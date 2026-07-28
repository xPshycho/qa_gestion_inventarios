#!/usr/bin/env bash

set -Eeuo pipefail

readonly installed_deploy_hook=/usr/local/libexec/inventory-certbot-deploy-hook
readonly renewal_service=/etc/systemd/system/inventory-certbot-renew.service
readonly renewal_timer=/etc/systemd/system/inventory-certbot-renew.timer

validate_only=false

usage() {
  cat <<'EOF'
Usage: scripts/gcp/install-certificate-renewal.sh [--validate-only]

Installs a hardened systemd timer that checks the short-lived IP certificate
every six hours. The deploy hook reloads a running production gateway only
after Certbot successfully issues a replacement certificate.

Required environment:
  PRODUCTION_PUBLIC_IP
  TLS_CERTIFICATE_NAME

Optional environment:
  CERTBOT_BIN=/absolute/path/to/certbot

This script neither registers an ACME account nor accepts Terms of Service.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --validate-only)
      validate_only=true
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      printf 'certificate-renewal: unknown option: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

renewal_error() {
  printf 'certificate-renewal: %s\n' "$*" >&2
}

require_command() {
  local command_name="$1"
  command -v "$command_name" >/dev/null 2>&1 || {
    renewal_error "required command not found: $command_name"
    return 1
  }
}

resolve_certbot() {
  local candidate="${CERTBOT_BIN:-}"

  if [[ -z "$candidate" && -x /opt/certbot/bin/certbot ]]; then
    candidate=/opt/certbot/bin/certbot
  fi
  if [[ -z "$candidate" ]]; then
    candidate="$(command -v certbot || true)"
  fi
  [[ "$candidate" =~ ^/[A-Za-z0-9._/+:-]+$ && -x "$candidate" ]] || {
    renewal_error "Certbot was not found; install Certbot 5.4 or newer"
    return 1
  }
  printf '%s' "$candidate"
}

