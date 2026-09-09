# Dockavel

[![CI](https://github.com/AfshinEfati/dockavel/actions/workflows/ci.yml/badge.svg)](https://github.com/AfshinEfati/dockavel/actions/workflows/ci.yml)

**English** | [فارسی](README.fa.md)

[Website](https://afshinefati.github.io/dockavel-site/) · [Documentation](https://afshinefati.github.io/dockavel-site/docs/) · [Smart Workflows](https://afshinefati.github.io/dockavel-site/docs/workflows/) · [Contributing](CONTRIBUTING.md)

Dockavel is a lightweight multi-project local development environment for **Laravel and Node.js**. It keeps one shared Docker Compose stack, supports multiple PHP runtimes at the same time, routes each project through Nginx, and provides project-aware commands so day-to-day development does not require memorizing Docker commands.

The core stays intentionally small: useful automation, explicit configuration, and no hidden infrastructure behavior.

## Current status

Current development version:

```bash
dockavel version
# or
dv
```

```text
0.1.0-dev
```

`VERSION` and `CHANGELOG.md` are now part of the repository. A public GitHub release/tag is intentionally separate from this development version.

## Core features

- PHP-FPM **8.2, 8.3, 8.4 and 8.5** can run side by side
- MySQL 8 and PostgreSQL 17
- Redis 7
- Node.js 24
- phpMyAdmin and pgAdmin
- Compose profiles so unused services stay disabled
- one shared `projects/` workspace
- Nginx routing per project/runtime
- explicit Official, IranServer, Runflare, China and Custom download-source presets
- project registration with `.dockavel.yml`
- project-aware shell / Artisan / Composer / npm commands
- global `dockavel` command and terminal shortcuts
- smart project detection with explicit suggestions
- project health checks
- safe MySQL/PostgreSQL helpers for status/create/export/import
- read-only Doctor and source diagnostics
- CI coverage for runtimes, Compose, CLI routing, detection, database helpers and shortcuts
- no private Dockavel registry images required

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
   ├── MySQL 8
   ├── PostgreSQL 17
   ├── Redis 7
   └── Node.js 24
```

All application runtimes mount:

```text
./projects → /var/www
```

## Supported stack

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

PHP runtimes are built locally from public `serversideup/php:<version>-fpm` images through the selected Docker namespace/mirror. Node.js is built locally from `node:24-bookworm-slim` through the selected Docker library mirror.

Dockavel does **not** require a Docker Hub account, GHCR account, or private Dockavel registry to run the stack.

## Requirements

- Docker Engine or Docker Desktop
- Docker Compose v2 (`docker compose`)
- Bash
- an interactive terminal
- port `80` available for Nginx

On Windows, WSL2 is recommended.

## Current setup entry point

The current setup script remains:

```bash
git clone https://github.com/AfshinEfati/dockavel.git
cd dockavel
chmod +x setup.sh dockavel
./setup.sh
```

It manages the current source preset, enabled profiles and optional shortcut installation. The installer UX is intentionally treated as a separate concern from the runtime architecture, so future installer work can evolve without changing the stack model.

Normal incremental changes do not require deleting persistent volumes.

## Global CLI and shortcuts

Install the global CLI and managed shortcuts once:

```bash
./dockavel shortcuts:install
```

Then use Dockavel from any directory:

```bash
dockavel help
dpl
ds my-api
```

Current shortcuts:

```text
ds <project>                    dockavel shell <project>
da <project> <args...>          dockavel artisan <project> <args...>
dco <project> <args...>         dockavel composer <project> <args...>
dn <project> <args...>          dockavel npm <project> <args...>

dpa                             dockavel project:add
dpl                             dockavel project:list
dpe <project>                   dockavel project:edit <project>
dpr <project>                   dockavel project:remove <project>
dpd <directory>                 dockavel project:detect <directory>
dpc <project>                   dockavel project:check <project>

dbs <project>                   dockavel db:status <project>
dbc <project>                   dockavel db:create <project>
dbx <project> [file.sql]        dockavel db:export <project> [file.sql]
dbi <project> <file.sql>        dockavel db:import <project> <file.sql>

ddoc                            dockavel doctor
dsrc                            dockavel source:test
dv                              dockavel version
dh [command]                    dockavel help [command]
```

Dockavel never overwrites an existing command or file with the same shortcut name. Managed symlinks live in `~/.local/bin`.

Full help:

```bash
dh
dh shell
dh project:detect
dh project:check
dh database
```

`ddoc` is used instead of `dd` because `dd` is a standard Unix command.

## Project Manager

Project Manager registers an **existing** project under `projects/`; it does not create a Laravel or Node application.

```bash
dpa
```

Project registration handles:

- Laravel/Node detection
- project name and local domain
- PHP runtime selection for Laravel
- MySQL/PostgreSQL selection when enabled
- Redis and shared Node flags
- `.dockavel.yml` generation
- Nginx generation and validation
- Nginx reload when running
- rollback when generated configuration cannot be applied
- hosts-file guidance without editing the host OS automatically

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

Other Project Manager commands:

```bash
dpl
dpe my-api
dpr my-api
```

`project:remove` removes Dockavel registration only. It never deletes project source files.

## Smart project detection

Read project hints without changing anything:

```bash
dockavel project:detect my-api
# shortcut
dpd my-api
```

Detection inspects project files such as:

- `artisan`
- `composer.json`
- `package.json`
- npm/yarn/pnpm/bun lockfiles
- `.env` or `.env.example`

It can report:

- Laravel or Node.js project type
- PHP requirement from `composer.json`
- the first compatible **enabled** PHP runtime suggestion
- npm / yarn / pnpm / bun hint
- MySQL / PostgreSQL / SQLite hint
- Redis usage hint
- whether Node frontend files are present

Detection is intentionally advisory. `project:add` still asks before writing metadata or selecting a runtime/service.

## Project-aware runtime commands

Once registered, Dockavel resolves the project runtime and `/var/www/<project>` working directory automatically.

```bash
ds my-api
da my-api migrate
dco my-api install
dn my-api run dev
```

For Laravel projects, `shell`, Artisan and Composer use the PHP runtime stored in `.dockavel.yml`. Node projects use the shared Node runtime. `npm` is available for Node projects and Laravel projects with `node: true`.

Before execution Dockavel validates that the runtime is enabled/running, the host project path exists, and the project is visible inside the container.

## Project health check

Check one registered project without changing it:

```bash
dockavel project:check my-api
# shortcut
dpc my-api
```

The health check covers:

- metadata core fields
- host project path
- Laravel/Node project markers
- configured PHP/Node runtime state
- runtime bind-mount visibility
- generated Nginx config and `server_name`
- `nginx -t` when Nginx is running
- configured database presence
- optional Redis state
- optional frontend Node state

Warnings are separated from hard failures.

## Database helpers

Database helpers are project-aware. They use the database type from `.dockavel.yml` and `DB_DATABASE` from the project's `.env` or `.env.example`.

Check database status:

```bash
dbs my-api
```

Create it if missing:

```bash
dbc my-api
```

Export:

```bash
dbx my-api
# or
dbx my-api backups/my-api.sql
```

An export refuses to overwrite an existing file.

Import:

```bash
dbi my-api backups/my-api.sql
```

Import requires explicit confirmation because SQL imports can modify or delete existing data.

The helper layer currently supports MySQL and PostgreSQL. Dockavel intentionally does not provide automatic `drop`/`reset` commands here.

## Doctor and source diagnostics

Run:

```bash
ddoc
```

Doctor is read-only. It checks the local Docker/WSL environment, configured sources and enabled stack services. It also reports project-registry and proxy hints, including:

- registered/stale project paths
- shell `HTTP_PROXY` / `HTTPS_PROXY` / `ALL_PROXY` variables
- a Docker client `proxies` block in `~/.docker/config.json`

Doctor does not change proxy settings, DNS, Docker Desktop configuration, `.env`, mirrors or containers.

Source-only checks:

```bash
dsrc
```

Source tests cover the configured Docker registry, Debian mirrors, Composer repository and npm registry, including HTTP status, response time, remote IP and an IPv4 retry hint when the default route fails.

## Download source presets

Dockavel keeps image/package sources explicit. A regional preset does not intentionally fall back to a hidden global source.

### Official / Global

```text
Docker     docker.io
Debian     deb.debian.org
Composer   repo.packagist.org
npm        registry.npmjs.org
```

### Iran / IranServer

```text
Docker library     docker.iranserver.com/library/
Docker namespace   docker.iranserver.com/
Debian              mirror.iranserver.com
Composer            composer.iranserver.com
npm                 npm.iranserver.com
```

### Iran / Runflare

Uses the configured Runflare Docker, Debian, Composer and npm mirror endpoints.

### China

Uses regional Docker, Debian, Composer and npm endpoints configured by the China preset.

### Custom

Allows explicit Docker prefixes, Debian mirrors, Composer repository, npm registry and npm strict-SSL behavior.

## Default host ports

| Service | Host | Container |
| --- | ---: | ---: |
| Nginx | `80` | `80` |
| MySQL | `13307` | `3306` |
| PostgreSQL | `15432` | `5432` |
| Redis | `16379` | `6379` |
| phpMyAdmin | `18080` | `80` |
| pgAdmin | `18081` | `80` |

Except for Nginx, published service ports are bound to `127.0.0.1` by default.

## Hosts file

Dockavel does not modify the host machine hosts file automatically.

Example:

```text
127.0.0.1 my-api.local
```

On Windows:

```text
C:\Windows\System32\drivers\etc\hosts
```

## Data safety

Persistent database data uses named Docker volumes.

Safe normal shutdown:

```bash
docker compose down
```

Destructive:

```bash
docker compose down -v
```

Do not use `-v` unless you intentionally want to remove persistent volumes.

Database import is confirmation-protected, database export never overwrites an existing target, and project removal never deletes source code.

## Repository layout

```text
Dockavel/
├── projects/
├── lib/
│   ├── database.sh
│   ├── help.sh
│   ├── project-commands.sh
│   ├── project-detection.sh
│   ├── project-health.sh
│   ├── project-manager.sh
│   └── shortcuts.sh
├── nginx/
├── tests/
├── CHANGELOG.md
├── VERSION
├── Dockerfile
├── Dockerfile-node
├── docker-compose.yml
├── dockavel
└── setup.sh
```

Machine-local files such as project source, generated Nginx configs, project metadata and `.env` are not intended to be committed to the Dockavel repository.

## CI

GitHub Actions currently validates:

- Compose profile combinations
- PHP 8.2, 8.3, 8.4 and 8.5 builds and required extensions
- Node.js 24 build/runtime
- Bash syntax for the CLI modules and tests
- smart project detection
- project-aware command routing
- database helper routing/safety behavior
- global shortcut installation/removal and symlink routing
- executable CLI entry point

## Documentation

Detailed bilingual documentation is published at:

https://afshinefati.github.io/dockavel-site/docs/

Important pages:

- [CLI & Shortcuts](https://afshinefati.github.io/dockavel-site/docs/commands/)
- [Smart Workflows](https://afshinefati.github.io/dockavel-site/docs/workflows/)
- [Project Manager](https://afshinefati.github.io/dockavel-site/docs/projects/)
- [Sources & Diagnostics](https://afshinefati.github.io/dockavel-site/docs/network/)
- [Stack & Runtimes](https://afshinefati.github.io/dockavel-site/docs/stack/)
- [Troubleshooting](https://afshinefati.github.io/dockavel-site/docs/troubleshooting/)
- [Reference](https://afshinefati.github.io/dockavel-site/docs/reference/)

## Completed foundation

```text
✅ Configurable shared stack
✅ PHP 8.2 / 8.3 / 8.4 / 8.5
✅ MySQL / PostgreSQL / Redis / Node
✅ Regional download sources
✅ Project Manager
✅ Project-aware runtime commands
✅ Global CLI / Help / terminal shortcuts
✅ Smart project detection
✅ Project health checks
✅ Database helpers
✅ Doctor / source diagnostics
✅ Version / changelog foundation
```

Future work remains explicit and should not silently expand the core or change runtime/source architecture.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

User-facing features, services, runtimes, source presets, CLI commands, configuration changes, ports and workflows should keep `README.md`, `README.fa.md` and the public website/documentation synchronized.

## License

MIT
