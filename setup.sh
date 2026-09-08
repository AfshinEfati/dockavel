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

if [[ ! -t 0 || ! -t 1 ]]; then
    echo "Error: Dockavel setup requires an interactive terminal."
    exit 1
fi

if [[ ! -f "$ENV_FILE" ]]; then
    cp "$ENV_EXAMPLE" "$ENV_FILE"
    echo "Created $ENV_FILE from $ENV_EXAMPLE."
fi

sync_env_defaults() {
    local line
    local key
    local added=0

    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
            key="${BASH_REMATCH[1]}"
            if ! grep -q "^${key}=" "$ENV_FILE"; then
                if [[ "$added" -eq 0 ]]; then
                    printf '\n# Added automatically by Dockavel setup\n' >> "$ENV_FILE"
                fi
                printf '%s\n' "$line" >> "$ENV_FILE"
                added=$((added + 1))
            fi
        fi
    done < "$ENV_EXAMPLE"

    if [[ "$added" -gt 0 ]]; then
        echo "Added $added missing setting(s) to $ENV_FILE without changing existing values."
    fi
}

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

migrate_legacy_defaults() {
    local migrated=0

    if grep -qx 'DEBIAN_MIRROR=http://deb.debian.org/debian' "$ENV_FILE"; then
        set_env_value "DEBIAN_MIRROR" "https://deb.debian.org/debian"
        migrated=$((migrated + 1))
    fi

    if grep -qx 'DEBIAN_SECURITY_MIRROR=http://deb.debian.org/debian-security' "$ENV_FILE"; then
        set_env_value "DEBIAN_SECURITY_MIRROR" "https://deb.debian.org/debian-security"
        migrated=$((migrated + 1))
    fi

    if [[ "$migrated" -gt 0 ]]; then
        echo "Updated $migrated legacy Debian mirror setting(s) from HTTP to HTTPS."
    fi
}

add_profile() {
    local profile="$1"
    local existing

    for existing in "${PROFILES[@]:-}"; do
        [[ "$existing" == "$profile" ]] && return 0
    done

    PROFILES+=("$profile")
}

restore_cursor() {
    printf '\033[?25h' 2>/dev/null || true
}

trap restore_cursor EXIT INT TERM

