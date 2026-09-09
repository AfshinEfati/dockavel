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
- Developers who want to use Docker-backed local projects without memorizing Docker commands

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
- Official/Global, IranServer, Runflare, China, and fully custom source configuration
- No hidden regional-registry fallback by design
- Nginx routing per project and per runtime
- Shared `projects/` directory across runtimes
- Project manager CLI: add, list, edit, and remove registration
- Project-aware shell, Artisan, Composer, and npm commands
- Optional global `dockavel` command so normal use does not require `./dockavel`
- Short terminal commands such as `ds`, `da`, `dco`, `dn`, and `dpl`
- Full terminal help with `dockavel help`, `dh`, and per-command topics
- Read-only environment diagnostics with `dockavel doctor`
- Read-only source connectivity checks with `dockavel source:test`
- CI validation for Compose profiles, runtimes, shell scripts, project-command routing, and shortcuts
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

## Quick Start

```bash
git clone https://github.com/AfshinEfati/dockavel.git
cd dockavel
chmod +x setup.sh dockavel
./setup.sh
```

The installer lets you select the download source, PHP runtimes, databases, optional services, database tools, global CLI shortcuts, and whether to build/start immediately.

When shortcut installation is accepted, Dockavel installs managed symlinks in `~/.local/bin`. If that directory is not already in `PATH`, setup adds one managed PATH block to Bash or Zsh startup configuration and prints the exact reload command.

After reloading the shell, normal usage becomes:

```bash
dockavel help
dpl
ds my-api
da my-api route:list
```

No `./dockavel` is required for daily use.

## Global CLI, Help and Shortcuts

You can install or refresh the global command at any time:

```bash
./dockavel shortcuts:install
```

Inspect installation status:

```bash
dockavel shortcuts:list
```

Remove only the symlinks managed by the current Dockavel checkout:

```bash
dockavel shortcuts:remove
```

Dockavel never overwrites an existing file or command with the same shortcut name. The installer deliberately uses `ddoc` instead of `dd` because `dd` is a standard Unix command.

### Full help

```bash
dockavel help
dh
```

Detailed help for one command:

```bash
dockavel help shell
dh artisan
dh shortcuts
```

### Shortcut reference

| Shortcut | Equivalent command |
| --- | --- |
| `ds <project>` | `dockavel shell <project>` |
| `da <project> ...` | `dockavel artisan <project> ...` |
| `dco <project> ...` | `dockavel composer <project> ...` |
| `dn <project> ...` | `dockavel npm <project> ...` |
| `dpa` | `dockavel project:add` |
| `dpl` | `dockavel project:list` |
| `dpe <project>` | `dockavel project:edit <project>` |
| `dpr <project>` | `dockavel project:remove <project>` |
| `ddoc` | `dockavel doctor` |
| `dsrc` | `dockavel source:test` |
| `dh [command]` | `dockavel help [command]` |

Examples:

```bash
ds testlara
da testlara migrate
da testlara route:list
dco testlara install
dn testlara run dev
dpl
ddoc
```

The global `dockavel` executable and all shortcuts point back to the actual Dockavel checkout. The CLI resolves symlinks before loading its project metadata, Compose file, and modules, so it can be called from any working directory.

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

### Iran / Runflare

Uses Runflare Docker, Debian, Composer, and npm mirrors. Availability and request quotas are controlled by Runflare and may change over time.

### China / regional mirrors

Uses DaoCloud for Docker images, Tsinghua mirrors for Debian, Aliyun for Composer, and npmmirror for npm.

### Custom endpoints

Custom mode accepts explicit Docker, Debian, Composer, and npm endpoints. Values are stored in `.env`.

## Doctor and Source Diagnostics

```bash
dockavel doctor
# shortcut
ddoc
```

Doctor is read-only. It checks Docker CLI/daemon, Compose, WSL, `.env`, port 80, configured sources, running services, and container health when available.

For source-only checks:

```bash
dockavel source:test
# shortcut
dsrc
```

Source probes include HTTP status, response time, remote IP, and an IPv4 retry when the default route fails.

## Incrementally Changing the Stack

Re-run:

```bash
./setup.sh
```

