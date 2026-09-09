#!/usr/bin/env bash

DOCKAVEL_SHORTCUT_NAMES=(dockavel ds da dco dn dpa dpl dpe dpr dpd dpc dbs dbc dbx dbi ddoc dsrc dv dh)

shortcut_target_for_name() {
    case "$1" in
        ds) printf 'shell' ;;
        da) printf 'artisan' ;;
        dco) printf 'composer' ;;
        dn) printf 'npm' ;;
        dpa) printf 'project:add' ;;
        dpl) printf 'project:list' ;;
        dpe) printf 'project:edit' ;;
        dpr) printf 'project:remove' ;;
        dpd) printf 'project:detect' ;;
        dpc) printf 'project:check' ;;
        dbs) printf 'db:status' ;;
        dbc) printf 'db:create' ;;
        dbx) printf 'db:export' ;;
        dbi) printf 'db:import' ;;
        ddoc) printf 'doctor' ;;
        dsrc) printf 'source:test' ;;
        dv) printf 'version' ;;
        dh) printf 'help' ;;
        *) return 1 ;;
    esac
}

shortcut_description_for_name() {
    case "$1" in
        dockavel) printf 'Global Dockavel CLI' ;;
        ds) printf 'Open project shell' ;;
        da) printf 'Run Laravel Artisan' ;;
        dco) printf 'Run Composer' ;;
        dn) printf 'Run npm' ;;
        dpa) printf 'Add/register project' ;;
        dpl) printf 'List projects' ;;
        dpe) printf 'Edit project' ;;
        dpr) printf 'Remove project registration' ;;
        dpd) printf 'Detect project requirements' ;;
        dpc) printf 'Check project health' ;;
        dbs) printf 'Show project database status' ;;
        dbc) printf 'Create project database' ;;
        dbx) printf 'Export project database' ;;
        dbi) printf 'Import project database' ;;
        ddoc) printf 'Run Dockavel Doctor' ;;
        dsrc) printf 'Test configured download sources' ;;
        dv) printf 'Show Dockavel version' ;;
        dh) printf 'Show Dockavel help' ;;
        *) printf 'Dockavel shortcut' ;;
    esac
}

shortcut_bin_dir() {
    printf '%s' "${DOCKAVEL_BIN_DIR:-$HOME/.local/bin}"
}

shortcut_cli_target() {
    printf '%s' "$ROOT_DIR/dockavel"
}

shortcut_link_is_ours() {
    local path="$1" target="$2"
    [[ -L "$path" ]] && [[ "$(readlink "$path" 2>/dev/null || true)" == "$target" ]]
}

shortcut_path_active() {
    local bin_dir="$1" item
    IFS=':' read -r -a _dockavel_path_items <<< "${PATH:-}"
    for item in "${_dockavel_path_items[@]:-}"; do
        [[ "$item" == "$bin_dir" ]] && return 0
    done
    return 1
}

shortcut_shell_rc() {
    case "${SHELL##*/}" in
        zsh) printf '%s/.zshrc' "$HOME" ;;
        bash) printf '%s/.bashrc' "$HOME" ;;
        *)
            if [[ -f "$HOME/.zshrc" ]]; then
                printf '%s/.zshrc' "$HOME"
            elif [[ -f "$HOME/.bashrc" ]]; then
                printf '%s/.bashrc' "$HOME"
            else
                return 1
            fi
            ;;
    esac
}

shortcut_ensure_path() {
    local bin_dir="$1" rc_file marker_start='# >>> Dockavel CLI >>>' marker_end='# <<< Dockavel CLI <<<' path_line

    if shortcut_path_active "$bin_dir"; then
        SHORTCUT_PATH_CHANGED=false
        SHORTCUT_RC_FILE=""
        return 0
    fi

    if ! rc_file="$(shortcut_shell_rc)"; then
        printf '%s Could not detect Bash/Zsh startup file. Add this directory to PATH manually: %s\n' "$WARN" "$bin_dir"
        SHORTCUT_PATH_CHANGED=false
        SHORTCUT_RC_FILE=""
        return 0
    fi

    touch "$rc_file"
    if grep -Fq "$marker_start" "$rc_file" 2>/dev/null; then
        SHORTCUT_PATH_CHANGED=false
        SHORTCUT_RC_FILE="$rc_file"
        return 0
    fi

    if [[ "$bin_dir" == "$HOME/.local/bin" ]]; then
        path_line='export PATH="$HOME/.local/bin:$PATH"'
    else
        path_line="export PATH=\"$bin_dir:\$PATH\""
    fi

    {
        printf '\n%s\n' "$marker_start"
        printf '%s\n' "$path_line"
        printf '%s\n' "$marker_end"
    } >> "$rc_file"

    SHORTCUT_PATH_CHANGED=true
    SHORTCUT_RC_FILE="$rc_file"
}

