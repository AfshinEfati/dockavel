# Dockavel

[![CI](https://github.com/AfshinEfati/dockavel/actions/workflows/ci.yml/badge.svg)](https://github.com/AfshinEfati/dockavel/actions/workflows/ci.yml)

**English** | [فارسی](README.fa.md)

Dockavel is a configurable, multi-project local development environment for **Laravel and Node.js applications**, powered by Docker Compose and Nginx.

It is designed for developers who maintain several projects with different runtime requirements. You can run multiple PHP versions side by side, enable only the databases and services you need, use regional package/image mirrors when public registries are slow or unavailable, and route every local project to the correct runtime through Nginx.

## Why Dockavel?

A normal one-project Docker Compose file works well until you have several projects that need different PHP versions, databases, Node runtimes, or local domains. Dockavel provides one shared development stack instead of duplicating infrastructure for every project.

Typical use cases:

- Laravel projects that require different PHP versions
- Several local domains behind one Nginx instance
- Projects that share MySQL, PostgreSQL, Redis, or Node.js
- Development environments where direct access to global registries is unreliable
- Teams that want a repeatable local stack without hard-coding every service

## Features

- Multiple simultaneous PHP-FPM runtimes: **PHP 8.2, 8.3, 8.4, and 8.5**
- MySQL 8 and PostgreSQL 17 as optional database services
- Redis 7 as an optional shared cache/service
- Node.js 24 as an optional shared runtime
- phpMyAdmin and pgAdmin as optional database UIs
- Docker Compose profiles so unused services stay disabled
- Interactive terminal installer (`setup.sh`)
- Regional download-source presets for Docker images and package repositories
- Official/Global, IranServer, Runflare, China, and fully custom source configuration
- Nginx routing per project and per PHP runtime
- Shared `projects/` directory across runtimes
- PHP support for MySQL, PostgreSQL, Redis, Composer, and common Laravel requirements
- UID/GID-aware PHP builds to reduce root-owned files on the host
- Incremental stack changes by re-running the installer
- CI validation for Compose profiles and maintained runtimes
- No private or Dockavel-specific registry images are required

## Architecture

```text
Browser
   │
   ▼
 Nginx :80
   │
   ├── legacy.local   ──► php82:9000
   ├── api.local      ──► php84:9000
   ├── modern.local   ──► php85:9000
   └── frontend.local ──► node:3000

Shared services
   │
   ├── MySQL 8       (optional)
   ├── PostgreSQL 17 (optional)
   ├── Redis 7       (optional)
   └── Node.js 24    (optional)

Database tools
   │
   ├── phpMyAdmin    (optional)
   └── pgAdmin       (optional)
```

All application containers mount the same `projects/` directory. This makes it possible to keep several projects in one workspace while routing each project to the PHP runtime it actually needs.

## Supported Stack

| Component | Version / Type | Compose profile |
| --- | --- | --- |
| PHP-FPM | 8.2 | `php82` |
| PHP-FPM | 8.3 | `php83` |
| PHP-FPM | 8.4 | `php84` |
| PHP-FPM | 8.5 | `php85` |
| MySQL | 8.0 | `mysql` |
| PostgreSQL | 17 Alpine | `postgres` |
| Redis | 7 Alpine | `redis` |
| Node.js | 24 Bookworm Slim | `node` |
| phpMyAdmin | latest upstream image | `mysql-ui` |
| pgAdmin | 9 | `postgres-ui` |
| Nginx | Alpine | always enabled |

PHP runtimes are built locally from the public `serversideup/php:<version>-fpm` images through the selected Docker namespace/mirror. Node.js is built locally from the public `node:24-bookworm-slim` image through the selected Docker library mirror.

Dockavel does **not** require an account on Docker Hub, GHCR, or a private Dockavel image registry just to run the stack.

## Requirements

You need:

- Docker Engine or Docker Desktop
- Docker Compose v2 (`docker compose`)
- Bash
- An interactive terminal
- Port `80` available on the host for Nginx

On Windows, using Dockavel inside **WSL2** is recommended.

Check Docker before installation:

```bash
docker --version
docker compose version
```

## Quick Start

Clone the repository:

```bash
git clone https://github.com/AfshinEfati/dockavel.git
cd dockavel
```

Make the installer executable and run it:

```bash
chmod +x setup.sh
./setup.sh
```

The installer creates `.env` from `.env.example` on the first run, then lets you select:

1. Download source
2. PHP runtimes
3. Databases
4. Optional services
5. Database tools
6. Whether to build/start immediately

Use:

- `↑` / `↓` to move
- `Space` to select/unselect
- `Enter` to confirm

Example stack:

```text
Download source
[x] Iran / IranServer

PHP runtimes
[x] PHP 8.2
[ ] PHP 8.3
[ ] PHP 8.4
[x] PHP 8.5

Databases
[x] MySQL 8
[x] PostgreSQL 17

Optional services
[x] Redis 7
[x] Node.js 24

Database tools
[x] phpMyAdmin
[ ] pgAdmin
```

The resulting `.env` may contain:

```env
COMPOSE_PROFILES=php82,php85,mysql,postgres,redis,node,mysql-ui
```

The installer validates the generated Compose configuration before starting anything.

When you choose **Build and start**, it runs the equivalent of:

```bash
docker compose pull --ignore-buildable
docker compose up -d --build
```

`--ignore-buildable` prevents `docker compose pull` from trying to pull the locally built PHP and Node services as if they were prebuilt Dockavel images.

## Download Source Presets

Dockavel keeps Docker image sources and package repositories together as a preset. Selecting a regional preset does not intentionally fall back to another hidden registry.

### Official / Global

Uses the normal public sources:

```text
Docker images : docker.io
Debian        : deb.debian.org
Composer      : repo.packagist.org
npm           : registry.npmjs.org
```

### Iran / IranServer

Uses IranServer endpoints for Docker images and package repositories:

```text
Docker library   : docker.iranserver.com/library/
Docker namespace : docker.iranserver.com/
Debian            : mirror.iranserver.com
Composer          : composer.iranserver.com
npm               : npm.iranserver.com
```

For example, PHP 8.2 is based on:

```text
docker.iranserver.com/serversideup/php:8.2-fpm
```

and Node.js is based on:

```text
docker.iranserver.com/library/node:24-bookworm-slim
```

### Iran / Runflare

Uses Runflare Docker, Debian, Composer, and npm mirrors. Availability and request quotas are controlled by Runflare and may change over time.

### China / regional mirrors

Uses DaoCloud for Docker images, Tsinghua mirrors for Debian, Aliyun for Composer, and npmmirror for npm.

### Custom endpoints

You can provide your own:

- Docker library prefix
- Docker namespace prefix
- Debian mirror
- Debian security mirror
- Composer repository
- npm registry
- npm strict-SSL setting

The values are written to `.env`; committed project files do not need to be edited.

## How PHP Runtimes Work

Dockavel uses one parameterized `Dockerfile` for every PHP version.

The selected runtime is passed through `PHP_VERSION`, for example:

```text
serversideup/php:8.2-fpm
serversideup/php:8.3-fpm
serversideup/php:8.4-fpm
serversideup/php:8.5-fpm
```

The Docker namespace prefix is supplied by the selected download-source preset, so the same Dockerfile can work with global or regional mirrors.

Each PHP container mounts:

```text
./projects → /var/www
```

The PHP services are named:

```text
php82
php83
php84
php85
```

`php82` also exposes the network alias `php` for backward compatibility with older Dockavel Nginx configurations.

## Incrementally Changing the Stack

You do not need to delete the current stack just to add another optional service.

Re-run:

```bash
./setup.sh
```

Keep the existing selections and add the new service. For example, an installation that originally used:

```env
COMPOSE_PROFILES=php82,php85,mysql,redis,node,mysql-ui
```

can later add PostgreSQL and become:

```env
COMPOSE_PROFILES=php82,php85,mysql,postgres,redis,node,mysql-ui
```

Docker Compose reuses existing images, build cache, volumes, and unchanged containers whenever possible and creates the newly enabled service as needed.

Persistent database volumes are not removed by running the installer again.

## Project Layout

A typical workspace looks like this:

```text
Dockavel/
├── projects/
│   ├── legacy-crm/
│   ├── booking-api/
│   └── frontend/
├── nginx/
│   ├── conf.d/
│   ├── template-laravel.conf.example
│   └── template-node.conf.example
├── Dockerfile
├── Dockerfile-node
├── docker-compose.yml
├── setup.sh
└── .env
```

Local projects, generated Nginx configs, and `.env` are intentionally excluded from Git.

## Adding a Laravel Project

Put the project inside:

```text
projects/my-api
```

Create an Nginx configuration in:

```text
nginx/conf.d/my-api.local.conf
```

Example for a PHP 8.5 project:

```nginx
server {
    listen 80;
    server_name my-api.local;

    root /var/www/my-api/public;
    index index.php index.html;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_pass php85:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param DOCUMENT_ROOT $document_root;
    }

    location ~ /\.ht {
        deny all;
    }
}
```

Add the domain to the host machine's hosts file:

```text
127.0.0.1 my-api.local
```

Then restart Nginx:

```bash
docker compose restart nginx
```

You can also start from:

```text
nginx/template-laravel.conf.example
```

## Running Multiple PHP Versions

Example:

```text
projects/
├── old-app/       # PHP 8.2
├── internal-api/  # PHP 8.4
└── new-app/       # PHP 8.5
```

Nginx can route each domain to a different FPM service:

```nginx
fastcgi_pass php82:9000;
```

```nginx
fastcgi_pass php84:9000;
```

```nginx
fastcgi_pass php85:9000;
```

All runtimes can stay active at the same time.

## PHP and Composer Commands

Run PHP directly in a runtime:

```bash
docker compose exec php82 php -v
docker compose exec php85 php -v
```

Open a shell:

```bash
docker compose exec php85 bash
```

Run project commands:

```bash
docker compose exec php85 bash
cd /var/www/my-api
composer install
php artisan migrate
```

Composer uses the repository configured by the selected download-source preset.

## Node.js Projects

The Node container mounts the same `projects/` directory at `/var/www`.

Check the runtime:

```bash
docker compose exec node node --version
docker compose exec node npm --version
```

Install dependencies for a project:

```bash
docker compose exec node bash
cd /var/www/frontend
npm install
```

A Node application can listen on ports in the container range `3000-3099` and be exposed through Nginx.

Use:

```text
nginx/template-node.conf.example
```

as a starting point for reverse-proxy configuration.

## MySQL

Internal Docker address:

```text
mysql:3306
```

Host address:

```text
127.0.0.1:13307
```

Laravel example:

```env
DB_CONNECTION=mysql
DB_HOST=mysql
DB_PORT=3306
DB_DATABASE=laravel
DB_USERNAME=laravel
DB_PASSWORD=secret
```

MySQL data is stored in the persistent Docker volume `mysql_data`.

## PostgreSQL

Internal Docker address:

```text
postgres:5432
```

Host address:

```text
127.0.0.1:15432
```

Laravel example:

```env
DB_CONNECTION=pgsql
DB_HOST=postgres
DB_PORT=5432
DB_DATABASE=laravel
DB_USERNAME=laravel
DB_PASSWORD=secret
```

PostgreSQL data is stored in the persistent Docker volume `postgres_data`.

## Redis

Internal Docker address:

```text
redis:6379
```

Host address:

```text
127.0.0.1:16379
```

Laravel example:

```env
REDIS_HOST=redis
REDIS_PORT=6379
```

## Database UIs

### phpMyAdmin

When `mysql-ui` is enabled:

```text
http://127.0.0.1:18080
```

Use `mysql` as the database server host.

### pgAdmin

When `postgres-ui` is enabled:

```text
http://127.0.0.1:18081
```

Register PostgreSQL using `postgres` as the host and port `5432`.

pgAdmin data is stored in the persistent Docker volume `pgadmin_data`.

## Default Host Ports

| Service | Host | Container |
| --- | ---: | ---: |
| Nginx | `80` | `80` |
| MySQL | `13307` | `3306` |
| PostgreSQL | `15432` | `5432` |
| Redis | `16379` | `6379` |
| phpMyAdmin | `18080` | `80` |
| pgAdmin | `18081` | `80` |

Except for Nginx, published service ports are bound to `127.0.0.1` by default.

## Environment Configuration

Important `.env` variables:

```env
UID=1000
GID=1000

COMPOSE_PROFILES=php82,php85,mysql,redis,node,mysql-ui
DOWNLOAD_SOURCE_PRESET=official

DOCKER_LIBRARY_PREFIX=docker.io/library/
DOCKER_NAMESPACE_PREFIX=docker.io/

DEBIAN_MIRROR=https://deb.debian.org/debian
DEBIAN_SECURITY_MIRROR=https://deb.debian.org/debian-security
COMPOSER_REPOSITORY=https://repo.packagist.org
NPM_REGISTRY=https://registry.npmjs.org/
NPM_STRICT_SSL=true
```

Database credentials and host ports are also configurable in `.env`.

For local development, change default passwords when the environment is shared with other users or exposed beyond the local machine.

## Useful Commands

Show active services:

```bash
docker compose ps
```

Start the configured stack:

```bash
docker compose up -d
```

Build and start buildable runtimes:

```bash
docker compose up -d --build
```

Stop containers without deleting database volumes:

```bash
docker compose down
```

View logs:

```bash
docker compose logs -f
```

Validate Compose configuration:

```bash
docker compose config
```

Check PHP modules:

```bash
docker compose exec php82 php -m
docker compose exec php85 php -m
```

Check Redis:

```bash
docker compose exec redis redis-cli ping
```

Check PostgreSQL readiness:

```bash
docker compose exec postgres sh -lc 'pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
```

## Data Safety

Database data lives in named Docker volumes.

A normal shutdown:

```bash
docker compose down
```

does not delete those volumes.

Commands such as the following are destructive and remove persistent data:

```bash
docker compose down -v
```

Use destructive cleanup only when you intentionally want a completely fresh database state.

## Troubleshooting

### Port 80 is already in use

Find the process/container currently using the port and stop it, or change the Nginx port mapping in `docker-compose.yml`.

### A regional mirror cannot resolve an image

Verify that the selected mirror actually provides/proxies the upstream image. Dockavel does not intentionally fall back to an unrelated registry when a regional source is selected.

You can re-run:

```bash
./setup.sh
```

and select another preset or `Custom endpoints`.

### Existing services should not be deleted when adding a service

Re-run `./setup.sh`, keep the existing profiles selected, add the new service, and start the stack. Compose should reuse unchanged resources and create the newly enabled service.

### Check generated configuration

```bash
grep '^COMPOSE_PROFILES=' .env
docker compose config
docker compose ps -a
```

## Local Files and Git

The following are intentionally local/machine-specific:

```text
projects/*
nginx/conf.d/*
.env
```

This keeps application code, local domains, credentials, and machine-specific settings out of the Dockavel repository.

## CI

GitHub Actions currently validates:

- Multiple Compose profile combinations
- PHP 8.2, 8.3, 8.4, and 8.5 builds
- Required PHP runtime capabilities
- Node.js 24 build/runtime
- Bash/POSIX shell syntax

The goal is to catch configuration and runtime regressions before changes reach `main`.

## Roadmap

The next planned step is project-level metadata and project management.

Example:

```yaml
name: ledger
local_domain: ledger.local
php: "8.5"
database: postgres
redis: true
node: false
```

Planned command:

```bash
./dockavel project:add
```

The goal is for Dockavel to generate and maintain per-project Nginx/runtime configuration instead of requiring manual project setup.

## Contributing

Issues and pull requests are welcome. When changing Docker sources, runtime versions, or installer behavior, please keep regional-source behavior explicit and avoid hidden registry fallbacks.

## License

MIT
