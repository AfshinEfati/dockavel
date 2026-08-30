# Dockavel

[![CI](https://github.com/AfshinEfati/dockavel/actions/workflows/ci.yml/badge.svg)](https://github.com/AfshinEfati/dockavel/actions/workflows/ci.yml)

A reusable **Docker-based local development stack** for running multiple Laravel and Node.js projects behind shared infrastructure.

Dockavel provides a PHP-FPM workspace, Node.js tooling, Nginx, Traefik-based local domain routing, MySQL, Redis, and phpMyAdmin without coupling the repository to any application source code.

## What It Solves

When several backend or full-stack projects are developed on the same machine, each project often duplicates the same local infrastructure. Dockavel keeps those shared services in one place while project source directories remain outside version control.

- Shared PHP / Composer / Node.js workspace
- Multiple Laravel projects under one mounted `projects/` directory
- Local `*.local` routing through Traefik and Nginx
- MySQL and Redis available to every project on the shared Docker network
- phpMyAdmin available through a local domain
- Configurable PHP, Node.js, ports, credentials, and network name
- Nginx templates for Laravel and Node.js applications
- CI validation for Docker Compose and the PHP workspace image

## Architecture

```text
Browser
   |
   v
Traefik :80
   |
   +--> phpmyadmin.local --------> phpMyAdmin
   |
   +--> *.local -----------------> Nginx
                                    |
                    +---------------+---------------+
                    |                               |
                    v                               v
             Laravel project                Node.js upstream
             PHP-FPM :9000                  app/service port
                    |
            +-------+-------+
            |               |
            v               v
          MySQL           Redis
```

All services share the `dockavel` Docker network by default. The network name can be changed with `DOCKAVEL_NETWORK`.

## Requirements

- Docker Engine / Docker Desktop
- Docker Compose v2 (`docker compose`)
- On Windows, WSL2 is recommended for Linux-style file permissions and performance

## Quick Start

```bash
git clone https://github.com/AfshinEfati/dockavel.git
cd dockavel
cp .env.example .env
docker compose up -d --build
```

Default local endpoints:

| Service | Address |
| --- | --- |
| Traefik routing | `http://<project>.local` |
| phpMyAdmin | `http://phpmyadmin.local` |
| Nginx direct port | `http://localhost:8080` |
| Traefik dashboard | `http://localhost:8081/dashboard/` |
| MySQL | `127.0.0.1:3306` |
| Redis | `127.0.0.1:6379` |

> The Traefik dashboard uses insecure mode intentionally because this repository is for local development only. Do not expose this stack directly to the public internet.

## Local Domain Setup

Add the domains you want to use to your hosts file.

Windows:

```text
C:\Windows\System32\drivers\etc\hosts
```

Linux / macOS:

```text
/etc/hosts
```

Example:

```text
127.0.0.1 api.local admin.local phpmyadmin.local
```

## Add a Laravel Project

Create or copy the project inside `projects/`:

```bash
mkdir -p projects
docker compose run --rm php composer create-project laravel/laravel api
```

Create an Nginx config from the included template:

```bash
cp nginx/template-laravel.conf.example nginx/conf.d/api.local.conf
```

Replace:

```text
{{DOMAIN}}       -> api
{{PROJECT_NAME}} -> api
```

Then reload Nginx:

```bash
docker compose exec nginx nginx -s reload
```

Inside Laravel, the shared services are reachable by Docker service name:

```dotenv
DB_HOST=mysql
DB_PORT=3306
REDIS_HOST=redis
REDIS_PORT=6379
```

## Node.js / Nuxt Projects

Node.js is installed globally in the PHP workspace image together with Corepack and PM2, so project tooling is available without installing Node on the host.

Check the installed toolchain:

```bash
docker compose run --rm php node --version
docker compose run --rm php npm --version
docker compose run --rm php pnpm --version
```

For an HTTP Node.js application, copy the Node Nginx template:

```bash
cp nginx/template-node.conf.example nginx/conf.d/web.local.conf
```

Configure:

```text
{{DOMAIN}}        -> web
{{UPSTREAM_HOST}} -> the Docker DNS name of the Node process/service
{{PORT}}          -> the application's internal port
```

An external project Compose file can join Dockavel's shared network like this:

```yaml
networks:
  dockavel:
    external: true
    name: dockavel
```

Its service name can then be used as `{{UPSTREAM_HOST}}` in the Nginx template.

## Version and Port Overrides

The defaults live in `.env.example` and can be overridden locally in `.env`.

```dotenv
PHP_VERSION=8.3
NODE_VERSION=22
NGINX_PORT=8080
MYSQL_PORT=3306
REDIS_PORT=6379
TRAEFIK_DASHBOARD_PORT=8081
```

For example, rebuilding the workspace with a different supported PHP image only requires changing `PHP_VERSION` and rebuilding:

```bash
docker compose build --no-cache php
```

## Useful Commands

Start or rebuild the stack:

```bash
docker compose up -d --build
```

Open a shell in the PHP workspace:

```bash
docker compose exec php bash
```

Run Composer for a project:

```bash
docker compose exec -w /var/www/api php composer install
```

Run Artisan:

```bash
docker compose exec -w /var/www/api php php artisan migrate
```

Inspect running services:

```bash
docker compose ps
```

Stop the stack:

```bash
docker compose down
```

Remove the stack and MySQL data volume:

```bash
docker compose down -v
```

## Repository Layout

```text
dockavel/
├── .github/workflows/ci.yml
├── .env.example
├── Dockerfile
├── docker-compose.yml
├── nginx/
│   ├── conf.d/                         # local configs, git-ignored
│   ├── template-laravel.conf.example
│   └── template-node.conf.example
└── projects/                            # application sources, git-ignored
```

## CI

GitHub Actions validates the Compose configuration and builds the PHP workspace image on pushes and pull requests. This catches invalid Docker configuration and image build failures before changes are merged.

## Design Notes

Dockavel is intentionally a development environment rather than a production deployment stack. Application code stays separate from infrastructure, service discovery uses Docker DNS, and local routing is centralized through Traefik and Nginx so additional projects can be added without duplicating databases, caches, or proxy services.

## License

MIT
