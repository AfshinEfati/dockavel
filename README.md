# Dockavel

[![CI](https://github.com/AfshinEfati/dockavel/actions/workflows/ci.yml/badge.svg)](https://github.com/AfshinEfati/dockavel/actions/workflows/ci.yml)

A configurable, multi-project local development environment for **Laravel and Node.js applications**, powered by Docker Compose and Nginx.

Dockavel is built for developers who maintain multiple projects with different runtime requirements. You can run several PHP versions side by side, enable only the databases and services you need, and route each local project to the appropriate runtime.

## Features

- Shared Docker environment for multiple local projects
- Multiple simultaneous PHP-FPM runtimes: **8.2, 8.3, 8.4, 8.5**
- One reusable PHP Dockerfile parameterized by `PHP_VERSION`
- MySQL 8 and PostgreSQL 17
- Redis 7
- Node.js 24 with Supervisor
- phpMyAdmin and pgAdmin as optional database UIs
- Docker Compose profiles so unused services are not started or built
- Interactive installer for selecting the local stack before build
- Nginx routing per project and per PHP runtime
- PHP support for both `pdo_mysql` and `pdo_pgsql`
- UID/GID mapping to avoid root-owned project files
- Configurable Debian, Composer, and npm mirrors
- GitHub Actions validation across multiple stack combinations

## Architecture

```text
Browser
   │
   ▼
 Nginx
   │
   ├── project-a.local ──► php82:9000
   ├── project-b.local ──► php84:9000
   ├── project-c.local ──► php85:9000
   └── frontend.local  ──► node:3000

Applications
   │
   ├── MySQL      (optional)
   ├── PostgreSQL (optional)
   └── Redis      (optional)

Developer tools
   │
   ├── phpMyAdmin (optional)
   └── pgAdmin    (optional)
```

All PHP runtimes mount the same `projects/` directory, so different Laravel projects can use different PHP versions at the same time.

## Quick Start

Clone the repository:

```bash
git clone https://github.com/AfshinEfati/dockavel.git
cd dockavel
```

Run the interactive installer:

```bash
chmod +x setup.sh
./setup.sh
```

Example:

```text
Dockavel Setup

PHP runtimes
------------
1) PHP 8.2
2) PHP 8.3
3) PHP 8.4
4) PHP 8.5

Select one or more versions (example: 1 4): 1 4

Databases
---------
1) MySQL 8
2) PostgreSQL 17

Select databases (example: 1 2): 1 2
Enable Redis? [Y/n] y
Enable Node.js? [Y/n] y
Enable phpMyAdmin? [y/N] n
Enable pgAdmin? [y/N] y
```

The installer updates `COMPOSE_PROFILES` in `.env`, validates the resulting Compose configuration, and can build/start the selected stack immediately.

For example:

```env
COMPOSE_PROFILES=php82,php85,mysql,postgres,redis,node,postgres-ui
```

Only services belonging to those profiles are activated.

## Manual Configuration

If you do not want to use the installer:

```bash
cp .env.example .env
```

Edit `COMPOSE_PROFILES` yourself:

```env
COMPOSE_PROFILES=php82,php85,mysql,redis,node
```

Then run:

```bash
docker compose up -d --build
```

Available profiles:

| Profile | Service |
| --- | --- |
| `php82` | PHP 8.2 FPM |
| `php83` | PHP 8.3 FPM |
| `php84` | PHP 8.4 FPM |
| `php85` | PHP 8.5 FPM |
| `mysql` | MySQL 8 |
| `postgres` | PostgreSQL 17 |
| `redis` | Redis 7 |
| `node` | Node.js 24 |
| `mysql-ui` | phpMyAdmin |
| `postgres-ui` | pgAdmin |

Nginx is a core service and does not require a profile.

## Running Multiple PHP Versions Simultaneously

This is one of Dockavel's main use cases.

Example project layout:

```text
projects/
├── legacy-crm/      # PHP 8.2
├── booking-api/     # PHP 8.4
└── ledger-core/     # PHP 8.5
```

Enable the required runtimes:

```env
COMPOSE_PROFILES=php82,php84,php85,mysql,postgres,redis
```

Then route each Nginx virtual host to the correct service.

PHP 8.2:

```nginx
fastcgi_pass php82:9000;
```

PHP 8.4:

```nginx
fastcgi_pass php84:9000;
```

PHP 8.5:

```nginx
fastcgi_pass php85:9000;
```

The `php82` service also exposes the network alias `php` for backward compatibility with older Dockavel Nginx configurations.

## Adding a Laravel Project

Place the project inside:

```text
projects/my-api
```

Create a file such as:

```text
nginx/conf.d/my-api.local.conf
```

Example:

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

Add the domain to the host machine:

```text
127.0.0.1 my-api.local
```

Restart Nginx:

```bash
docker compose restart nginx
```

## PHP Commands

Enter a PHP runtime:

```bash
docker compose exec php82 bash
```

```bash
docker compose exec php84 bash
```

```bash
docker compose exec php85 bash
```

Then run commands against any mounted project:

```bash
cd /var/www/my-api
composer install
php artisan migrate
```

## MySQL

Container address:

```text
mysql:3306
```

Default host address:

```text
127.0.0.1:13307
```

Laravel example:

```env
DB_CONNECTION=mysql
DB_HOST=mysql
DB_PORT=3306
```

## PostgreSQL

Container address:

```text
postgres:5432
```

Default host address:

```text
127.0.0.1:15432
```

Laravel example:

```env
DB_CONNECTION=pgsql
DB_HOST=postgres
DB_PORT=5432
```

Every Dockavel PHP runtime includes both `pdo_mysql` and `pdo_pgsql`, so the same runtime image can work with either database.

## Redis

Container address:

```text
redis:6379
```

Default host address:

```text
127.0.0.1:16379
```

## Database UIs

When `mysql-ui` is enabled, phpMyAdmin is available at:

```text
http://127.0.0.1:18080
```

Use `mysql` as the server host.

When `postgres-ui` is enabled, pgAdmin is available at:

```text
http://127.0.0.1:18081
```

Use `postgres` as the server host when registering the database inside pgAdmin.

## Node.js Projects

Node applications share the `node` container and the `projects/` directory.

Applications can listen on independent ports such as:

```text
3000
3001
3002
```

Use `nginx/template-node.conf.example` as a starting point for reverse-proxy configuration.

Supervisor configuration belongs in:

```text
supervisor/conf.d/
```

## Environment Configuration

The default `.env.example` uses public package repositories and local-development credentials.

Important variables include:

```env
COMPOSE_PROFILES=php82,php85,mysql,redis,node,mysql-ui

MYSQL_PORT=13307
POSTGRES_PORT=15432
REDIS_PORT=16379
PHPMYADMIN_PORT=18080
PGADMIN_PORT=18081
```

Package repositories and Debian mirrors can be overridden without changing committed files.

## Useful Commands

Show active services:

```bash
docker compose ps
```

Start selected services:

```bash
docker compose up -d
```

Build and start selected services:

```bash
docker compose up -d --build
```

Stop the stack:

```bash
docker compose down
```

Build one runtime explicitly:

```bash
docker compose --profile php84 build php84
```

View logs:

```bash
docker compose logs -f
```

Validate the active Compose configuration:

```bash
docker compose config
```

## Local Files and Git

Local projects and machine-specific application configuration are intentionally excluded from version control:

```text
projects/*
nginx/conf.d/*
supervisor/conf.d/*
.env
```

This keeps application code, credentials, local routing, and machine-specific configuration out of the Dockavel repository.

## CI

GitHub Actions validates several profile combinations and builds every maintained PHP runtime plus the Node runtime.

This helps catch invalid Compose dependencies and runtime-specific Dockerfile problems before changes reach `main`.

## Roadmap

The next major step is project-level configuration, for example:

```yaml
name: ledger
local_domain: ledger.local
php: "8.5"
database: postgres
redis: true
node: false
```

The goal is for Dockavel to generate Nginx configuration and project metadata through a command such as:

```bash
./dockavel project:add
```

## License

MIT
