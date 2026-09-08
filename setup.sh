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
    local line key added=0

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
    local key="$1" value="$2" tmp
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
            if (!updated) print key "=" value
        }
    ' "$ENV_FILE" > "$tmp"

    mv "$tmp" "$ENV_FILE"
}

get_env_value() {
    local key="$1"
    grep -m1 "^${key}=" "$ENV_FILE" | cut -d= -f2- || true
}

add_profile() {
    local profile="$1" existing
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
    local title="$1" minimum="$2" defaults_csv="$3"
    shift 3

    local -a items=("$@") checked=() defaults=()
    local cursor=0 key="" rest="" i selected_count first_render=1

    for ((i = 0; i < ${#items[@]}; i++)); do checked[i]=0; done

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
            (( i == cursor )) && printf '❯ ' || printf '  '
            [[ "${checked[i]}" -eq 1 ]] && printf '[x] %s\n' "${items[i]}" || printf '[ ] %s\n' "${items[i]}"
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
            ' ') [[ "${checked[cursor]}" -eq 1 ]] && checked[cursor]=0 || checked[cursor]=1 ;;
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
    local title="$1" default_index="$2"
    shift 2

    local -a items=("$@")
    local cursor="$default_index" key="" rest="" i first_render=1

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

prompt_url() {
    local prompt="$1" current="$2" value
    while true; do
        read -r -p "$prompt [$current]: " value
        value="${value:-$current}"
        if [[ "$value" =~ ^https?://[^[:space:]]+$ ]]; then
            PROMPT_RESULT="$value"
            return 0
        fi
        echo "Enter a valid http:// or https:// URL."
    done
}

prompt_registry_prefix() {
    local prompt="$1" current="$2" allow_empty="${3:-0}" value
    while true; do
        read -r -p "$prompt [$current]: " value
        value="${value:-$current}"

        if [[ "$value" == "-" && "$allow_empty" -eq 1 ]]; then
            PROMPT_RESULT=""
            return 0
        fi

        if [[ -z "$value" && "$allow_empty" -eq 1 ]]; then
            PROMPT_RESULT=""
            return 0
        fi

        if [[ -n "$value" && "$value" != *"://"* && "$value" != *" "* ]]; then
            [[ "$value" == */ ]] || value="${value}/"
            PROMPT_RESULT="$value"
            return 0
        fi

        echo "Enter an image prefix without http:// or https://."
        [[ "$allow_empty" -eq 1 ]] && echo "Use - to clear the prefix."
    done
}

print_header() {
    cat <<'HEADER'

╔══════════════════════════════════════╗
║            Dockavel Setup            ║
╚══════════════════════════════════════╝

Choose only the runtimes and services you actually need.
Dockavel pulls prebuilt PHP/Node runtimes, so setup does not compile extensions locally.
HEADER
}

select_download_source() {
    local preset default_index=0 current
    preset="$(get_env_value DOWNLOAD_SOURCE_PRESET)"

    case "$preset" in
        official) default_index=0 ;;
        iranserver) default_index=1 ;;
        iran|runflare) default_index=2 ;;
        china) default_index=3 ;;
        custom) default_index=4 ;;
        *) default_index=0 ;;
    esac

    choose_one "Download source" "$default_index" \
        "Official / Global" \
        "Iran / IranServer (recommended)" \
        "Iran / Runflare (GHCR proxy, quota-limited)" \
        "China / regional mirrors" \
        "Custom endpoints"

    case "$CHOICE_INDEX" in
        0)
            DOWNLOAD_SOURCE_PRESET="official"
            SOURCE_LABEL="Official / Global"
            DOCKAVEL_RUNTIME_PREFIX="ghcr.io/afshinefati/"
            DOCKER_LIBRARY_PREFIX=""
            DOCKER_NAMESPACE_PREFIX=""
            GHCR_PREFIX="ghcr.io/"
            DEBIAN_MIRROR="https://deb.debian.org/debian"
            DEBIAN_SECURITY_MIRROR="https://deb.debian.org/debian-security"
            COMPOSER_REPOSITORY="https://repo.packagist.org"
            NPM_REGISTRY="https://registry.npmjs.org/"
            NPM_STRICT_SSL="true"
            ;;
        1)
            DOWNLOAD_SOURCE_PRESET="iranserver"
            SOURCE_LABEL="Iran / IranServer"
            # IranServer mirrors Docker Hub, Debian, Composer and npm. Dockavel's
            # prebuilt runtimes currently live on GHCR, so those few images are
            # pulled directly from GHCR instead of consuming Runflare quota.
            DOCKAVEL_RUNTIME_PREFIX="ghcr.io/afshinefati/"
            DOCKER_LIBRARY_PREFIX="docker.iranserver.com/library/"
            DOCKER_NAMESPACE_PREFIX="docker.iranserver.com/"
            GHCR_PREFIX="ghcr.io/"
            DEBIAN_MIRROR="https://mirror.iranserver.com/debian"
            DEBIAN_SECURITY_MIRROR="https://mirror.iranserver.com/debian-security"
            COMPOSER_REPOSITORY="https://composer.iranserver.com/repository/composer/"
            NPM_REGISTRY="https://npm.iranserver.com/repository/npm/"
            NPM_STRICT_SSL="false"
            ;;
        2)
            DOWNLOAD_SOURCE_PRESET="runflare"
            SOURCE_LABEL="Iran / Runflare"
            DOCKAVEL_RUNTIME_PREFIX="mirror-docker.runflare.com/afshinefati/"
            DOCKER_LIBRARY_PREFIX="mirror-docker.runflare.com/library/"
            DOCKER_NAMESPACE_PREFIX="mirror-docker.runflare.com/"
            GHCR_PREFIX="mirror-docker.runflare.com/"
            DEBIAN_MIRROR="http://mirror-linux.runflare.com/debian"
            DEBIAN_SECURITY_MIRROR="http://mirror-linux.runflare.com/debian-security"
            COMPOSER_REPOSITORY="https://mirror-composer.runflare.com"
            NPM_REGISTRY="https://mirror-npm.runflare.com"
            NPM_STRICT_SSL="false"
            ;;
        3)
            DOWNLOAD_SOURCE_PRESET="china"
            SOURCE_LABEL="China / regional mirrors"
            DOCKAVEL_RUNTIME_PREFIX="m.daocloud.io/ghcr.io/afshinefati/"
            DOCKER_LIBRARY_PREFIX="m.daocloud.io/docker.io/library/"
            DOCKER_NAMESPACE_PREFIX="m.daocloud.io/docker.io/"
            GHCR_PREFIX="m.daocloud.io/ghcr.io/"
            DEBIAN_MIRROR="https://mirrors.tuna.tsinghua.edu.cn/debian"
            DEBIAN_SECURITY_MIRROR="https://mirrors.tuna.tsinghua.edu.cn/debian-security"
            COMPOSER_REPOSITORY="https://mirrors.aliyun.com/composer/"
            NPM_REGISTRY="https://registry.npmmirror.com/"
            NPM_STRICT_SSL="true"
            ;;
        4)
            DOWNLOAD_SOURCE_PRESET="custom"
            SOURCE_LABEL="Custom"

            current="$(get_env_value DOCKAVEL_RUNTIME_PREFIX)"
            prompt_registry_prefix "Dockavel runtime image prefix" "$current" 0
            DOCKAVEL_RUNTIME_PREFIX="$PROMPT_RESULT"

            current="$(get_env_value DOCKER_LIBRARY_PREFIX)"
            prompt_registry_prefix "Docker Hub library prefix (- to clear)" "$current" 1
            DOCKER_LIBRARY_PREFIX="$PROMPT_RESULT"

            current="$(get_env_value DOCKER_NAMESPACE_PREFIX)"
            prompt_registry_prefix "Docker Hub namespace prefix (- to clear)" "$current" 1
            DOCKER_NAMESPACE_PREFIX="$PROMPT_RESULT"

            current="$(get_env_value GHCR_PREFIX)"
            prompt_registry_prefix "GHCR-compatible build prefix" "$current" 0
            GHCR_PREFIX="$PROMPT_RESULT"

            current="$(get_env_value DEBIAN_MIRROR)"
            prompt_url "Debian package mirror" "$current"
            DEBIAN_MIRROR="$PROMPT_RESULT"

            current="$(get_env_value DEBIAN_SECURITY_MIRROR)"
            prompt_url "Debian security mirror" "$current"
            DEBIAN_SECURITY_MIRROR="$PROMPT_RESULT"

            current="$(get_env_value COMPOSER_REPOSITORY)"
            prompt_url "Composer / Packagist repository" "$current"
            COMPOSER_REPOSITORY="$PROMPT_RESULT"

            current="$(get_env_value NPM_REGISTRY)"
            prompt_url "npm registry" "$current"
            NPM_REGISTRY="$PROMPT_RESULT"

            choose_one "npm strict SSL" 0 \
                "Enabled (recommended)" \
                "Disabled (only when your mirror requires it)"
            [[ "$CHOICE_INDEX" -eq 0 ]] && NPM_STRICT_SSL="true" || NPM_STRICT_SSL="false"
            ;;
    esac

    set_env_value "DOWNLOAD_SOURCE_PRESET" "$DOWNLOAD_SOURCE_PRESET"
    set_env_value "DOCKAVEL_RUNTIME_PREFIX" "$DOCKAVEL_RUNTIME_PREFIX"
    set_env_value "DOCKER_LIBRARY_PREFIX" "$DOCKER_LIBRARY_PREFIX"
    set_env_value "DOCKER_NAMESPACE_PREFIX" "$DOCKER_NAMESPACE_PREFIX"
    set_env_value "GHCR_PREFIX" "$GHCR_PREFIX"
    set_env_value "DEBIAN_MIRROR" "$DEBIAN_MIRROR"
    set_env_value "DEBIAN_SECURITY_MIRROR" "$DEBIAN_SECURITY_MIRROR"
    set_env_value "COMPOSER_REPOSITORY" "$COMPOSER_REPOSITORY"
    set_env_value "NPM_REGISTRY" "$NPM_REGISTRY"
    set_env_value "NPM_STRICT_SSL" "$NPM_STRICT_SSL"
}

