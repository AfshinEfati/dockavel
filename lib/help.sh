#!/usr/bin/env bash

dockavel_help() {
    local topic="${1:-}"

    if [[ -n "$topic" ]]; then
        dockavel_help_topic "$topic"
        return $?
    fi

    cat <<'HELP'
Dockavel CLI
===========

Run Dockavel globally after installing shortcuts:
  dockavel <command> [arguments...]

Before global installation, the same commands still work with:
  ./dockavel <command> [arguments...]

Projects
--------
  dockavel project:add
      Register an existing Laravel or Node.js project.

  dockavel project:list
      List registered projects, runtimes and databases.

  dockavel project:edit [project]
      Edit project domain/runtime/service metadata.

  dockavel project:remove [project]
      Remove Dockavel registration without deleting source code.

  dockavel project:detect <directory>
      Read project files and show type/runtime/database/service suggestions.

  dockavel project:check <project>
      Check project metadata, runtime, mount, Nginx and shared services.

Project commands
----------------
  dockavel shell <project>
      Open Bash in the project's configured PHP or Node runtime.

  dockavel artisan <project> [arguments...]
      Run Laravel Artisan in the project's configured PHP runtime.

  dockavel composer <project> [arguments...]
      Run Composer in the project's configured PHP runtime.

  dockavel npm <project> [arguments...]
      Run npm in the shared Node runtime for a Node-enabled project.

Database helpers
----------------
  dockavel db:status <project>
      Check whether the project's configured database exists.

  dockavel db:create <project>
      Create the configured MySQL/PostgreSQL database if missing.

  dockavel db:export <project> [file.sql]
      Export the configured database without overwriting an existing file.

  dockavel db:import <project> <file.sql>
      Import SQL after an explicit confirmation prompt.

Diagnostics
-----------
  dockavel doctor
      Diagnose Docker, WSL, proxy hints, project registry, sources and stack health.

  dockavel source:test
      Test the download endpoints configured in .env.

Global CLI / shortcuts
----------------------
  dockavel shortcuts:install
      Install the global dockavel command and terminal shortcuts.

  dockavel shortcuts:list
      Show shortcut installation status.

  dockavel shortcuts:remove
      Remove shortcuts managed by this Dockavel checkout.

  dockavel version
      Show the current Dockavel version.

  dockavel help [command]
      Show this help or detailed help for one command.

Shortcuts
---------
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

Examples
--------
  dpd testlara
  dpc testlara
  ds testlara
  da testlara migrate
  dco testlara install
  dbs testlara
  dbx testlara backup.sql
  dpl
  ddoc

More help
---------
  dockavel help project:detect
  dockavel help project:check
  dockavel help database
  dockavel help shell
  dockavel help shortcuts

Note: smart detection only suggests values. project:add still asks before saving metadata.
HELP
}

dockavel_help_topic() {
    local topic="$1"

    case "$topic" in
        shell|ds)
            cat <<'HELP'
Shell
-----
Usage:
  dockavel shell <project>
  ds <project>

Laravel projects open in their configured PHP runtime.
Node projects open in the shared Node runtime.
HELP
            ;;
        artisan|da)
            cat <<'HELP'
Artisan
-------
Usage:
  dockavel artisan <project> [arguments...]
  da <project> [arguments...]

Examples:
  da testlara migrate
  da testlara route:list
  da testlara queue:work
HELP
            ;;
        composer|dco)
            cat <<'HELP'
Composer
--------
Usage:
  dockavel composer <project> [arguments...]
  dco <project> [arguments...]

Examples:
  dco testlara install
  dco testlara update
  dco testlara require laravel/sanctum
HELP
            ;;
        npm|dn)
            cat <<'HELP'
npm
---
Usage:
  dockavel npm <project> [arguments...]
  dn <project> [arguments...]

The project must be a Node project or have node: true in .dockavel.yml.
HELP
            ;;
        project:add|project-add|dpa)
            cat <<'HELP'
Project add
-----------
Usage:
  dockavel project:add
  dpa

Registers an existing project inside Dockavel's projects/ directory.
Smart detection prints PHP, database, Redis, Node and package-manager hints first, but the command still asks before writing metadata.
HELP
            ;;
        project:list|project-list|dpl)
            cat <<'HELP'
Project list
------------
Usage:
  dockavel project:list
  dpl

Shows registered project names, types, domains, runtimes and databases.
HELP
            ;;
        project:edit|project-edit|dpe)
            cat <<'HELP'
Project edit
------------
Usage:
  dockavel project:edit [project]
  dpe [project]
HELP
            ;;
        project:remove|project-remove|dpr)
            cat <<'HELP'
Project remove
--------------
Usage:
  dockavel project:remove [project]
  dpr [project]

Removes Dockavel metadata and generated Nginx registration only.
Project source files are never deleted by this command.
HELP
            ;;
        project:detect|project-detect|dpd)
            cat <<'HELP'
Project detect
--------------
Usage:
  dockavel project:detect <directory>
  dpd <directory>

Example:
  dpd testlara

Read-only detection looks at composer.json, package.json/lockfiles and .env/.env.example.
It can suggest project type, PHP runtime, database, Redis and package-manager usage.
Suggestions never change the project automatically.
HELP
            ;;
        project:check|project-check|dpc)
            cat <<'HELP'
Project check
-------------
Usage:
  dockavel project:check <project>
  dpc <project>

Checks metadata, host path, runtime state, container mount visibility, generated Nginx config, database presence and optional Redis/Node services.
The check is read-only.
HELP
            ;;
        database|db|db:status|db:create|db:export|db:import|dbs|dbc|dbx|dbi)
            cat <<'HELP'
Database helpers
----------------
Status:
  dockavel db:status <project>
  dbs <project>

Create if missing:
  dockavel db:create <project>
  dbc <project>

Export:
  dockavel db:export <project> [file.sql]
  dbx <project> [file.sql]

Import:
  dockavel db:import <project> <file.sql>
  dbi <project> <file.sql>

The database name is read from the project's .env (or .env.example fallback).
Export refuses to overwrite an existing file. Import requires confirmation and does not create/drop databases automatically.
HELP
            ;;
        doctor|ddoc)
            cat <<'HELP'
Doctor
------
Usage:
  dockavel doctor
  ddoc

Read-only diagnostics for Docker, WSL, port 80, download sources, stack health, registered-project staleness and host/Docker-client proxy hints.
HELP
            ;;
        source:test|source-test|dsrc)
            cat <<'HELP'
Source test
-----------
Usage:
  dockavel source:test
  dsrc

Read-only connectivity checks for the currently configured download sources.
HELP
            ;;
        version|dv|-v|--version)
            cat <<'HELP'
Version
-------
Usage:
  dockavel version
  dockavel --version
  dv
HELP
            ;;
        shortcuts|shortcut|shortcuts:install|shortcuts:list|shortcuts:remove)
            cat <<'HELP'
Global CLI and shortcuts
------------------------
Install:
  ./dockavel shortcuts:install

Inspect:
  dockavel shortcuts:list

Remove:
  dockavel shortcuts:remove

Dockavel installs managed symlinks in ~/.local/bin and never overwrites an existing command or file with the same name.
HELP
            ;;
        help|dh)
            cat <<'HELP'
Help
----
Usage:
  dockavel help
  dockavel help <command>
  dh
  dh <command>
HELP
            ;;
        *)
            printf 'Unknown help topic: %s\n\n' "$topic" >&2
            dockavel_help
            return 2
            ;;
    esac
}
