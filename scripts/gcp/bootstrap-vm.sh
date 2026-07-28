#!/usr/bin/env bash

set -Eeuo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  printf 'bootstrap-vm.sh must run as root.\n' >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

readonly docker_keyring=/etc/apt/keyrings/docker.asc
readonly docker_repository=/etc/apt/sources.list.d/docker.list
readonly deployment_root="${GCP_DEPLOY_PATH:-/opt/inventory}"

apt-get update
apt-get install --yes --no-install-recommends \
  ca-certificates \
  curl \
  git \
  google-compute-engine-oslogin \
  gnupg \
  iproute2 \
  jq \
  openssh-server \
  openssl \
  python3 \
  python3-venv \
  rsync

install -m 0755 -d /etc/apt/keyrings
curl --fail --silent --show-error --location \
  https://download.docker.com/linux/debian/gpg \
  --output "$docker_keyring"
chmod 0644 "$docker_keyring"

# shellcheck disable=SC1091
source /etc/os-release
printf '%s\n' \
  "deb [arch=$(dpkg --print-architecture) signed-by=$docker_keyring] https://download.docker.com/linux/debian $VERSION_CODENAME stable" \
  > "$docker_repository"

apt-get update
apt-get install --yes --no-install-recommends \
  containerd.io \
  docker-buildx-plugin \
  docker-ce \
  docker-ce-cli \
  docker-compose-plugin

install -m 0755 -d /etc/docker
if [[ ! -f /etc/docker/daemon.json ]]; then
  install -m 0644 /dev/null /etc/docker/daemon.json
  printf '%s\n' \
    '{' \
    '  "log-driver": "json-file",' \
    '  "log-opts": {' \
    '    "max-size": "10m",' \
    '    "max-file": "5"' \
    '  },' \
    '  "live-restore": true' \
    '}' \
    > /etc/docker/daemon.json
fi

install -m 0755 -d \
  "$deployment_root/releases" \
  "$deployment_root/shared" \
  "$deployment_root/shared/backups" \
  "$deployment_root/shared/evidence" \
  /var/www/certbot
chmod 0700 \
  "$deployment_root/shared" \
  "$deployment_root/shared/backups" \
  "$deployment_root/shared/evidence"

certbot_version_is_supported() {
  local executable="$1"
  local version_output
  local major
  local minor

  version_output="$("$executable" --version 2>&1)" || return 1
  [[ "$version_output" =~ ^certbot[[:space:]]+([0-9]+)\.([0-9]+)(\.[0-9]+)?([[:space:]].*)?$ ]] || return 1
  major=$((10#${BASH_REMATCH[1]}))
  minor=$((10#${BASH_REMATCH[2]}))
  ((major > 5 || (major == 5 && minor >= 4)))
}

certbot_executable="$(command -v certbot || true)"
if [[ -z "$certbot_executable" ]] || ! certbot_version_is_supported "$certbot_executable"; then
  readonly certbot_virtualenv=/opt/certbot
  if [[ ! -x "$certbot_virtualenv/bin/python" ]]; then
    python3 -m venv "$certbot_virtualenv"
  fi
  "$certbot_virtualenv/bin/python" -m pip install \
    --disable-pip-version-check \
    --no-cache-dir \
    --upgrade \
    pip
  "$certbot_virtualenv/bin/python" -m pip install \
    --disable-pip-version-check \
    --no-cache-dir \
    --upgrade \
    'certbot>=5.4,<6'
  ln -sfn "$certbot_virtualenv/bin/certbot" /usr/local/bin/certbot
  certbot_executable=/usr/local/bin/certbot
fi

certbot_version_is_supported "$certbot_executable" || {
  printf 'Certbot 5.4 or newer is required for IP certificate support.\n' >&2
  exit 1
}

install -m 0700 -d /etc/letsencrypt /var/lib/letsencrypt /var/log/letsencrypt

systemctl enable ssh docker
systemctl restart ssh docker

docker version
docker compose version
"$certbot_executable" --version
printf 'VM bootstrap completed at %s\n' "$deployment_root"
