#!/usr/bin/env bash

set -Eeuo pipefail

readonly minimum_certbot_major=5
readonly minimum_certbot_minor=4
readonly certbot_webroot=/var/www/certbot
readonly deploy_hook=/usr/local/libexec/inventory-certbot-deploy-hook

validate_only=false

usage() {
  cat <<'EOF'
Usage: scripts/gcp/issue-ip-certificate.sh [--validate-only]

Obtains or renews a Let's Encrypt short-lived certificate for an IP address.
The script uses webroot when port 80 is already in use and standalone only when
port 80 is free.

Required environment:
  PRODUCTION_PUBLIC_IP
  TLS_CERTIFICATE_NAME
  LETSENCRYPT_AGREE_TOS=true

Set exactly one of:
  LETSENCRYPT_EMAIL=<account email>
  LETSENCRYPT_WITHOUT_EMAIL=true

Optional environment:
  LETSENCRYPT_AUTHENTICATOR=auto|webroot|standalone  (default: auto)
  LETSENCRYPT_STAGING=true|false                     (default: false)
  CERTBOT_BIN=/absolute/path/to/certbot

Review the current subscriber agreement before setting LETSENCRYPT_AGREE_TOS:
  https://letsencrypt.org/repository/
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
      printf 'certificate: unknown option: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

certificate_error() {
  printf 'certificate: %s\n' "$*" >&2
}

require_command() {
  local command_name="$1"
  command -v "$command_name" >/dev/null 2>&1 || {
    certificate_error "required command not found: $command_name"
    return 1
  }
}

validate_ipv4() {
  local address="$1"
  local octet
  local -a octets

  [[ "$address" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || {
    certificate_error "PRODUCTION_PUBLIC_IP must be an IPv4 address"
    return 1
  }

  IFS=. read -r -a octets <<< "$address"
  for octet in "${octets[@]}"; do
    ((10#$octet >= 0 && 10#$octet <= 255)) || {
      certificate_error "PRODUCTION_PUBLIC_IP contains an invalid IPv4 octet"
      return 1
    }
  done
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
    certificate_error "Certbot was not found; install Certbot 5.4 or newer"
    return 1
  }
  printf '%s' "$candidate"
}

validate_certbot_version() {
  local executable="$1"
  local version_output
  local major
  local minor

  version_output="$("$executable" --version 2>&1)" || {
    certificate_error "unable to determine the Certbot version"
    return 1
  }
  [[ "$version_output" =~ ^certbot[[:space:]]+([0-9]+)\.([0-9]+)(\.[0-9]+)?([[:space:]].*)?$ ]] || {
    certificate_error "unexpected Certbot version output"
    return 1
  }
  major=$((10#${BASH_REMATCH[1]}))
  minor=$((10#${BASH_REMATCH[2]}))

  ((major > minimum_certbot_major \
    || (major == minimum_certbot_major && minor >= minimum_certbot_minor))) || {
    certificate_error "Certbot 5.4 or newer is required for IP webroot issuance"
    return 1
  }
}

port_80_in_use() {
  local listeners

  require_command ss
  listeners="$(ss -H -ltn 'sport = :80')" || {
    certificate_error "unable to inspect TCP port 80"
    return 2
  }
  [[ -n "$listeners" ]]
}

select_authenticator() {
  local requested="$1"

  case "$requested" in
    auto)
      if port_80_in_use; then
        printf 'webroot'
      else
        case "$?" in
          1) printf 'standalone' ;;
          *) return 1 ;;
        esac
      fi
      ;;
    webroot)
      printf 'webroot'
      ;;
    standalone)
      if port_80_in_use; then
        certificate_error "standalone mode is unsafe while TCP port 80 is in use"
        return 1
      else
        case "$?" in
          1) printf 'standalone' ;;
          *) return 1 ;;
        esac
      fi
      ;;
    *)
      certificate_error "LETSENCRYPT_AUTHENTICATOR must be auto, webroot or standalone"
      return 1
      ;;
  esac
}

: "${PRODUCTION_PUBLIC_IP:?PRODUCTION_PUBLIC_IP is required}"
: "${TLS_CERTIFICATE_NAME:?TLS_CERTIFICATE_NAME is required}"

validate_ipv4 "$PRODUCTION_PUBLIC_IP"
[[ "$TLS_CERTIFICATE_NAME" =~ ^[A-Za-z0-9][A-Za-z0-9.-]*$ ]] || {
  certificate_error "TLS_CERTIFICATE_NAME contains unsupported characters"
  exit 2
}
[[ "${LETSENCRYPT_AGREE_TOS:-false}" == true ]] || {
  certificate_error "set LETSENCRYPT_AGREE_TOS=true only after accepting the Let's Encrypt Terms of Service"
  exit 2
}

