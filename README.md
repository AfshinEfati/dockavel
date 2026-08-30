# Dockavel

A lightweight multi-project development environment for **Laravel and Node.js applications**, powered by Docker Compose, Nginx, PHP-FPM, MySQL, Redis, and Supervisor.

Dockavel is designed for developers who work on multiple backend and frontend projects locally and want to share one reusable development stack instead of maintaining a separate infrastructure setup for every project.

## Features

* Shared Docker environment for multiple local projects
* PHP 8.2 and PHP 8.5 runtimes
* Node.js 24 runtime
* Nginx reverse proxy
* MySQL 8
* Redis
* phpMyAdmin
* Supervisor for long-running Node.js processes
* Per-project local domains
* Laravel and Node.js Nginx templates
* UID/GID mapping to avoid root-owned project files
* Configurable package mirrors and registries
* Docker Compose validation and image builds through GitHub Actions

## Architecture

```text
Browser
   │
   ▼
 Nginx
   │
   ├──────────────► Laravel Project
   │                    │
   │                    ├── PHP 8.2 (php:9000)
   │                    │
   │                    └── PHP 8.5 (php85:9000)
   │
   └──────────────► Node / Nuxt Project
                        │
                        └── Node container
                              │
                              └── Supervisor

Applications
   │
   ├── MySQL
   └── Redis

Developer
   │
   └── phpMyAdmin
```

## Services

| Service      | Purpose                              |
| ------------ | ------------------------------------ |
| `php`        | PHP 8.2 FPM runtime                  |
| `php85`      | PHP 8.5 FPM runtime                  |
| `node`       | Node.js 24 development runtime       |
| `nginx`      | Local HTTP routing and reverse proxy |
| `mysql`      | Shared MySQL 8 database              |
| `redis`      | Shared Redis instance                |
| `phpmyadmin` | Browser-based MySQL administration   |

## Project Structure

```text
dockavel/
├── .github/
│   └── workflows/
│       └── ci.yml
├── nginx/
│   ├── conf.d/
│   │   └── .gitkeep
│   ├── template-laravel.conf.example
│   └── template-node.conf.example
├── projects/
│   └── .gitkeep
├── supervisor/
│   ├── conf.d/
│   │   └── .gitkeep
│   ├── example-node.conf
│   └── supervisord.conf
├── .env.example
├── Dockerfile
├── Dockerfile-php85
├── Dockerfile-node
├── docker-compose.yml
└── README.md
```

Local projects, Nginx configurations, and Supervisor application configurations are intentionally excluded from Git.

## Requirements

You need:

* Docker
* Docker Compose
* Git

On Windows, Docker Desktop with WSL2 is recommended.

## Installation

Clone the repository:

```bash
git clone https://github.com/AfshinEfati/dockavel.git
cd dockavel
```

Create your local environment file:

```bash
cp .env.example .env
```

Then build and start the stack:

```bash
docker compose build
docker compose up -d
```

Check running services:

```bash
docker compose ps
```

## Environment Configuration

The default `.env.example` uses public package repositories so the project can be built outside Iran without depending on regional infrastructure.

Example:

```env
UID=1000
GID=1000

PIE_IMAGE=ghcr.io/php/pie:bin

DEBIAN_MIRROR=http://deb.debian.org/debian
DEBIAN_SECURITY_MIRROR=http://deb.debian.org/debian-security

COMPOSER_REPOSITORY=https://repo.packagist.org
NPM_REGISTRY=https://registry.npmjs.org/

MYSQL_PORT=13307
MYSQL_ROOT_PASSWORD=root
MYSQL_DATABASE=laravel
MYSQL_USER=laravel
MYSQL_PASSWORD=secret

REDIS_PORT=16379

PHPMYADMIN_PORT=18080
```

These values are intended for local development.

Developers can override package repositories or mirrors in their own `.env` file without changing the repository configuration.

## Adding a Laravel Project

Place your Laravel project inside:

```text
projects/
```

Example:

```text
projects/my-api
```

Create an Nginx configuration using:

```text
nginx/template-laravel.conf.example
```

