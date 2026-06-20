# Getting Started with pgui

This guide covers setting up your local environment, running the development server, configuring settings, and troubleshooting common issues.

## Prerequisites

To run `pgui` applications locally, you need:
- **Docker** or a Docker-compatible container engine (such as Podman or Colima).
- A **POSIX-compliant shell** (`sh`, `bash`, `zsh`, etc.).
- **curl** for checking HTTP readiness.
- **psql** (PostgreSQL interactive terminal client) installed on your host system for manual connections and running `./verify.sh`.

## Local Development Server

Start the default development database and web server by running the root start script:
```sh
./run.sh
```

By default, this will:
1. Start an isolated Docker container running Postgres 17 with the Omnigres extensions loaded.
2. Wait for database and web server readiness.
3. Automatically install the `pgui` framework and the guestbook demo database schema.
4. Output the connection strings and web server URLs.

### Verification

Run the verification suite to ensure the framework and demo app are functioning correctly:
```sh
./verify.sh
```

## Configuration

`run.sh` can be configured using environment variables. The supported variables and their defaults are:

| Variable | Default Value | Description |
|---|---|---|
| `PGUI_CONTAINER` | `pgui` | Name of the Docker container to create/reuse. |
| `PGUI_IMAGE` | `ghcr.io/omnigres/omnigres-17:latest` | Omnigres Docker image to use. |
| `PGUI_DB` | `omnigres` | Target database name inside the container. |
| `PGUI_USER` | `omnigres` | PostgreSQL username inside the container. |
| `PGUI_PASSWORD` | `omnigres` | PostgreSQL password inside the container. |
| `PGUI_DB_PORT` | `5432` | Local port mapped to PostgreSQL inside the container. |
| `PGUI_HTTP_PORT` | `8080` | Local port mapped to the web server inside the container. |
| `PGUI_BIND_ADDR` | `127.0.0.1` | Network interface address to bind the HTTP port to. |
| `PGUI_RESET` | `0` | If set to `1`, forces removal and recreation of the container. |
| `PGUI_INSTALL` | `1` | If set to `1`, executes `PGUI_INSTALL_SQL` on startup. |
| `PGUI_INSTALL_SQL` | `db/install.sql` | SQL script to run for schema installation. |
| `PGUI_WAIT_SECONDS` | `60` | Maximum time (in seconds) to wait for database/web readiness. |

### Resetting the Database
To clear the container state and run a fresh installation:
```sh
PGUI_RESET=1 ./run.sh
```

### Specifying Custom Ports
To avoid port conflicts with other local databases or web servers:
```sh
PGUI_DB_PORT=55432 PGUI_HTTP_PORT=18080 ./run.sh
```

### Framework-Only Installation
To spin up a container that has only the core framework loaded without any demo handlers:
```sh
PGUI_INSTALL_SQL=db/framework/install.sql ./run.sh
```

## Troubleshooting

### Docker daemon is not running
If you get `Error: Docker daemon is not running or unreachable.`, make sure your container engine (Docker Desktop, Colima, OrbStack, etc.) is started. If using Colima on macOS, the script will automatically export the correct socket path if the default socket exists.

### Occupied ports
If `run.sh` fails with a message that a port is occupied, you might have another PostgreSQL instance running on port 5432, or a web server on port 8080. You can change these ports using:
```sh
PGUI_DB_PORT=54321 PGUI_HTTP_PORT=8081 ./run.sh
```

### missing psql or curl
If `verify.sh` prints `Error: psql command not found`, make sure you have the postgresql client utilities installed (e.g., via `brew install postgresql` on macOS or `apt-get install postgresql-client` on Debian/Ubuntu).

### Image pull failures
If the script times out waiting for readiness and logs show image pulling issues, verify your internet connection and make sure you can resolve and pull images from `ghcr.io/omnigres/omnigres-17`.