readonly letsencrypt_email="${LETSENCRYPT_EMAIL:-}"
readonly without_email="${LETSENCRYPT_WITHOUT_EMAIL:-false}"
[[ "$without_email" == true || "$without_email" == false ]] || {
  certificate_error "LETSENCRYPT_WITHOUT_EMAIL must be true or false"
  exit 2
}
if [[ -n "$letsencrypt_email" ]]; then
  [[ "$without_email" == false ]] || {
    certificate_error "set LETSENCRYPT_EMAIL or LETSENCRYPT_WITHOUT_EMAIL=true, not both"
    exit 2
  }
  [[ ${#letsencrypt_email} -le 254 \
    && "$letsencrypt_email" =~ ^[A-Za-z0-9._+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,63}$ ]] || {
    certificate_error "LETSENCRYPT_EMAIL is not a supported email address"
    exit 2
  }
elif [[ "$without_email" != true ]]; then
  certificate_error "set LETSENCRYPT_EMAIL or explicitly set LETSENCRYPT_WITHOUT_EMAIL=true"
  exit 2
fi

readonly letsencrypt_staging="${LETSENCRYPT_STAGING:-false}"
[[ "$letsencrypt_staging" == true || "$letsencrypt_staging" == false ]] || {
  certificate_error "LETSENCRYPT_STAGING must be true or false"
  exit 2
}

readonly requested_authenticator="${LETSENCRYPT_AUTHENTICATOR:-auto}"
certbot_bin="$(resolve_certbot)"
readonly certbot_bin
validate_certbot_version "$certbot_bin"
selected_authenticator="$(select_authenticator "$requested_authenticator")"
readonly selected_authenticator

if [[ "$validate_only" == true ]]; then
  printf 'Certificate configuration is valid.\n'
  printf 'IP identifier: %s\n' "$PRODUCTION_PUBLIC_IP"
  printf 'Certificate name: %s\n' "$TLS_CERTIFICATE_NAME"
  printf 'Authenticator: %s\n' "$selected_authenticator"
  exit 0
fi

if [[ "$EUID" -ne 0 ]]; then
  certificate_error "certificate issuance must run as root"
  exit 1
fi

umask 077
install -d -m 0700 /etc/letsencrypt /var/lib/letsencrypt /var/log/letsencrypt

declare -a account_arguments
if [[ -n "$letsencrypt_email" ]]; then
  account_arguments=(--email "$letsencrypt_email")
else
  account_arguments=(--register-unsafely-without-email)
fi

declare -a authenticator_arguments
if [[ "$selected_authenticator" == webroot ]]; then
  install -d -m 0755 \
    "$certbot_webroot" \
    "$certbot_webroot/.well-known" \
    "$certbot_webroot/.well-known/acme-challenge"
  authenticator_arguments=(
    --webroot
    --webroot-path "$certbot_webroot"
  )
else
  # Recheck immediately before Certbot binds the port to avoid disrupting a
  # web server that started after authenticator selection.
  if port_80_in_use; then
    certificate_error "TCP port 80 became busy; refusing standalone issuance"
    exit 1
  else
    case "$?" in
      1) ;;
      *) exit 1 ;;
    esac
  fi
  authenticator_arguments=(
    --standalone
    --http-01-port 80
  )
fi

declare -a staging_arguments=()
if [[ "$letsencrypt_staging" == true ]]; then
  staging_arguments=(--staging)
fi

declare -a hook_arguments=()
if [[ -x "$deploy_hook" ]]; then
  hook_arguments=(--deploy-hook "$deploy_hook")
fi

"$certbot_bin" certonly \
  --non-interactive \
  --agree-tos \
  "${account_arguments[@]}" \
  --preferred-profile shortlived \
  --cert-name "$TLS_CERTIFICATE_NAME" \
  --ip-address "$PRODUCTION_PUBLIC_IP" \
  --keep-until-expiring \
  "${authenticator_arguments[@]}" \
  "${staging_arguments[@]}" \
  "${hook_arguments[@]}"

readonly certificate_lineage="/etc/letsencrypt/live/$TLS_CERTIFICATE_NAME"
[[ -r "$certificate_lineage/fullchain.pem" && -r "$certificate_lineage/privkey.pem" ]] || {
  certificate_error "Certbot completed without the expected certificate lineage"
  exit 1
}

require_command openssl
openssl x509 \
  -in "$certificate_lineage/cert.pem" \
  -noout \
  -ext subjectAltName |
  grep -F -- "IP Address:$PRODUCTION_PUBLIC_IP" >/dev/null || {
    certificate_error "issued certificate does not contain the expected IP SAN"
    exit 1
  }

if command -v systemctl >/dev/null 2>&1 \
  && [[ -f /etc/systemd/system/inventory-certbot-renew.timer ]]; then
  systemctl enable --now inventory-certbot-renew.timer
fi

printf 'IP certificate is available at %s\n' "$certificate_lineage"