shortcuts_install() {
    local bin_dir target name path existing installed=0 skipped=0

    bin_dir="$(shortcut_bin_dir)"
    target="$(shortcut_cli_target)"

    if [[ ! -x "$target" ]]; then
        printf '%s Dockavel CLI is not executable: %s\n' "$FAIL" "$target" >&2
        return 1
    fi

    mkdir -p "$bin_dir"

    printf '\nDockavel shortcuts\n------------------\n'
    for name in "${DOCKAVEL_SHORTCUT_NAMES[@]}"; do
        path="$bin_dir/$name"

        if shortcut_link_is_ours "$path" "$target"; then
            printf '%-10s %s already installed\n' "$name" "$OK"
            continue
        fi

        if [[ -e "$path" || -L "$path" ]]; then
            printf '%-10s %s skipped · %s already exists\n' "$name" "$WARN" "$path"
            skipped=$((skipped + 1))
            continue
        fi

        existing="$(command -v "$name" 2>/dev/null || true)"
        if [[ -n "$existing" ]]; then
            printf '%-10s %s skipped · existing command: %s\n' "$name" "$WARN" "$existing"
            skipped=$((skipped + 1))
            continue
        fi

        ln -s "$target" "$path"
        printf '%-10s %s %s\n' "$name" "$OK" "$(shortcut_description_for_name "$name")"
        installed=$((installed + 1))
    done

    shortcut_ensure_path "$bin_dir"

    printf '\n%s Installed/updated %d shortcut(s); skipped %d conflict(s).\n' "$INFO" "$installed" "$skipped"
    printf '%s Global command directory: %s\n' "$INFO" "$bin_dir"

    if [[ "$SHORTCUT_PATH_CHANGED" == "true" && -n "$SHORTCUT_RC_FILE" ]]; then
        printf '%s PATH was added to %s. Reload your shell with:\n' "$INFO" "$SHORTCUT_RC_FILE"
        printf '  source %q\n' "$SHORTCUT_RC_FILE"
    elif ! shortcut_path_active "$bin_dir"; then
        printf '%s Open a new terminal after adding %s to PATH.\n' "$WARN" "$bin_dir"
    else
        printf '%s Shortcuts are ready. Try: dh\n' "$OK"
    fi
}

shortcuts_list() {
    local bin_dir target name path command_name status
    bin_dir="$(shortcut_bin_dir)"
    target="$(shortcut_cli_target)"

    printf '\nDockavel shortcuts\n------------------\n'
    printf '%-10s %-18s %s\n' 'NAME' 'COMMAND' 'STATUS'

    for name in "${DOCKAVEL_SHORTCUT_NAMES[@]}"; do
        path="$bin_dir/$name"
        if [[ "$name" == "dockavel" ]]; then
            command_name='dockavel <command>'
        else
            command_name="$(shortcut_target_for_name "$name")"
        fi

        if shortcut_link_is_ours "$path" "$target"; then
            status="${OK} installed"
        elif [[ -e "$path" || -L "$path" ]]; then
            status="${WARN} conflict"
        else
            status="${INFO} not installed"
        fi

        printf '%-10s %-18s %s\n' "$name" "$command_name" "$status"
    done

    printf '\n%s Directory: %s\n' "$INFO" "$bin_dir"
}

shortcuts_remove() {
    local bin_dir target name path removed=0 kept=0
    bin_dir="$(shortcut_bin_dir)"
    target="$(shortcut_cli_target)"

    printf '\nRemove Dockavel shortcuts\n-------------------------\n'
    for name in "${DOCKAVEL_SHORTCUT_NAMES[@]}"; do
        path="$bin_dir/$name"
        if shortcut_link_is_ours "$path" "$target"; then
            rm -f "$path"
            printf '%-10s %s removed\n' "$name" "$OK"
            removed=$((removed + 1))
        elif [[ -e "$path" || -L "$path" ]]; then
            printf '%-10s %s kept · not managed by this Dockavel checkout\n' "$name" "$WARN"
            kept=$((kept + 1))
        fi
    done

    printf '\n%s Removed %d shortcut(s); kept %d unrelated path(s).\n' "$INFO" "$removed" "$kept"
    printf '%s The PATH entry is left untouched because ~/.local/bin may contain other user commands.\n' "$INFO"
}
