#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

ENV_FILE=".env"
ENV_EXAMPLE=".env.example"

if [[ ! -f "$ENV_EXAMPLE" ]]; then
    echo "Error: $ENV_EXAMPLE was not found."
    exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
    echo "Error: Docker is not installed or is not available in PATH."
    exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
    echo "Error: Docker Compose v2 is required."
    exit 1
fi

if [[ ! -f "$ENV_FILE" ]]; then
    cp "$ENV_EXAMPLE" "$ENV_FILE"
    echo "Created $ENV_FILE from $ENV_EXAMPLE."
fi

set_env_value() {
    local key="$1"
    local value="$2"
    local tmp

    tmp="$(mktemp)"

    awk -v key="$key" -v value="$value" '
        BEGIN { updated = 0 }
        index($0, key "=") == 1 {
            print key "=" value
            updated = 1
            next
        }
        { print }
        END {
            if (!updated) {
                print key "=" value
            }
        }
    ' "$ENV_FILE" > "$tmp"

    mv "$tmp" "$ENV_FILE"
}

ask_yes_no() {
    local prompt="$1"
    local default="${2:-n}"
    local answer

    while true; do
        if [[ "$default" == "y" ]]; then
            read -r -p "$prompt [Y/n] " answer || true
            answer="${answer:-y}"
        else
            read -r -p "$prompt [y/N] " answer || true
            answer="${answer:-n}"
        fi

        case "${answer,,}" in
            y|yes) return 0 ;;
            n|no) return 1 ;;
            *) echo "Please answer y or n." ;;
        esac
    done
}

add_profile() {
    local profile="$1"
    local existing

    for existing in "${PROFILES[@]:-}"; do
        [[ "$existing" == "$profile" ]] && return 0
    done

    PROFILES+=("$profile")
}

print_header() {
    cat <<'EOF'

╔══════════════════════════════════════╗
║            Dockavel Setup            ║
╚══════════════════════════════════════╝

Choose only the runtimes and services you actually need.
Multiple PHP versions can run at the same time.
EOF
}

select_php_versions() {
    local input
    local choice
    local invalid

    while true; do
        cat <<'EOF'

PHP runtimes
------------
1) PHP 8.2
2) PHP 8.3
3) PHP 8.4
4) PHP 8.5
EOF
        read -r -p "Select one or more versions (example: 1 4): " input
        input="${input//,/ }"
        invalid=0
        PHP_LABELS=()
        PHP_PROFILES=()

        for choice in $input; do
            case "$choice" in
                1) PHP_PROFILES+=("php82"); PHP_LABELS+=("8.2") ;;
                2) PHP_PROFILES+=("php83"); PHP_LABELS+=("8.3") ;;
                3) PHP_PROFILES+=("php84"); PHP_LABELS+=("8.4") ;;
                4) PHP_PROFILES+=("php85"); PHP_LABELS+=("8.5") ;;
                *) echo "Unknown PHP option: $choice"; invalid=1 ;;
            esac
        done

        if [[ "$invalid" -eq 0 && "${#PHP_PROFILES[@]}" -gt 0 ]]; then
            break
        fi

        echo "Select at least one valid PHP runtime."
    done

    for choice in "${PHP_PROFILES[@]}"; do
        add_profile "$choice"
    done
}

select_databases() {
    local input
    local choice
    local invalid

    MYSQL_ENABLED=0
    POSTGRES_ENABLED=0

    while true; do
        cat <<'EOF'

Databases
---------
1) MySQL 8
2) PostgreSQL 17

Press Enter if you do not need a database.
EOF
        read -r -p "Select databases (example: 1 2): " input
        input="${input//,/ }"
        invalid=0
        MYSQL_ENABLED=0
        POSTGRES_ENABLED=0

        if [[ -z "${input// }" ]]; then
            break
        fi

        for choice in $input; do
            case "$choice" in
                1) MYSQL_ENABLED=1 ;;
                2) POSTGRES_ENABLED=1 ;;
                *) echo "Unknown database option: $choice"; invalid=1 ;;
            esac
        done

        [[ "$invalid" -eq 0 ]] && break
    done

    [[ "$MYSQL_ENABLED" -eq 1 ]] && add_profile "mysql"
    [[ "$POSTGRES_ENABLED" -eq 1 ]] && add_profile "postgres"
}

print_header

PROFILES=()
PHP_PROFILES=()
PHP_LABELS=()
MYSQL_ENABLED=0
POSTGRES_ENABLED=0
REDIS_ENABLED=0
NODE_ENABLED=0
PHPMYADMIN_ENABLED=0
PGADMIN_ENABLED=0

select_php_versions
select_databases

if ask_yes_no "Enable Redis?" "y"; then
    REDIS_ENABLED=1
    add_profile "redis"
fi

if ask_yes_no "Enable Node.js?" "y"; then
    NODE_ENABLED=1
    add_profile "node"
fi

if [[ "$MYSQL_ENABLED" -eq 1 ]] && ask_yes_no "Enable phpMyAdmin?" "n"; then
    PHPMYADMIN_ENABLED=1
    add_profile "mysql-ui"
fi

if [[ "$POSTGRES_ENABLED" -eq 1 ]] && ask_yes_no "Enable pgAdmin?" "n"; then
    PGADMIN_ENABLED=1
    add_profile "postgres-ui"
fi

PROFILES_CSV="$(IFS=,; echo "${PROFILES[*]}")"
set_env_value "COMPOSE_PROFILES" "$PROFILES_CSV"

COMPOSE_PROFILES="$PROFILES_CSV" docker compose config >/dev/null

printf '\nConfiguration\n-------------\n'
printf 'PHP runtimes : %s\n' "$(IFS=', '; echo "${PHP_LABELS[*]}")"
printf 'MySQL        : %s\n' "$([[ "$MYSQL_ENABLED" -eq 1 ]] && echo Yes || echo No)"
printf 'PostgreSQL   : %s\n' "$([[ "$POSTGRES_ENABLED" -eq 1 ]] && echo Yes || echo No)"
printf 'Redis        : %s\n' "$([[ "$REDIS_ENABLED" -eq 1 ]] && echo Yes || echo No)"
printf 'Node.js      : %s\n' "$([[ "$NODE_ENABLED" -eq 1 ]] && echo Yes || echo No)"
printf 'phpMyAdmin   : %s\n' "$([[ "$PHPMYADMIN_ENABLED" -eq 1 ]] && echo Yes || echo No)"
printf 'pgAdmin      : %s\n' "$([[ "$PGADMIN_ENABLED" -eq 1 ]] && echo Yes || echo No)"
printf '\nCOMPOSE_PROFILES=%s\n\n' "$PROFILES_CSV"

if ask_yes_no "Build and start the selected stack now?" "y"; then
    docker compose up -d --build
    echo
    docker compose ps
else
    echo "Configuration saved to $ENV_FILE."
    echo "Start later with: docker compose up -d --build"
fi
