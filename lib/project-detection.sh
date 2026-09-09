#!/usr/bin/env bash

project_env_value_from_file() {
    local file="$1" key="$2" value
    [[ -f "$file" ]] || return 0
    value="$(sed -n -E "s/^[[:space:]]*(export[[:space:]]+)?${key}[[:space:]]*=[[:space:]]*(.*)$/\\2/p" "$file" | head -n1 | tr -d '\r')"
    value="${value#\"}"
    value="${value%\"}"
    value="${value#\'}"
    value="${value%\'}"
    printf '%s' "$value"
}

project_detection_env_file() {
    local project_dir="$1"
    if [[ -f "$project_dir/.env" ]]; then
        printf '%s/.env' "$project_dir"
    elif [[ -f "$project_dir/.env.example" ]]; then
        printf '%s/.env.example' "$project_dir"
    fi
}

project_detection_php_constraint() {
    local composer="$1" match
    [[ -f "$composer" ]] || return 0
    match="$(grep -oE '"php"[[:space:]]*:[[:space:]]*"[^"]+"' "$composer" 2>/dev/null | head -n1 || true)"
    [[ -n "$match" ]] || return 0
    printf '%s' "$match" | sed -E 's/^"php"[[:space:]]*:[[:space:]]*"([^"]+)"$/\1/'
}

project_detection_min_php() {
    local constraint="$1" version
    version="$(printf '%s' "$constraint" | grep -oE '8\.[0-9]+' | head -n1 || true)"
    printf '%s' "$version"
}

project_detection_suggest_php() {
    local min_version="$1" min_minor minor service
    [[ "$min_version" =~ ^8\.([0-9]+)$ ]] || return 0
    min_minor="${BASH_REMATCH[1]}"

    for minor in 2 3 4 5; do
        (( minor < min_minor )) && continue
        service="php8${minor}"
        if profile_enabled "$service"; then
            printf '8.%s' "$minor"
            return 0
        fi
    done
}

project_detection_package_manager() {
    local dir="$1"
    if [[ -f "$dir/pnpm-lock.yaml" ]]; then
        printf 'pnpm'
    elif [[ -f "$dir/yarn.lock" ]]; then
        printf 'yarn'
    elif [[ -f "$dir/bun.lockb" || -f "$dir/bun.lock" ]]; then
        printf 'bun'
    elif [[ -f "$dir/package-lock.json" ]]; then
        printf 'npm'
    elif [[ -f "$dir/package.json" ]]; then
        printf 'npm (no lockfile)'
    else
        printf 'none'
    fi
}

project_detection_database() {
    local env_file="$1" connection
    [[ -n "$env_file" ]] || return 0
    connection="$(project_env_value_from_file "$env_file" DB_CONNECTION)"
    case "$connection" in
        mysql|mariadb) printf 'mysql' ;;
        pgsql|postgres|postgresql) printf 'postgres' ;;
        sqlite) printf 'none' ;;
    esac
}

project_detection_redis() {
    local env_file="$1" cache session queue redis_host
    [[ -n "$env_file" ]] || { printf 'unknown'; return 0; }

    cache="$(project_env_value_from_file "$env_file" CACHE_STORE)"
    [[ -z "$cache" ]] && cache="$(project_env_value_from_file "$env_file" CACHE_DRIVER)"
    session="$(project_env_value_from_file "$env_file" SESSION_DRIVER)"
    queue="$(project_env_value_from_file "$env_file" QUEUE_CONNECTION)"
    redis_host="$(project_env_value_from_file "$env_file" REDIS_HOST)"

    if [[ "$cache" == "redis" || "$session" == "redis" || "$queue" == "redis" ]]; then
        printf 'yes'
    elif [[ -n "$redis_host" && "$redis_host" != "127.0.0.1" && "$redis_host" != "localhost" ]]; then
        printf 'possible'
    else
        printf 'no'
    fi
}

project_detection_collect() {
    local project_dir="$1" type="$2" env_file min_php

    PROJECT_DETECTED_TYPE="$type"
    PROJECT_DETECTED_ENV_FILE="$(project_detection_env_file "$project_dir")"
    PROJECT_DETECTED_PHP_CONSTRAINT=""
    PROJECT_DETECTED_PHP_SUGGESTION=""
    PROJECT_DETECTED_DATABASE="$(project_detection_database "$PROJECT_DETECTED_ENV_FILE")"
    PROJECT_DETECTED_PACKAGE_MANAGER="$(project_detection_package_manager "$project_dir")"
    PROJECT_DETECTED_NODE=false
    PROJECT_DETECTED_REDIS="$(project_detection_redis "$PROJECT_DETECTED_ENV_FILE")"

    [[ -f "$project_dir/package.json" ]] && PROJECT_DETECTED_NODE=true

    if [[ "$type" == "laravel" ]]; then
        PROJECT_DETECTED_PHP_CONSTRAINT="$(project_detection_php_constraint "$project_dir/composer.json")"
        min_php="$(project_detection_min_php "$PROJECT_DETECTED_PHP_CONSTRAINT")"
        PROJECT_DETECTED_PHP_SUGGESTION="$(project_detection_suggest_php "$min_php")"
    fi
}