multiselect() {
    local title="$1"
    local minimum="$2"
    local defaults_csv="$3"
    shift 3

    local -a items=("$@")
    local -a checked=()
    local -a defaults=()
    local cursor=0
    local key=""
    local rest=""
    local i
    local selected_count
    local first_render=1

    for ((i = 0; i < ${#items[@]}; i++)); do
        checked[i]=0
    done

    if [[ -n "$defaults_csv" ]]; then
        IFS=',' read -r -a defaults <<< "$defaults_csv"
        for i in "${defaults[@]}"; do
            if [[ "$i" =~ ^[0-9]+$ ]] && (( i >= 0 && i < ${#items[@]} )); then
                checked[i]=1
            fi
        done
    fi

    printf '\n%s\n' "$title"
    printf '%*s\n' "${#title}" '' | tr ' ' '-'
    printf 'Use ↑/↓ to move, Space to select, Enter to confirm.\n\n'
    printf '\033[?25l'

    while true; do
        if [[ "$first_render" -eq 0 ]]; then
            printf '\033[%dA' "${#items[@]}"
        fi
        first_render=0

        for ((i = 0; i < ${#items[@]}; i++)); do
            printf '\033[2K\r'
            if (( i == cursor )); then
                printf '❯ '
            else
                printf '  '
            fi

            if [[ "${checked[i]}" -eq 1 ]]; then
                printf '[x] %s\n' "${items[i]}"
            else
                printf '[ ] %s\n' "${items[i]}"
            fi
        done

        IFS= read -rsn1 key

        case "$key" in
            $'\x1b')
                rest=""
                IFS= read -rsn2 -t 0.1 rest || true
                case "$rest" in
                    '[A') cursor=$(( (cursor - 1 + ${#items[@]}) % ${#items[@]} )) ;;
                    '[B') cursor=$(( (cursor + 1) % ${#items[@]} )) ;;
                esac
                ;;
            k|K) cursor=$(( (cursor - 1 + ${#items[@]}) % ${#items[@]} )) ;;
            j|J) cursor=$(( (cursor + 1) % ${#items[@]} )) ;;
            ' ')
                if [[ "${checked[cursor]}" -eq 1 ]]; then
                    checked[cursor]=0
                else
                    checked[cursor]=1
                fi
                ;;
            '')
                selected_count=0
                for ((i = 0; i < ${#items[@]}; i++)); do
                    [[ "${checked[i]}" -eq 1 ]] && selected_count=$((selected_count + 1))
                done

                if (( selected_count < minimum )); then
                    printf '\a'
                    continue
                fi

                MULTI_SELECTED=()
                for ((i = 0; i < ${#items[@]}; i++)); do
                    [[ "${checked[i]}" -eq 1 ]] && MULTI_SELECTED+=("$i")
                done
                printf '\033[?25h\n'
                return 0
                ;;
        esac
    done
}

choose_one() {
    local title="$1"
    local default_index="$2"
    shift 2

    local -a items=("$@")
    local cursor="$default_index"
    local key=""
    local rest=""
    local i
    local first_render=1

    printf '\n%s\n' "$title"
    printf '%*s\n' "${#title}" '' | tr ' ' '-'
    printf 'Use ↑/↓ to move and Enter to confirm.\n\n'
    printf '\033[?25l'

    while true; do
        if [[ "$first_render" -eq 0 ]]; then
            printf '\033[%dA' "${#items[@]}"
        fi
        first_render=0

        for ((i = 0; i < ${#items[@]}; i++)); do
            printf '\033[2K\r'
            if (( i == cursor )); then
                printf '❯ (●) %s\n' "${items[i]}"
            else
                printf '  ( ) %s\n' "${items[i]}"
            fi
        done

        IFS= read -rsn1 key
        case "$key" in
            $'\x1b')
                rest=""
                IFS= read -rsn2 -t 0.1 rest || true
                case "$rest" in
                    '[A') cursor=$(( (cursor - 1 + ${#items[@]}) % ${#items[@]} )) ;;
                    '[B') cursor=$(( (cursor + 1) % ${#items[@]} )) ;;
                esac
                ;;
            k|K) cursor=$(( (cursor - 1 + ${#items[@]}) % ${#items[@]} )) ;;
            j|J) cursor=$(( (cursor + 1) % ${#items[@]} )) ;;
            '')
                CHOICE_INDEX="$cursor"
                printf '\033[?25h\n'
                return 0
                ;;
        esac
    done
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

sync_env_defaults
migrate_legacy_defaults
print_header

PROFILES=()
PHP_PROFILES=()
PHP_LABELS=()
MULTI_SELECTED=()
CHOICE_INDEX=0
MYSQL_ENABLED=0
POSTGRES_ENABLED=0
REDIS_ENABLED=0
NODE_ENABLED=0
PHPMYADMIN_ENABLED=0
PGADMIN_ENABLED=0

multiselect "PHP runtimes" 1 "0,3" \
    "PHP 8.2" \
    "PHP 8.3" \
    "PHP 8.4" \
    "PHP 8.5"

for index in "${MULTI_SELECTED[@]}"; do
    case "$index" in
        0) PHP_PROFILES+=("php82"); PHP_LABELS+=("8.2") ;;
        1) PHP_PROFILES+=("php83"); PHP_LABELS+=("8.3") ;;
        2) PHP_PROFILES+=("php84"); PHP_LABELS+=("8.4") ;;
        3) PHP_PROFILES+=("php85"); PHP_LABELS+=("8.5") ;;
    esac
done

for profile in "${PHP_PROFILES[@]}"; do
    add_profile "$profile"
done

multiselect "Databases" 0 "0" \
    "MySQL 8" \
    "PostgreSQL 17"

for index in "${MULTI_SELECTED[@]}"; do
    case "$index" in
        0) MYSQL_ENABLED=1; add_profile "mysql" ;;
        1) POSTGRES_ENABLED=1; add_profile "postgres" ;;
    esac
done

multiselect "Optional services" 0 "0,1" \
    "Redis 7" \
    "Node.js 24"

for index in "${MULTI_SELECTED[@]}"; do
    case "$index" in
        0) REDIS_ENABLED=1; add_profile "redis" ;;
        1) NODE_ENABLED=1; add_profile "node" ;;
    esac
done

DB_TOOL_LABELS=()
DB_TOOL_KEYS=()

if [[ "$MYSQL_ENABLED" -eq 1 ]]; then
    DB_TOOL_LABELS+=("phpMyAdmin")
    DB_TOOL_KEYS+=("mysql-ui")
fi

if [[ "$POSTGRES_ENABLED" -eq 1 ]]; then
    DB_TOOL_LABELS+=("pgAdmin")
    DB_TOOL_KEYS+=("postgres-ui")
fi

if [[ "${#DB_TOOL_LABELS[@]}" -gt 0 ]]; then
    multiselect "Database tools" 0 "" "${DB_TOOL_LABELS[@]}"

    for index in "${MULTI_SELECTED[@]}"; do
        case "${DB_TOOL_KEYS[index]}" in
            mysql-ui)
                PHPMYADMIN_ENABLED=1
                add_profile "mysql-ui"
                ;;
            postgres-ui)
                PGADMIN_ENABLED=1
                add_profile "postgres-ui"
                ;;
        esac
    done
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
printf '\nCOMPOSE_PROFILES=%s\n' "$PROFILES_CSV"

choose_one "Build and start the selected stack now?" 0 \
    "Yes, build and start" \
    "No, save configuration only"

if [[ "$CHOICE_INDEX" -eq 0 ]]; then
    docker compose up -d --build
    echo
    docker compose ps
else
    echo "Configuration saved to $ENV_FILE."
    echo "Start later with: docker compose up -d --build"
fi
