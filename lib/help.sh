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

Diagnostics
-----------
  dockavel doctor
      Diagnose Docker, WSL, ports, sources and stack health.

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
  ddoc                            dockavel doctor
  dsrc                            dockavel source:test
  dh [command]                    dockavel help [command]

Examples
--------
  ds testlara
  da testlara migrate
  da testlara route:list
  dco testlara install
  dn testlara run dev
  dpl
  ddoc

More help
---------
  dockavel help shell
  dockavel help artisan
  dockavel help composer
  dockavel help npm
  dockavel help shortcuts

Note: Dockavel intentionally uses ddoc instead of dd because dd is a standard Unix command.
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

Examples:
  ds testlara
  dockavel shell testlara

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
----
Usage:
  dockavel npm <project> [arguments...]
  dn <project> [arguments...]

Examples:
  dn testlara install
  dn testlara run dev
  dn frontend run build

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
It does not create a Laravel or Node application.
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

Examples:
  dpe testlara
  dockavel project:edit testlara
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
        doctor|ddoc)
            cat <<'HELP'
Doctor
------
Usage:
  dockavel doctor
  ddoc

Read-only diagnostics for Docker, WSL, port 80, download sources and stack health.
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
        shortcuts|shortcut|shortcuts:install|shortcuts:list|shortcuts:remove)
            cat <<'HELP'
Global CLI and shortcuts
------------------------
Install:
  ./dockavel shortcuts:install

After installation:
  dockavel help
  ds testlara
  da testlara route:list

Inspect:
  dockavel shortcuts:list

Remove:
  dockavel shortcuts:remove

Dockavel installs managed symlinks in ~/.local/bin and never overwrites an existing command or file with the same name. If ~/.local/bin is not already in PATH, Dockavel can add one managed PATH block to Bash or Zsh startup configuration.
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

Examples:
  dh shell
  dh artisan
  dockavel help shortcuts
HELP
            ;;
        *)
            printf 'Unknown help topic: %s\n\n' "$topic" >&2
            dockavel_help
            return 2
            ;;
    esac
}