project_detection_print_summary() {
    local env_label="none"
    [[ -n "${PROJECT_DETECTED_ENV_FILE:-}" ]] && env_label="$(basename "$PROJECT_DETECTED_ENV_FILE")"

    printf '\nSmart detection\n---------------\n'
    print_row "Type" "$INFO" "${PROJECT_DETECTED_TYPE:-unknown}"
    if [[ "${PROJECT_DETECTED_TYPE:-}" == "laravel" ]]; then
        print_row "PHP requirement" "$INFO" "${PROJECT_DETECTED_PHP_CONSTRAINT:-not detected}"
        if [[ -n "${PROJECT_DETECTED_PHP_SUGGESTION:-}" ]]; then
            print_row "Suggested PHP" "$OK" "$PROJECT_DETECTED_PHP_SUGGESTION"
        else
            print_row "Suggested PHP" "$WARN" "choose from enabled runtimes"
        fi
    fi
    print_row "Node frontend" "$INFO" "${PROJECT_DETECTED_NODE:-false}"
    print_row "Package manager" "$INFO" "${PROJECT_DETECTED_PACKAGE_MANAGER:-none}"
    print_row "Database hint" "$INFO" "${PROJECT_DETECTED_DATABASE:-not detected}"
    print_row "Redis hint" "$INFO" "${PROJECT_DETECTED_REDIS:-unknown}"
    print_row "Environment source" "$INFO" "$env_label"
    printf '%s Suggestions are informational; project:add still asks before saving metadata.\n' "$INFO"
}

# Override the basic detector from project-manager.sh with richer, read-only hints.
project_detect_type() {
    local path="$1" type

    if [[ -f "$path/artisan" && -f "$path/composer.json" ]]; then
        type="laravel"
    elif [[ -f "$path/package.json" ]]; then
        type="node"
    else
        type="unknown"
    fi

    project_detection_collect "$path" "$type"
    project_detection_print_summary >&2
    printf '%s' "$type"
}

# Keep the existing selection behavior but make the suggested PHP runtime visible.
project_enabled_php_services() {
    local version label
    PROJECT_PHP_SERVICES=()
    PROJECT_PHP_LABELS=()

    for version in 8.2 8.3 8.4 8.5; do
        local service="php${version/.}"
        profile_enabled "$service" || continue
        label="PHP $version"
        [[ "${PROJECT_DETECTED_PHP_SUGGESTION:-}" == "$version" ]] && label+=" (suggested)"
        PROJECT_PHP_SERVICES+=("$service")
        PROJECT_PHP_LABELS+=("$label")
    done
}

# Keep edit behavior unchanged; during project:add, mark a detected database as suggested.
project_database_choice() {
    local current="${1:-}" labels=("None") keys=("none") index default_index=0 label

    if profile_enabled mysql; then
        label="MySQL 8"
        [[ -z "$current" && "${PROJECT_DETECTED_DATABASE:-}" == "mysql" ]] && label+=" (suggested)"
        labels+=("$label"); keys+=("mysql")
    fi
    if profile_enabled postgres; then
        label="PostgreSQL 17"
        [[ -z "$current" && "${PROJECT_DETECTED_DATABASE:-}" == "postgres" ]] && label+=" (suggested)"
        labels+=("$label"); keys+=("postgres")
    fi

    for ((index = 0; index < ${#keys[@]}; index++)); do
        if [[ "${keys[index]}" == "$current" ]]; then
            default_index="$index"
            break
        fi
    done

    if [[ -n "$current" ]]; then
        project_choose_one_default "Database" "$default_index" "${labels[@]}"
    else
        project_choose_one "Database" "${labels[@]}"
    fi
    PROJECT_DATABASE="${keys[PROJECT_CHOICE_INDEX]}"
}

project_detect_command() {
    local input="${1:-}" rel_path project_dir type

    if [[ -z "$input" ]]; then
        project_error "Project directory is required. Usage: dockavel project:detect <directory>"
        return 2
    fi

    rel_path="${input#./}"
    rel_path="${rel_path#projects/}"
    rel_path="${rel_path%/}"
    if [[ -z "$rel_path" || "$rel_path" == /* || "$rel_path" == *".."* ]]; then
        project_error "Use a relative directory inside projects/."
        return 1
    fi

    project_dir="$PROJECTS_DIR/$rel_path"
    if [[ ! -d "$project_dir" ]]; then
        project_error "Project directory does not exist: projects/$rel_path"
        return 1
    fi

    if [[ -f "$project_dir/artisan" && -f "$project_dir/composer.json" ]]; then
        type="laravel"
    elif [[ -f "$project_dir/package.json" ]]; then
        type="node"
    else
        type="unknown"
    fi

    project_detection_collect "$project_dir" "$type"
    printf '\nProject: projects/%s\n' "$rel_path"
    project_detection_print_summary
}
