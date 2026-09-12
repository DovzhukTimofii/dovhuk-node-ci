#!/usr/bin/env bash
set -euo pipefail
: "${EC2_HOST:?}" "${EC2_USER:?}" "${EC2_SSH_KEY_B64:?}" "${EC2_KNOWN_HOSTS:?}"
: "${DOCKER_USERNAME:?}" "${IMAGE_TAG:?}" "${POSTGRES_PASSWORD:?}"
[[ "$EC2_HOST" =~ ^[0-9.]+$ ]]
[[ "$EC2_USER" =~ ^[a-z_][a-z0-9_-]*$ ]]
[[ "$DOCKER_USERNAME" =~ ^[a-z0-9][a-z0-9_-]*$ ]]
[[ "$IMAGE_TAG" =~ ^[0-9a-f]{40}$ ]]
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
umask 077
printf '%s' "$EC2_SSH_KEY_B64" | base64 --decode > "$tmp/key"
printf '%s\n' "$EC2_KNOWN_HOSTS" > "$tmp/known_hosts"
export DEPLOY_ENV_FILE="$tmp/deploy.env"
python3 - <<'ENV'
import os
# Simple dotenv values avoid interpolation, quoting and newline ambiguity.
password = os.environ['POSTGRES_PASSWORD']
if not password or any(c not in 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-' for c in password):
    raise SystemExit('POSTGRES_PASSWORD must use letters, digits, underscore or hyphen')
with open(os.environ['DEPLOY_ENV_FILE'], 'w') as f:
    for key in ['DOCKER_USERNAME', 'IMAGE_TAG', 'POSTGRES_PASSWORD']:
        f.write(key + '=' + os.environ[key] + '\n')
ENV
opts=(-i "$tmp/key" -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=yes -o HostKeyAlias=nodeapp -o "UserKnownHostsFile=$tmp/known_hosts")
target="$EC2_USER@$EC2_HOST"
ready=false
for attempt in {1..24}; do
  if ssh "${opts[@]}" "$target" true; then ready=true; break; fi
  sleep 5
done
if [ "$ready" != true ]; then echo 'SSH unavailable; verify key, known hosts, and security group.' >&2; exit 1; fi
ssh "${opts[@]}" "$target" 'mkdir -p ~/nodeapp && chmod 700 ~/nodeapp'
scp "${opts[@]}" docker-compose.yml "$target:nodeapp/docker-compose.next.yml"
scp "${opts[@]}" "$tmp/deploy.env" "$target:nodeapp/.env.next"
ssh "${opts[@]}" "$target" 'bash -se' <<'REMOTE'
set -euo pipefail
if ! sudo docker compose version >/dev/null 2>&1; then
  sudo apt-get update
  sudo apt-get install -y ca-certificates curl
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc
  . /etc/os-release
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $VERSION_CODENAME stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi
sudo systemctl enable --now docker
cd ~/nodeapp
chmod 600 .env.next
# Pull successfully before updating the running service. Docker Hub repository must be public.
sudo docker compose --env-file .env.next -f docker-compose.next.yml -p nodeapp pull
mv .env.next .env
mv docker-compose.next.yml docker-compose.yml
sudo docker compose -p nodeapp up -d --no-build --wait --wait-timeout 120
curl --fail --retry 5 --retry-connrefused http://127.0.0.1:3000/ready
REMOTE
curl --fail --retry 5 --retry-connrefused "http://$EC2_HOST:3000/ready"
