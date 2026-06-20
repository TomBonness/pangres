#!/usr/bin/env sh
set -eu
if [ -z "${DOCKER_HOST:-}" ] && [ -S "${HOME}/.colima/default/docker.sock" ]; then
  export DOCKER_HOST="unix://${HOME}/.colima/default/docker.sock"
fi
DOCKER_CONFIG="${DOCKER_CONFIG:-$(mktemp -d)}"
export DOCKER_CONFIG
docker rm -f pgui 2>/dev/null || true
docker run -d --name pgui \
  -e POSTGRES_PASSWORD=omnigres -e POSTGRES_USER=omnigres -e POSTGRES_DB=omnigres \
  -p 127.0.0.1:5432:5432 -p 127.0.0.1:8080:8081 \
  ghcr.io/omnigres/omnigres-17:latest
until docker exec pgui psql -U omnigres -d omnigres -v ON_ERROR_STOP=1 -c 'select 1' >/dev/null 2>&1 \
  && curl -fsS http://localhost:8080/ >/dev/null 2>&1; do sleep 1; done
echo "pgui up: psql on :5432, http on :8080"
