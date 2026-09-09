# Dockavel

[![CI](https://github.com/AfshinEfati/dockavel/actions/workflows/ci.yml/badge.svg)](https://github.com/AfshinEfati/dockavel/actions/workflows/ci.yml)

**English** | [فارسی](README.fa.md)

[Website](https://afshinefati.github.io/dockavel-site/) · [Documentation](https://afshinefati.github.io/dockavel-site/docs/) · [Contributing](CONTRIBUTING.md)

Dockavel is a lightweight, configurable local development environment for running multiple **Laravel and Node.js projects** on one shared Docker Compose stack.

It is designed for developers who maintain projects with different PHP versions, databases, local domains, and network constraints. Dockavel keeps the core small: enable only what you need, manage projects through a simple CLI, and avoid turning local development into a large configuration project of its own.

## Why Dockavel?

A normal one-project Compose file works well until you have several projects that need different PHP versions, databases, Node runtimes, or local domains. Dockavel provides one shared environment instead of duplicating the same infrastructure per project.

Typical use cases:

- Laravel projects that require different PHP versions
- Several local domains behind one Nginx instance
- Projects that share MySQL, PostgreSQL, Redis, or Node.js
- Development environments where direct access to global registries is unreliable
- Teams that want a repeatable local stack without a huge configuration surface

## Design Principles

Dockavel intentionally stays opinionated and small.

A feature belongs in the core when it does at least one of these:

1. speeds up project setup,
2. simplifies multi-project management,
3. reduces local-environment errors and debugging.

The goal is useful automation without becoming a large all-purpose stack.

## Features

- Multiple simultaneous PHP-FPM runtimes: **PHP 8.2, 8.3, 8.4, and 8.5**
- MySQL 8 and PostgreSQL 17 as optional database services
- Redis 7 as an optional shared service
- Node.js 24 as an optional shared runtime
- phpMyAdmin and pgAdmin as optional database UIs
- Docker Compose profiles so unused services stay disabled
- Interactive installer: `./setup.sh`
- Optional global CLI and terminal shortcuts such as `dockavel help`, `ds my-api`, `da my-api migrate`, and `dpl`
- Regional download-source presets for Docker images and package repositories
- Official/Global, IranServer, Runflare, China, and fully custom source configuration
- No hidden regional-registry fallback by design
- Nginx routing per project and per runtime
- Shared `projects/` directory across runtimes
- Project manager CLI: add, list, edit, and remove registration
- Project-aware `shell`, `artisan`, `composer`, and `npm` commands
- Read-only environment diagnostics with `dockavel doctor` or `ddoc`
- Read-only source connectivity checks with `dockavel source:test` or `dsrc`
- CI validation for Compose profiles, runtimes, shell scripts, project-command routing, and shortcut installation
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

All application runtimes mount:

```text
./projects → /var/www
```

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
| phpMyAdmin | upstream image | `mysql-ui` |
| pgAdmin | 9 | `postgres-ui` |
| Nginx | Alpine | always enabled |

PHP runtimes are built locally from public `serversideup/php:<version>-fpm` images through the selected Docker namespace/mirror. Node.js is built locally from the public `node:24-bookworm-slim` image through the selected Docker library mirror.

Dockavel does **not** require a Docker Hub account, GHCR account, or private Dockavel registry just to run the stack.

## Requirements

- Docker Engine or Docker Desktop
- Docker Compose v2 (`docker compose`)
- Bash
- An interactive terminal
- Port `80` available for Nginx

On Windows, using Dockavel inside **WSL2** is recommended.

Check Docker:

```bash
docker --version
docker compose version
```

## Quick Start

```bash
git clone https://github.com/AfshinEfati/dockavel.git
cd dockavel
chmod +x setup.sh dockavel
./setup.sh
```

The installer creates `.env` from `.env.example` on the first run and lets you select:

1. download source,
2. PHP runtimes,
3. databases,
4. optional services,
5. database tools,
6. whether to install the global `dockavel` command and shortcuts,
7. whether to build/start immediately.

Use `↑` / `↓` to move, `Space` to toggle selections, and `Enter` to confirm.

Example:

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

When you choose **Build and start**, setup runs the equivalent of:

```bash
docker compose pull --ignore-buildable
docker compose up -d --build
```

`--ignore-buildable` prevents Compose from trying to pull the locally built PHP and Node services as if they were prebuilt Dockavel images.

## Global CLI and Shortcuts

During setup, Dockavel can install a global `dockavel` command plus short terminal commands in `~/.local/bin`. You can also install them later:

```bash
./dockavel shortcuts:install
```

After reloading the shell when prompted, the CLI can be used from any directory:

```bash
dockavel help
dockavel project:list
```

Daily shortcuts:

```text
ds <project>             → dockavel shell <project>
da <project> ...         → dockavel artisan <project> ...
dco <project> ...        → dockavel composer <project> ...
dn <project> ...         → dockavel npm <project> ...
dpa                      → dockavel project:add
dpl                      → dockavel project:list
dpe <project>            → dockavel project:edit <project>
dpr <project>            → dockavel project:remove <project>
ddoc                     → dockavel doctor
dsrc                     → dockavel source:test
dh [command]             → dockavel help [command]
```

Examples:

```bash
ds my-api
da my-api migrate
dco my-api install
dn frontend run dev
dpl
dh artisan
```

`ddoc` is intentionally used instead of `dd` because `dd` is a standard Unix command.

Dockavel never overwrites an existing command or file with the same shortcut name. Shortcut installation is idempotent. If `~/.local/bin` is not already in `PATH`, Dockavel adds one managed PATH block to Bash or Zsh startup configuration and prints the reload command.

Manage shortcut installation with:

```bash
dockavel shortcuts:list
dockavel shortcuts:install
dockavel shortcuts:remove
```

`shortcuts:remove` removes only Dockavel-managed symlinks. It leaves the `~/.local/bin` PATH entry untouched because that directory may contain other user commands.

Full terminal help:

```bash
dockavel help
dockavel help shell
dh
dh composer
```

Before shortcut installation, all commands continue to work through `./dockavel`.

## Download Source Presets

Dockavel keeps Docker image sources and package repositories together as one preset. Selecting a regional preset does not intentionally fall back to another hidden registry.

### Official / Global

```text
Docker images : docker.io
Debian        : deb.debian.org
Composer      : repo.packagist.org
npm           : registry.npmjs.org
```

### Iran / IranServer

```text
Docker library   : docker.iranserver.com/library/
Docker namespace : docker.iranserver.com/
Debian            : mirror.iranserver.com
Composer          : composer.iranserver.com
npm               : npm.iranserver.com
```

Example base images through the selected mirror:

```text
docker.iranserver.com/serversideup/php:8.5-fpm
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

These values are stored in `.env`.

## Doctor: Environment Diagnostics

Run:

```bash
dockavel doctor
```

Doctor is **read-only**. It does not change `.env`, Docker settings, DNS, mirrors, containers, or the hosts file.

It currently checks:

- Docker CLI
- Docker daemon
- Docker Compose
- WSL detection
- `.env` availability
- port 80 ownership
- selected download-source preset
- Docker registry reachability
- Debian mirror reachability
- Debian security mirror reachability
- Composer repository reachability
- npm registry reachability
- HTTP response status, response time, and remote IP
- enabled/running stack services
- container health when a healthcheck is available

Example:

```text
Dockavel Doctor
===============

System
------
Docker CLI               ✅ Docker version ...
Docker daemon            ✅ reachable
Docker Compose           ✅ Docker Compose version ...
WSL                      ✅ detected
Port 80                  ✅ used by dockavel-nginx

Download source
---------------
Selected preset          ℹ️  iranserver
Docker registry          ✅ HTTP 401 · 0.37s · 185.x.x.x
Composer                 ✅ HTTP 200 · 0.34s · 185.x.x.x
npm                      ✅ HTTP 200 · 0.44s · 185.x.x.x
```

`HTTP 401` from a Docker registry `/v2/` endpoint is treated as reachable because authentication may be expected there.

Doctor also performs a read-only IPv4 retry when the default route fails, which helps identify broken IPv6/default routing without changing system networking.

## Testing the Current Download Source

Run:

```bash
dockavel source:test
```

This checks the endpoints currently configured in `.env` without changing the selected preset.

It is especially useful before a large pull/build on restricted or unstable networks.

## Incrementally Changing the Stack

You do not need to delete the stack just to add another optional service.

Re-run:

```bash
./setup.sh
```

Keep existing selections and add the new service. Compose reuses existing images, build cache, volumes, and unchanged containers whenever possible.

Persistent database volumes are not removed by running setup again.

## Project Layout

```text
Dockavel/
├── projects/
│   ├── legacy-crm/
│   │   └── .dockavel.yml
│   ├── booking-api/
│   │   └── .dockavel.yml
│   └── frontend/
│       └── .dockavel.yml
├── lib/
│   ├── help.sh
│   ├── project-manager.sh
│   ├── project-commands.sh
│   └── shortcuts.sh
├── nginx/
│   ├── conf.d/
│   ├── template-laravel.conf.example
│   └── template-node.conf.example
├── Dockerfile
├── Dockerfile-node
├── docker-compose.yml
├── dockavel
├── setup.sh
└── .env
```

Local projects, generated Nginx configs, `.dockavel.yml` files inside local projects, and `.env` are machine-specific and are not intended to be committed to the Dockavel repository.

## Project Manager

Project Manager registers an **existing** project inside `projects/`. It does not create a Laravel or Node application for you.

### Add a project

```bash
dockavel project:add
# or: dpa
```

The command:

- detects Laravel from `artisan` + `composer.json`
- detects Node.js from `package.json`
- asks for project name and local domain
- only offers PHP runtimes already enabled in the current stack
- only offers MySQL/PostgreSQL when those services are enabled
- asks whether to use Redis/Node when available
- generates project metadata
- generates Nginx configuration from the existing templates
- validates Nginx before applying the new registration
- reloads Nginx when it is running
- rolls generated files back if Nginx validation/application fails
- prints the required hosts-file entry instead of modifying the host machine automatically

Example metadata:

```yaml
version: 1
name: "my-api"
type: "laravel"
path: "my-api"
domain: "my-api.local"
php: "8.5"
database: "postgres"
redis: true
node: true
```

For a Node.js project, metadata uses the selected internal application port instead of a PHP version.

### List projects

```bash
dpl
# or: dockavel project:list
```

Example:

```text
NAME                 TYPE       DOMAIN                       RUNTIME        DATABASE
my-api               laravel    my-api.local                 PHP 8.5        postgres
frontend             node       frontend.local               Node :3000     none
```

### Edit a project

Interactive selection:

```bash
dockavel project:edit
```

Direct selection by project name:

```bash
dpe my-api
```

Editable settings include:

- project name
- local domain
- PHP runtime for Laravel projects
- database
- Redis usage
- shared Node runtime usage
- Node application port for Node.js projects

Project path and detected project type stay fixed during edit.

Edits regenerate metadata/Nginx configuration and use rollback if validation or reload fails.

### Remove a project registration

Interactive:

```bash
dockavel project:remove
```

Direct:

```bash
dpr my-api
```

`project:remove` removes Dockavel registration only:

```text
projects/my-api/.dockavel.yml
nginx/conf.d/my-api.local.conf
```

It **never deletes the project source directory**.

The command validates/reloads Nginx and restores removed Dockavel files if applying the change fails.

## Project-aware Commands

Once a project is registered, Dockavel can route common development commands through that project's metadata.

```bash
ds my-api
da my-api migrate
dco my-api install
dn frontend install
```

### `shell`

For Laravel projects, `shell` opens Bash in the PHP runtime stored in `.dockavel.yml`. For Node projects it opens the shared Node runtime.

```bash
ds legacy-api   # php82 if metadata says php: "8.2"
ds my-api       # php85 if metadata says php: "8.5"
ds frontend     # node for a Node project
```

### `artisan`

Runs `php artisan` in the project's configured PHP runtime and working directory:

```bash
da my-api migrate
da my-api queue:work
da my-api route:list
```

### `composer`

Runs Composer in the same project-aware PHP runtime:

```bash
dco my-api install
dco my-api update
dco my-api require vendor/package
```

### `npm`

Runs npm in the shared Node runtime. It works for Node projects and Laravel projects with `node: true` in their metadata.

```bash
dn my-api install
dn my-api run build
dn frontend run dev
```

Before running a project-aware command, Dockavel validates that the selected runtime is enabled and running, the project still exists on the host, and the project directory is visible inside the runtime. If Docker Desktop has a stale `projects/` bind mount, the command stops before executing the requested tool and reports the visibility problem.

Arguments after the project selector are passed directly to the underlying command instead of being wrapped in an extra shell.

## Hosts File

Dockavel intentionally does not edit the host machine's hosts file automatically.

After project registration, add the printed entry manually, for example:

```text
127.0.0.1 my-api.local
```

On Windows the hosts file is:

```text
C:\Windows\System32\drivers\etc\hosts
```

You normally need administrator privileges to save it.

## Running Multiple PHP Versions

Example:

```text
projects/
├── old-app/       # PHP 8.2
├── internal-api/  # PHP 8.4
└── new-app/       # PHP 8.5
```

Nginx can route each project to its selected FPM service:

```text
php82:9000
php84:9000
php85:9000
```

All enabled runtimes can stay active at the same time.

## PHP and Composer Commands

For registered projects, the short project-aware commands are the normal path after shortcut installation:

```bash
ds my-api
da my-api migrate
dco my-api install
```

Low-level runtime commands are still available when needed:

```bash
docker compose exec php82 php -v
docker compose exec php85 php -v
docker compose exec php85 bash
```

Note the naming difference:

```text
Compose service : php85
Container name  : dockavel-php85
Local image     : dev-stack-php85
```

For low-level Compose usage, prefer the Compose service name rather than the container name.

## Node.js Projects

For registered Node projects or Laravel projects with Node enabled:

```bash
dn frontend install
dn frontend run dev
ds frontend
```

Low-level shared runtime checks are still available:

```bash
docker compose exec node node --version
docker compose exec node npm --version
```

Node applications registered through Project Manager use ports in the internal range `3000-3099` and are exposed through Nginx.

## MySQL

Inside Docker:

```text
mysql:3306
```

Host:

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

Persistent volume: `mysql_data`.

## PostgreSQL

Inside Docker:

```text
postgres:5432
```

Host:

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

Persistent volume: `postgres_data`.

## Redis

Inside Docker:

```text
redis:6379
```

Host:

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

Use:

```text
Host: postgres
Port: 5432
```

Persistent volume: `pgadmin_data`.

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

## Important `.env` Values

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

## Useful Commands

```bash
# Help
dockavel help
dh

# Dockavel diagnostics
ddoc
dsrc

# Project management
dpa
dpl
dpe my-api
dpr my-api

# Project-aware runtime commands
ds my-api
da my-api migrate
dco my-api install
dn frontend install

# Shortcut management
dockavel shortcuts:list
dockavel shortcuts:install
dockavel shortcuts:remove

# Stack status
docker compose ps

# Start / build
docker compose up -d
docker compose up -d --build

# Stop without deleting database volumes
docker compose down

# Logs
docker compose logs -f

# Validate Compose
docker compose config
```

## Data Safety

Database data lives in named Docker volumes.

A normal shutdown does not delete them:

```bash
docker compose down
```

This is destructive and removes persistent volumes:

```bash
docker compose down -v
```

Use destructive cleanup only when you intentionally want a fresh database state.

`project:remove` is different: it removes only Dockavel metadata/Nginx registration and never deletes the source project.

## Troubleshooting

### Diagnose before rebuilding

Start with:

```bash
ddoc
```

For source-only connectivity:

```bash
dsrc
```

This helps distinguish Docker/project configuration problems from DNS, TLS, timeout, mirror, or routing problems before doing expensive rebuilds.

### Port 80 is already in use

Doctor reports whether port 80 is available, used by `dockavel-nginx`, or occupied elsewhere.

### A regional mirror cannot resolve an image

Verify that the selected mirror actually provides/proxies the upstream image. Dockavel does not intentionally fall back to another registry when a regional source is selected.

Re-run `./setup.sh` and explicitly choose another preset or `Custom endpoints` when needed.

### Project exists on the host but is not visible in a runtime

Project-aware commands verify the project path before execution. If Docker Desktop/WSL has a stale bind mount, Dockavel reports the visibility problem instead of launching Artisan, Composer, npm, or a shell in the wrong state. Restarting Docker Desktop can resolve a stale bind mount when the host path is otherwise correct.

### Add a service without deleting the existing stack

Re-run:

```bash
./setup.sh
```

Keep existing profiles selected and add the new service.

### Validate current state

```bash
grep '^COMPOSE_PROFILES=' .env
docker compose config
docker compose ps -a
dpl
```

## Local Files and Git

These are intentionally local/machine-specific:

```text
projects/*
nginx/conf.d/*
.env
```

This keeps local application code, domains, credentials, and machine-specific configuration out of the Dockavel repository.

## CI

GitHub Actions currently validates:

- multiple Compose profile combinations
- PHP 8.2, 8.3, 8.4, and 8.5 builds
- required PHP runtime capabilities
- Node.js 24 build/runtime
- `setup.sh`, `dockavel`, Project Manager, Project Commands, help and shortcuts shell syntax
- project-aware command routing with a fake Docker CLI
- global shortcut installation/removal and symlink routing
- executable CLI entry point

## Roadmap

Completed core foundations:

```text
✅ Configurable stack
✅ Multiple PHP runtimes
✅ Regional download sources
✅ MySQL / PostgreSQL / Redis / Node
✅ Doctor / source diagnostics
✅ Project add / list / edit / remove
✅ Project-aware shell / Artisan / Composer / npm
✅ Global Dockavel CLI / help / terminal shortcuts
```

Likely next productivity work:

```text
- smarter project detection and runtime suggestions
- database helpers for repeated local workflows
- additional Doctor / project health diagnostics
```

These remain separate features and should stay explicit rather than adding hidden automation.

## Contributing

Issues and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

User-facing features, services, runtimes, source presets, CLI commands, configuration changes, ports and workflows should keep the runtime README files and the public [website/documentation](https://afshinefati.github.io/dockavel-site/docs/) synchronized.

## License

MIT
