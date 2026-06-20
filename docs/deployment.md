# Deployment

This guide explains how to package, deploy, and host `pgui` applications in production environments.

## Architecture Overview

`pgui` relies on Omnigres, specifically the `omni_httpd` extension, to run the HTTP web server inside the PostgreSQL database engine.

```mermaid
+-------------------------------------------------------------+
|                      Client (Browser)                       |
+-------------------------------------------------------------+
                               |
                               | HTTP (Port 80/443)
                               v
+-------------------------------------------------------------+
|            Reverse Proxy (Nginx / Caddy / ALB)              |
+-------------------------------------------------------------+
                               |
                               | Proxy HTTP (e.g., Port 8080)
                               v
+-------------------------------------------------------------+
|    PostgreSQL Process (with omni_httpd running on 8081)     |
+-------------------------------------------------------------+
```

Because the web server is embedded within the PostgreSQL engine, **pgui applications cannot be hosted on managed database services** like AWS RDS, Google Cloud SQL, or serverless platforms like AWS Amplify. These managed services do not allow running the custom Omnigres shared library or binding the process to HTTP ports.

Instead, you must deploy to a virtual machine (EC2, DigitalOcean Droplet) or container hosting service (AWS ECS, GCP Cloud Run) where you manage the PostgreSQL/Omnigres container process.

---

## Production Docker Deployment

Deploying is typically done using the official Omnigres Docker image.

### 1. Environment Configuration

In production, bind the HTTP server to all interfaces and map ports accordingly.

- Set `PGUI_BIND_ADDR=0.0.0.0` to accept public traffic.
- Set `PGUI_HTTP_PORT=80` or use a reverse proxy.
- Ensure your database data directory is persisted using a Docker volume so your tables, handlers, and routes survive container restarts.

### 2. Sample Docker Compose File

Here is a production-ready `docker-compose.yml` configuration:

```yaml
version: '3.8'

services:
  web:
    image: ghcr.io/omnigres/omnigres-17:latest
    container_name: hello_pgui_production
    restart: always
    environment:
      POSTGRES_DB: my_app
      POSTGRES_USER: admin
      POSTGRES_PASSWORD: secure_database_password
    ports:
      # Map host port 80 to container port 8081 (omni_httpd listener)
      - "80:8081"
      # Secure DB port (avoid exposing publicly in production)
      - "127.0.0.1:5432:5432"
    volumes:
      # Persist PostgreSQL database cluster data
      - pgui_data:/var/lib/postgresql/data
      # Copy schema migration script
      - ./db:/tmp/db:ro

volumes:
  pgui_data:
```

### 3. Running Schema Migration on Startup

After the container starts, you must execute the SQL installation script. You can run this command as part of your deployment CI/CD pipeline or systemd service startup:

```sh
docker exec hello_pgui_production psql -U admin -d my_app -v ON_ERROR_STOP=1 -f /tmp/db/install.sql
```

---

## Reverse Proxy Configuration

We strongly recommend running a reverse proxy (like Nginx, Caddy, or an AWS Application Load Balancer) in front of the PostgreSQL web server. The reverse proxy handles:
1. SSL/TLS termination (HTTPS certificates via Let's Encrypt).
2. Static file serving (assets, images, compiled JS).
3. Rate limiting and basic request sanitization.

### Sample Nginx Configuration
```nginx
server {
    listen 80;
    server_name myapp.example.com;

    location / {
        proxy_pass http://127.0.0.1:8080; # Mapped PGUI_HTTP_PORT
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

---

## Persistence Caveat (`run.sh`)

The local development script `run.sh` does **not** persist the database data directory by default. When you run with `PGUI_RESET=1`, the container is deleted along with its internal storage. Make sure to define proper volume mounts (as shown in the `docker-compose.yml` above) for any persistent staging or production environments.
