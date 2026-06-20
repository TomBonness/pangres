#!/usr/bin/env sh
set -eu

PGUI_CONTAINER="${PGUI_CONTAINER:-pgui}"
PGUI_IMAGE="${PGUI_IMAGE:-ghcr.io/omnigres/omnigres-17:latest}"
PGUI_DB="${PGUI_DB:-omnigres}"
PGUI_USER="${PGUI_USER:-omnigres}"
PGUI_PASSWORD="${PGUI_PASSWORD:-omnigres}"
PGUI_DB_PORT="${PGUI_DB_PORT:-5432}"
PGUI_HTTP_PORT="${PGUI_HTTP_PORT:-8080}"
PGUI_BIND_ADDR="${PGUI_BIND_ADDR:-127.0.0.1}"
PGUI_RESET="${PGUI_RESET:-0}"
PGUI_INSTALL="${PGUI_INSTALL:-1}"
PGUI_INSTALL_SQL="${PGUI_INSTALL_SQL:-db/install.sql}"
PGUI_WAIT_SECONDS="${PGUI_WAIT_SECONDS:-60}"

if [ -z "${DOCKER_HOST:-}" ] && [ -S "${HOME}/.colima/default/docker.sock" ]; then
  export DOCKER_HOST="unix://${HOME}/.colima/default/docker.sock"
fi

is_port_in_use() {
  port="$1"
  if command -v nc >/dev/null 2>&1; then
    nc -z 127.0.0.1 "$port" >/dev/null 2>&1
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c "import socket; s = socket.socket(); s.connect(('127.0.0.1', $port))" >/dev/null 2>&1
  else
    false
  fi
}

# Preflight: Check Docker command
if ! command -v docker >/dev/null 2>&1; then
  echo "Error: docker command not found. Please install Docker." >&2
  exit 1
fi

# Preflight: Check Docker daemon
if ! docker info >/dev/null 2>&1; then
  echo "Error: Docker daemon is not running or unreachable." >&2
  exit 1
fi

# Container lifecycle
container_exists=0
if docker inspect "$PGUI_CONTAINER" >/dev/null 2>&1; then
  container_exists=1
fi

if [ "$container_exists" = "1" ] && [ "$PGUI_RESET" = "1" ]; then
  if ! docker rm -f "$PGUI_CONTAINER" >/dev/null; then
    echo "Error: Failed to remove container $PGUI_CONTAINER." >&2
    exit 1
  fi
  container_exists=0
fi

if [ "$container_exists" = "1" ]; then
  status=$(docker inspect --format '{{.State.Status}}' "$PGUI_CONTAINER" 2>/dev/null || echo "")
  if [ "$status" = "running" ]; then
    # Already running, do nothing
    :
  else
    # Check ports before starting
    if is_port_in_use "$PGUI_DB_PORT"; then
      echo "Error: DB port $PGUI_DB_PORT is already occupied." >&2
      exit 1
    fi
    if is_port_in_use "$PGUI_HTTP_PORT"; then
      echo "Error: HTTP port $PGUI_HTTP_PORT is already occupied." >&2
      exit 1
    fi
    if ! docker start "$PGUI_CONTAINER" >/dev/null; then
      echo "Error: Failed to start container $PGUI_CONTAINER." >&2
      exit 1
    fi
  fi
else
  # Check ports before running
  if is_port_in_use "$PGUI_DB_PORT"; then
    echo "Error: DB port $PGUI_DB_PORT is already occupied." >&2
    exit 1
  fi
  if is_port_in_use "$PGUI_HTTP_PORT"; then
    echo "Error: HTTP port $PGUI_HTTP_PORT is already occupied." >&2
    exit 1
  fi
  if ! docker run -d --name "$PGUI_CONTAINER" \
    -e POSTGRES_PASSWORD="$PGUI_PASSWORD" \
    -e POSTGRES_USER="$PGUI_USER" \
    -e POSTGRES_DB="$PGUI_DB" \
    -p "127.0.0.1:$PGUI_DB_PORT:5432" \
    -p "$PGUI_BIND_ADDR:$PGUI_HTTP_PORT:8081" \
    "$PGUI_IMAGE" >/dev/null; then
      echo "Error: Failed to run container $PGUI_CONTAINER with image $PGUI_IMAGE." >&2
      exit 1
  fi
fi