Example configuration:

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

        fastcgi_pass php:9000;
        fastcgi_index index.php;

        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param DOCUMENT_ROOT $document_root;
    }

    location ~ /\.ht {
        deny all;
    }
}
```

Save it as:

```text
nginx/conf.d/my-api.local.conf
```

Add the local domain to your hosts file:

```text
127.0.0.1 my-api.local
```

Restart Nginx:

```bash
docker compose restart nginx
```

Then open:

```text
http://my-api.local
```

## Choosing a PHP Version

Dockavel includes two PHP-FPM services.

For PHP 8.2:

```nginx
fastcgi_pass php:9000;
```

For PHP 8.5:

```nginx
fastcgi_pass php85:9000;
```

This makes it possible to run projects requiring different PHP versions inside the same development environment.

## Running Artisan Commands

For a PHP 8.2 project:

```bash
docker compose exec php bash
```

Then:

```bash
cd /var/www/my-api
php artisan migrate
```

For PHP 8.5:

```bash
docker compose exec php85 bash
```

## Adding a Node.js Project

Place the project inside:

```text
projects/
```

Example:

```text
projects/my-frontend
```

Node applications run inside the shared `node` container.

Each application should listen on its own port, for example:

```text
3000
3001
3002
```

Create an Nginx configuration based on:

```text
nginx/template-node.conf.example
```

Example:

```nginx
server {
    listen 80;
    server_name my-frontend.local;

    location / {
        proxy_pass http://node:3000;

        proxy_http_version 1.1;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        proxy_cache_bypass $http_upgrade;
    }
}
```

Add:

```text
127.0.0.1 my-frontend.local
```

to your hosts file.

## Running Node Applications with Supervisor

Dockavel uses Supervisor inside the Node container to keep development processes running.

Application-specific Supervisor configurations belong in:

```text
supervisor/conf.d/
```

Example:

```ini
[program:my-frontend]
directory=/var/www/my-frontend

command=npm run dev -- --host 0.0.0.0 --port 3000

autostart=true
autorestart=true
startretries=3

stopasgroup=true
killasgroup=true

stdout_logfile=/dev/fd/1
stdout_logfile_maxbytes=0

stderr_logfile=/dev/fd/2
stderr_logfile_maxbytes=0

environment=HOME="/var/www"
```

Restart the Node service after adding or changing Supervisor configuration:

```bash
docker compose restart node
```

View logs:

```bash
docker compose logs -f node
```

## MySQL

MySQL is available to containers through:

```text
mysql:3306
```

From the host machine, the default address is:

```text
127.0.0.1:13307
```

The host port can be changed through:

```env
MYSQL_PORT=13307
```

## Redis

Containers can access Redis through:

```text
redis:6379
```

From the host machine, the default address is:

```text
127.0.0.1:16379
```

## phpMyAdmin

phpMyAdmin is available by default at:

```text
http://127.0.0.1:18080
```

The port can be changed through:

```env
PHPMYADMIN_PORT=18080
```

Use `mysql` as the database host when connecting from phpMyAdmin.

## Useful Commands

Start the stack:

```bash
docker compose up -d
```

Stop it:

```bash
docker compose down
```

Rebuild containers:

```bash
docker compose build
```

Rebuild one runtime:

```bash
docker compose build php
```

```bash
docker compose build php85
```

```bash
docker compose build node
```

View logs:

```bash
docker compose logs -f
```

Enter PHP 8.2:

```bash
docker compose exec php bash
```

Enter PHP 8.5:

```bash
docker compose exec php85 bash
```

Enter Node:

```bash
docker compose exec node bash
```

Restart Nginx:

```bash
docker compose restart nginx
```

## Local Files and Git

The following directories are intentionally excluded from version control:

```text
projects/*
nginx/conf.d/*
supervisor/conf.d/*
```

Only `.gitkeep` placeholders are committed.

Your local `.env` file is also ignored.

This prevents application source code, machine-specific routing, credentials, and local development configuration from accidentally being committed to Dockavel.

## CI

GitHub Actions performs:

* Docker Compose configuration validation
* PHP 8.2 image build
* PHP 8.5 image build
* Node image build

The build matrix runs independently, so a failure in one runtime does not hide failures in the others.

## Why Dockavel?

Running every project with a completely separate Docker stack can create duplicated containers, duplicated databases, port conflicts, and unnecessary local resource usage.

Dockavel provides shared infrastructure while still allowing each application to keep its own source code, domain, runtime choice, and process configuration.

It is intended as a practical development environment rather than a production deployment platform.

## License

Dockavel is open-source software licensed under the MIT License.