validate_ipv4() {
  local address="$1"
  local octet
  local -a octets

  [[ "$address" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || {
    renewal_error "PRODUCTION_PUBLIC_IP must be an IPv4 address"
    return 1
  }
  IFS=. read -r -a octets <<< "$address"
  for octet in "${octets[@]}"; do
    ((10#$octet >= 0 && 10#$octet <= 255)) || {
      renewal_error "PRODUCTION_PUBLIC_IP contains an invalid IPv4 octet"
      return 1
    }
  done
}

validate_certbot_version() {
  local executable="$1"
  local version_output
  local major
  local minor

  version_output="$("$executable" --version 2>&1)" || {
    renewal_error "unable to determine the Certbot version"
    return 1
  }
  [[ "$version_output" =~ ^certbot[[:space:]]+([0-9]+)\.([0-9]+)(\.[0-9]+)?([[:space:]].*)?$ ]] || {
    renewal_error "unexpected Certbot version output"
    return 1
  }
  major=$((10#${BASH_REMATCH[1]}))
  minor=$((10#${BASH_REMATCH[2]}))
  ((major > 5 || (major == 5 && minor >= 4))) || {
    renewal_error "Certbot 5.4 or newer is required for IP renewal"
    return 1
  }
}

: "${PRODUCTION_PUBLIC_IP:?PRODUCTION_PUBLIC_IP is required}"
: "${TLS_CERTIFICATE_NAME:?TLS_CERTIFICATE_NAME is required}"

validate_ipv4 "$PRODUCTION_PUBLIC_IP"
[[ "$TLS_CERTIFICATE_NAME" =~ ^[A-Za-z0-9][A-Za-z0-9.-]*$ ]] || {
  renewal_error "TLS_CERTIFICATE_NAME contains unsupported characters"
  exit 2
}

certbot_bin="$(resolve_certbot)"
readonly certbot_bin
validate_certbot_version "$certbot_bin"

render_deploy_hook() {
  local output_file="$1"

  {
    printf '%s\n' \
      '#!/usr/bin/env bash' \
      '' \
      'set -Eeuo pipefail'
    printf 'readonly expected_lineage=%q\n' "/etc/letsencrypt/live/$TLS_CERTIFICATE_NAME"
    printf 'readonly expected_ip=%q\n' "$PRODUCTION_PUBLIC_IP"
    printf '%s\n' \
      '' \
      'if [[ -n "${RENEWED_LINEAGE:-}" && "$RENEWED_LINEAGE" != "$expected_lineage" ]]; then' \
      '  exit 0' \
      'fi' \
      '[[ -r "$expected_lineage/fullchain.pem" && -r "$expected_lineage/privkey.pem" ]] || exit 0' \
      'openssl_bin="$(command -v openssl || true)"' \
      '[[ -n "$openssl_bin" ]] || exit 0' \
      '"$openssl_bin" x509 -in "$expected_lineage/cert.pem" -noout -ext subjectAltName |' \
      '  grep -F -- "IP Address:$expected_ip" >/dev/null || exit 0' \
      '' \
      'docker_bin="$(command -v docker || true)"' \
      '[[ -n "$docker_bin" ]] || exit 0' \
      '' \
      'mapfile -t gateway_ids < <(' \
      '  "$docker_bin" ps \' \
      '    --filter label=com.docker.compose.project=inventory-production \' \
      '    --filter label=com.docker.compose.service=gateway \' \
      "    --format '{{.ID}}'" \
      ')' \
      '((${#gateway_ids[@]} > 0)) || exit 0' \
      '' \
      'for gateway_id in "${gateway_ids[@]}"; do' \
      '  "$docker_bin" exec "$gateway_id" nginx -t >/dev/null' \
      '  "$docker_bin" kill --signal HUP "$gateway_id" >/dev/null' \
      'done'
  } > "$output_file"
}

render_renewal_service() {
  local output_file="$1"

  {
    printf '%s\n' \
      '[Unit]' \
      'Description=Renew the Inventory short-lived IP certificate' \
      'Documentation=https://letsencrypt.org/2026/03/11/shorter-certs-certbot' \
      'Wants=network-online.target' \
      'After=network-online.target docker.service' \
      '' \
      '[Service]' \
      'Type=oneshot' \
      'UMask=0077' \
      'Environment=PATH=/opt/certbot/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
    printf 'ExecStart=%s renew --non-interactive --quiet --cert-name=%s --webroot --webroot-path=/var/www/certbot --preferred-profile=shortlived --deploy-hook=%s --no-random-sleep-on-renew\n' \
      "$certbot_bin" \
      "$TLS_CERTIFICATE_NAME" \
      "$installed_deploy_hook"
    printf '%s\n' \
      'Nice=10' \
      'IOSchedulingClass=idle' \
      'NoNewPrivileges=true' \
      'PrivateTmp=true' \
      'ProtectHome=true' \
      'ProtectSystem=strict' \
      'ReadWritePaths=/etc/letsencrypt /var/lib/letsencrypt /var/log/letsencrypt /var/www/certbot' \
      'RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6'
  } > "$output_file"
}

render_renewal_timer() {
  local output_file="$1"

  {
    printf '%s\n' \
      '[Unit]' \
      'Description=Check the Inventory short-lived IP certificate every six hours' \
      '' \
      '[Timer]' \
      'OnBootSec=5min' \
      'OnUnitActiveSec=6h' \
      'RandomizedDelaySec=30min' \
      'AccuracySec=1min' \
      'Persistent=true' \
      'Unit=inventory-certbot-renew.service' \
      '' \
      '[Install]' \
      'WantedBy=timers.target'
  } > "$output_file"
}

if [[ "$validate_only" == true ]]; then
  require_command mktemp
  validation_directory="$(mktemp -d /tmp/inventory-certbot-renewal-validation.XXXXXX)"
  readonly validation_directory
  readonly validation_hook="$validation_directory/inventory-certbot-deploy-hook"
  readonly validation_service="$validation_directory/inventory-certbot-renew.service"
  readonly validation_timer="$validation_directory/inventory-certbot-renew.timer"

  cleanup_validation_directory() {
    rm -f -- "$validation_hook" "$validation_service" "$validation_timer"
    rmdir -- "$validation_directory"
  }
  trap cleanup_validation_directory EXIT

  render_deploy_hook "$validation_hook"
  render_renewal_service "$validation_service"
  render_renewal_timer "$validation_timer"
  bash -n "$validation_hook"
  if command -v systemd-analyze >/dev/null 2>&1; then
    verification_output=""
    if ! verification_output="$(
      systemd-analyze verify "$validation_service" "$validation_timer" 2>&1
    )"; then
      if [[ "$verification_output" != *"Operation not permitted"* ]]; then
        printf '%s\n' "$verification_output" >&2
        exit 1
      fi
      printf 'systemd unit verification was limited by the local sandbox.\n'
    fi
  fi
  printf 'Certificate renewal configuration is valid.\n'
  exit 0
fi

if [[ "$EUID" -ne 0 ]]; then
  renewal_error "certificate renewal installation must run as root"
  exit 1
fi

require_command docker
require_command install
require_command mktemp
require_command systemctl
require_command systemd-analyze

umask 077
install -d -m 0755 /usr/local/libexec

temporary_hook="$(mktemp /tmp/inventory-certbot-hook.XXXXXX)"
temporary_service="$(mktemp /tmp/inventory-certbot-service.XXXXXX)"
temporary_timer="$(mktemp /tmp/inventory-certbot-timer.XXXXXX)"
readonly temporary_hook temporary_service temporary_timer

cleanup_temporary_files() {
  rm -f -- "$temporary_hook" "$temporary_service" "$temporary_timer"
}
trap cleanup_temporary_files EXIT

render_deploy_hook "$temporary_hook"
render_renewal_service "$temporary_service"
render_renewal_timer "$temporary_timer"

install -o root -g root -m 0755 "$temporary_hook" "$installed_deploy_hook"
install -o root -g root -m 0644 "$temporary_service" "$renewal_service"
install -o root -g root -m 0644 "$temporary_timer" "$renewal_timer"

systemd-analyze verify "$renewal_service" "$renewal_timer"
systemctl daemon-reload

printf 'Certificate renewal timer installed: inventory-certbot-renew.timer\n'
printf 'Renewal interval: six hours with up to thirty minutes of jitter\n'

readonly certificate_lineage="/etc/letsencrypt/live/$TLS_CERTIFICATE_NAME"
if [[ -r "$certificate_lineage/fullchain.pem" \
  && -r "$certificate_lineage/privkey.pem" ]]; then
  systemctl enable --now inventory-certbot-renew.timer
  printf 'Certificate exists; renewal timer enabled.\n'
else
  systemctl disable --now inventory-certbot-renew.timer >/dev/null 2>&1 || true
  printf 'Initial certificate is absent; the issuance script will enable the timer.\n'
fi