# Poll for database and web server readiness
db_ready=0
i=0
while [ $i -lt "$PGUI_WAIT_SECONDS" ]; do
  if docker exec "$PGUI_CONTAINER" psql -U "$PGUI_USER" -d "$PGUI_DB" -v ON_ERROR_STOP=1 -c 'select 1' >/dev/null 2>&1; then
    if curl -fsS "http://127.0.0.1:$PGUI_HTTP_PORT/" >/dev/null 2>&1; then
      db_ready=1
      break
    fi
  fi
  sleep 1
  i=$((i + 1))
done

if [ "$db_ready" -ne 1 ]; then
  echo "Timeout waiting for pgui to start up." >&2
  echo "Container: $PGUI_CONTAINER" >&2
  echo "Image: $PGUI_IMAGE" >&2
  echo "Database URL: postgres://$PGUI_USER:$PGUI_PASSWORD@localhost:$PGUI_DB_PORT/$PGUI_DB" >&2
  echo "HTTP URL: http://localhost:$PGUI_HTTP_PORT/" >&2
  echo "Logs hint: run 'docker logs $PGUI_CONTAINER' for details." >&2
  exit 1
fi

# Install the SQL if PGUI_INSTALL=1
if [ "$PGUI_INSTALL" = "1" ]; then
  case "$PGUI_INSTALL_SQL" in
    db/*) ;;
    *)
      echo "PGUI_INSTALL_SQL must point inside db/ when PGUI_INSTALL=1" >&2
      exit 1
      ;;
  esac
  
  docker exec "$PGUI_CONTAINER" rm -rf /tmp/pgui-db
  docker exec "$PGUI_CONTAINER" mkdir -p /tmp/pgui-db/app /tmp/pgui-db/framework

  docker exec -i "$PGUI_CONTAINER" sh -c 'cat > /tmp/pgui-db/install.sql' < db/install.sql
  docker exec -i "$PGUI_CONTAINER" sh -c 'cat > /tmp/pgui-db/app/install.sql' < db/app/install.sql
  docker exec -i "$PGUI_CONTAINER" sh -c 'cat > /tmp/pgui-db/app/schema.sql' < db/app/schema.sql
  docker exec -i "$PGUI_CONTAINER" sh -c 'cat > /tmp/pgui-db/app/handlers.sql' < db/app/handlers.sql
  docker exec -i "$PGUI_CONTAINER" sh -c 'cat > /tmp/pgui-db/app/routes.sql' < db/app/routes.sql
  docker exec -i "$PGUI_CONTAINER" sh -c 'cat > /tmp/pgui-db/framework/install.sql' < db/framework/install.sql
  docker exec -i "$PGUI_CONTAINER" sh -c 'cat > /tmp/pgui-db/framework/pgui.sql' < db/framework/pgui.sql
  
  if ! docker exec "$PGUI_CONTAINER" psql -U "$PGUI_USER" -d "$PGUI_DB" -v ON_ERROR_STOP=1 -f "/tmp/pgui-db/${PGUI_INSTALL_SQL#db/}" >/dev/null; then
    echo "Error: Failed to install SQL schema: $PGUI_INSTALL_SQL" >&2
    exit 1
  fi
fi

# Wait for both DB and HTTP url
web_ready=0
i=0
while [ $i -lt "$PGUI_WAIT_SECONDS" ]; do
  if docker exec "$PGUI_CONTAINER" psql -U "$PGUI_USER" -d "$PGUI_DB" -v ON_ERROR_STOP=1 -c 'select 1' >/dev/null 2>&1; then
    if curl -fsS "http://127.0.0.1:$PGUI_HTTP_PORT/" >/dev/null 2>&1; then
      web_ready=1
      break
    fi
  fi
  sleep 1
  i=$((i + 1))
done

if [ "$web_ready" -ne 1 ]; then
  echo "Timeout waiting for pgui to become ready." >&2
  echo "Container: $PGUI_CONTAINER" >&2
  echo "Image: $PGUI_IMAGE" >&2
  echo "Database URL: postgres://$PGUI_USER:$PGUI_PASSWORD@localhost:$PGUI_DB_PORT/$PGUI_DB" >&2
  echo "HTTP URL: http://localhost:$PGUI_HTTP_PORT/" >&2
  echo "Logs hint: run 'docker logs $PGUI_CONTAINER' for details." >&2
  exit 1
fi

installed_val="none"
if [ "$PGUI_INSTALL" = "1" ]; then
  installed_val="$PGUI_INSTALL_SQL"
fi

echo "pgui up"
echo "database: postgres://$PGUI_USER:$PGUI_PASSWORD@localhost:$PGUI_DB_PORT/$PGUI_DB"
echo "http: http://localhost:$PGUI_HTTP_PORT/"
echo "installed: $installed_val"