Keep existing selections and add or remove optional services. Compose reuses existing images, build cache, volumes, and unchanged containers whenever possible. Persistent database volumes are not removed by running setup again.

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
│   ├── project-manager.sh
│   ├── project-commands.sh
│   ├── shortcuts.sh
│   └── help.sh
├── nginx/
│   ├── conf.d/
│   ├── template-laravel.conf.example
│   └── template-node.conf.example
├── docker-compose.yml
├── dockavel
├── setup.sh
└── .env
```

Local projects, generated Nginx configs, `.dockavel.yml` files inside local projects, and `.env` are machine-specific and are not intended to be committed to the Dockavel repository.

## Project Manager

Project Manager registers an **existing** project inside `projects/`. It does not create a Laravel or Node application for you.

```bash
dpa               # add/register project
dpl               # list projects
dpe my-api        # edit project
dpr my-api        # remove Dockavel registration
```

The long forms remain available:

```bash
dockavel project:add
dockavel project:list
dockavel project:edit my-api
dockavel project:remove my-api
```

Project Manager detects Laravel from `artisan` + `composer.json`, detects Node.js from `package.json`, only offers enabled runtimes/services, generates `.dockavel.yml` and Nginx configuration, validates Nginx before applying changes, and rolls generated files back if apply fails.

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

`project:remove` removes Dockavel metadata and generated Nginx registration only. It never deletes the project source directory.

## Project-aware Commands

Once a project is registered, the shortest normal workflow is:

```bash
ds my-api
da my-api migrate
dco my-api install
dn my-api run dev
```

Equivalent long forms:

```bash
dockavel shell my-api
dockavel artisan my-api migrate
dockavel composer my-api install
dockavel npm my-api run dev
```

Laravel `shell`, `artisan`, and `composer` automatically use the PHP runtime stored in `.dockavel.yml`. Node project shells use the shared Node runtime. `npm` works for Node projects and Laravel projects with `node: true`.

Before execution, Dockavel validates that the runtime is enabled and running, the project exists on the host, and the project path is visible inside the selected container. A stale Docker Desktop/WSL bind mount is reported before Artisan, Composer, npm, or the shell is launched.

Arguments after the project selector are passed directly to the underlying command.

## Hosts File

Dockavel intentionally does not edit the host machine's hosts file automatically. After registration, add the printed entry manually, for example:

```text
127.0.0.1 my-api.local
```

On Windows:

```text
C:\Windows\System32\drivers\etc\hosts
```

## Low-level Runtime Commands

Most users should prefer Dockavel shortcuts. Raw Compose commands remain available when needed:

```bash
docker compose exec php82 php -v
docker compose exec php85 bash
docker compose exec node node --version
```

Naming example:

```text
Compose service : php85
Container name  : dockavel-php85
Local image     : dev-stack-php85
```

## Service Connections

| Service | Inside Docker | Host |
| --- | --- | --- |
| MySQL | `mysql:3306` | `127.0.0.1:13307` |
| PostgreSQL | `postgres:5432` | `127.0.0.1:15432` |
| Redis | `redis:6379` | `127.0.0.1:16379` |
| phpMyAdmin | — | `127.0.0.1:18080` |
| pgAdmin | — | `127.0.0.1:18081` |

Database data lives in named Docker volumes. Normal `docker compose down` keeps those volumes; `docker compose down -v` is destructive.

## Useful Commands

```bash
# Help
dh
dh shell

# Project management
dpa
dpl
dpe my-api
dpr my-api

# Project commands
ds my-api
da my-api route:list
dco my-api install
dn my-api run dev

# Diagnostics
ddoc
dsrc

# Global shortcut management
dockavel shortcuts:list
dockavel shortcuts:install
dockavel shortcuts:remove
```

## Troubleshooting

Start with:

```bash
ddoc
```

For source-only connectivity:

```bash
dsrc
```

If a project exists on the host but is not visible inside its runtime, Dockavel stops the requested project command and reports the bind-mount visibility issue. When the host path is correct, restarting Docker Desktop can resolve a stale WSL/Docker bind mount.

## CI

GitHub Actions currently validates:

- multiple Compose profile combinations
- PHP 8.2, 8.3, 8.4, and 8.5 builds
- required PHP runtime capabilities
- Node.js 24 build/runtime
- shell syntax for setup, CLI, project modules, help, shortcuts, and tests
- project-aware command routing with a fake Docker CLI
- global symlink invocation, conflict protection, PATH idempotency, help aliases, and shortcut removal

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
✅ Global dockavel CLI + terminal shortcuts + full help
```

Likely next productivity work:

```text
- smarter project detection and runtime suggestions
- database helpers for repeated local workflows
- additional Doctor / project health diagnostics
```

## Contributing

Issues and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

User-facing features, services, runtimes, source presets, CLI commands, configuration changes, ports and workflows should keep the runtime README files and the public [website/documentation](https://afshinefati.github.io/dockavel-site/docs/) synchronized.

## License

MIT
