#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_HOME="$(mktemp -d)"
trap 'rm -rf "$TEST_HOME"' EXIT

export HOME="$TEST_HOME"
export SHELL="/bin/bash"
export DOCKAVEL_BIN_DIR="$HOME/.local/bin"
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

mkdir -p "$HOME/.local/bin"
touch "$HOME/.bashrc"

# A pre-existing command/file must never be overwritten.
printf '#!/usr/bin/env bash\necho existing\n' > "$HOME/.local/bin/dsrc"
chmod +x "$HOME/.local/bin/dsrc"

"$REPO_ROOT/dockavel" shortcuts:install >/tmp/dockavel-shortcuts-install.log

for name in dockavel ds da dco dn dpa dpl dpe dpr dpd dpc dbs dbc dbx dbi ddoc dv dh; do
    if [[ ! -L "$HOME/.local/bin/$name" ]]; then
        printf 'Expected shortcut symlink was not installed: %s\n' "$name" >&2
        exit 1
    fi
done

if [[ -L "$HOME/.local/bin/dsrc" ]]; then
    printf 'Existing dsrc command was overwritten.\n' >&2
    exit 1
fi

if [[ "$("$HOME/.local/bin/dsrc")" != "existing" ]]; then
    printf 'Existing dsrc command content changed.\n' >&2
    exit 1
fi

if ! "$HOME/.local/bin/dh" project:check | grep -Fq 'dpc <project>'; then
    printf 'dh project:check did not route to detailed help.\n' >&2
    exit 1
fi

if ! "$HOME/.local/bin/dockavel" help database | grep -Fq 'dbx <project>'; then
    printf 'Global dockavel command did not expose database helper help.\n' >&2
    exit 1
fi

if ! "$HOME/.local/bin/dv" | grep -Fq 'Dockavel '; then
    printf 'dv did not resolve the Dockavel version command.\n' >&2
    exit 1
fi

# PATH setup is managed and idempotent.
"$REPO_ROOT/dockavel" shortcuts:install >/dev/null
if [[ "$(grep -Fc '# >>> Dockavel CLI >>>' "$HOME/.bashrc")" -ne 1 ]]; then
    printf 'Dockavel PATH block was duplicated.\n' >&2
    exit 1
fi

"$REPO_ROOT/dockavel" shortcuts:remove >/dev/null
for name in dockavel ds da dco dn dpa dpl dpe dpr dpd dpc dbs dbc dbx dbi ddoc dv dh; do
    if [[ -e "$HOME/.local/bin/$name" || -L "$HOME/.local/bin/$name" ]]; then
        printf 'Managed shortcut was not removed: %s\n' "$name" >&2
        exit 1
    fi
done

if [[ ! -x "$HOME/.local/bin/dsrc" ]]; then
    printf 'Unrelated shortcut conflict was removed unexpectedly.\n' >&2
    exit 1
fi

printf 'Shortcut installation tests passed.\n'