sync_env_defaults
print_header

PROFILES=()
PHP_PROFILES=()
PHP_LABELS=()
MULTI_SELECTED=()
CHOICE_INDEX=0
PROMPT_RESULT=""
SOURCE_LABEL=""
MYSQL_ENABLED=0
POSTGRES_ENABLED=0
REDIS_ENABLED=0
NODE_ENABLED=0
PHPMYADMIN_ENABLED=0
PGADMIN_ENABLED=0

select_download_source

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

for profile in "${PHP_PROFILES[@]}"; do add_profile "$profile"; done

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
            mysql-ui) PHPMYADMIN_ENABLED=1; add_profile "mysql-ui" ;;
            postgres-ui) PGADMIN_ENABLED=1; add_profile "postgres-ui" ;;
        esac
    done
fi

PROFILES_CSV="$(IFS=,; echo "${PROFILES[*]}")"
set_env_value "COMPOSE_PROFILES" "$PROFILES_CSV"

COMPOSE_PROFILES="$PROFILES_CSV" docker compose config >/dev/null

printf '\nConfiguration\n-------------\n'
printf 'Download source : %s\n' "$SOURCE_LABEL"
printf 'Dockavel images : %s\n' "$DOCKAVEL_RUNTIME_PREFIX"
printf 'Docker library  : %s\n' "${DOCKER_LIBRARY_PREFIX:-docker.io/library/}"
printf 'Composer        : %s\n' "$COMPOSER_REPOSITORY"
printf 'npm             : %s\n' "$NPM_REGISTRY"
printf 'PHP runtimes    : %s\n' "$(IFS=', '; echo "${PHP_LABELS[*]}")"
printf 'MySQL           : %s\n' "$([[ "$MYSQL_ENABLED" -eq 1 ]] && echo Yes || echo No)"
printf 'PostgreSQL      : %s\n' "$([[ "$POSTGRES_ENABLED" -eq 1 ]] && echo Yes || echo No)"
printf 'Redis           : %s\n' "$([[ "$REDIS_ENABLED" -eq 1 ]] && echo Yes || echo No)"
printf 'Node.js         : %s\n' "$([[ "$NODE_ENABLED" -eq 1 ]] && echo Yes || echo No)"
printf 'phpMyAdmin      : %s\n' "$([[ "$PHPMYADMIN_ENABLED" -eq 1 ]] && echo Yes || echo No)"
printf 'pgAdmin         : %s\n' "$([[ "$PGADMIN_ENABLED" -eq 1 ]] && echo Yes || echo No)"
printf '\nCOMPOSE_PROFILES=%s\n' "$PROFILES_CSV"

if [[ "$DOWNLOAD_SOURCE_PRESET" == "runflare" ]]; then
    printf '\nNote: Runflare currently limits free mirror usage to 500 requests per IP.\n'
    printf 'A 402 Payment Required response normally means that quota has been exhausted.\n'
fi

choose_one "Pull and start the selected stack now?" 0 \
    "Yes, pull and start" \
    "No, save configuration only"

if [[ "$CHOICE_INDEX" -eq 0 ]]; then
    docker compose pull
    docker compose up -d
    echo
    docker compose ps
else
    echo "Configuration saved to $ENV_FILE."
    echo "Start later with: docker compose pull && docker compose up -d"
fi
