#!/usr/bin/env bash

project_db_env_value() {
    local file="$1" key="$2"
    project_env_value_from_file "$file" "$key"
}

project_db_safe_identifier() {
    [[ "$1" =~ ^[A-Za-z0-9_][A-Za-z0-9_-]*$ ]]
}

project_db_prepare() {
    local requested="$1" metadata_file rel_path database env_file connection db_name

    project_select_metadata "$requested" || return 1
    metadata_file="$PROJECT_METADATA_FILE"
    rel_path="$(project_yaml_value "$metadata_file" path)"
    database="$(project_yaml_value "$metadata_file" database)"

    if [[ "$database" != "mysql" && "$database" != "postgres" ]]; then
        project_error "Project database is '${database:-none}'. Set MySQL or PostgreSQL with dockavel project:edit first."
        return 1
    fi

    env_file="$(project_detection_env_file "$PROJECTS_DIR/$rel_path")"
    if [[ -z "$env_file" ]]; then
        project_error "Neither .env nor .env.example was found for projects/$rel_path."
        return 1
    fi

    db_name="$(project_db_env_value "$env_file" DB_DATABASE)"
    connection="$(project_db_env_value "$env_file" DB_CONNECTION)"
    if [[ -z "$db_name" ]]; then
        project_error "DB_DATABASE is missing in ${env_file#$ROOT_DIR/}."
        return 1
    fi
    if ! project_db_safe_identifier "$db_name"; then
        project_error "DB_DATABASE contains unsupported characters for safe CLI automation: $db_name"
        return 1
    fi

    if ! profile_enabled "$database"; then
        project_error "$database is configured for this project but is not enabled in Dockavel."
        return 1
    fi
    if ! project_runtime_running "$database"; then
        project_error "$database is enabled but not running. Start the Dockavel stack first."
        return 1
    fi

    case "$database:$connection" in
        mysql:mysql|mysql:mariadb|postgres:pgsql|postgres:postgres|postgres:postgresql|*:"") ;;
        *) project_warn "Project metadata says $database but DB_CONNECTION is '$connection'." ;;
    esac

    PROJECT_DB_METADATA_FILE="$metadata_file"
    PROJECT_DB_PATH="$rel_path"
    PROJECT_DB_SERVICE="$database"
    PROJECT_DB_NAME="$db_name"
    PROJECT_DB_ENV_FILE="$env_file"
}

project_db_mysql_exists() {
    docker compose -f "$ROOT_DIR/docker-compose.yml" exec -T mysql sh -lc \
        'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot -Nse "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = '\''$1'\'';"' sh "$PROJECT_DB_NAME" 2>/dev/null \
        | grep -Fxq "$PROJECT_DB_NAME"
}

project_db_postgres_exists() {
    docker compose -f "$ROOT_DIR/docker-compose.yml" exec -T postgres sh -lc \
        'PGPASSWORD="$POSTGRES_PASSWORD" psql -U "$POSTGRES_USER" -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname = '\''$1'\'';"' sh "$PROJECT_DB_NAME" 2>/dev/null \
        | grep -Fxq '1'
}

project_db_exists() {
    case "$PROJECT_DB_SERVICE" in
        mysql) project_db_mysql_exists ;;
        postgres) project_db_postgres_exists ;;
        *) return 1 ;;
    esac
}

project_db_status() {
    local requested="${1:-}"
    if [[ -z "$requested" ]]; then
        project_error "Project name is required. Usage: dockavel db:status <project>"
        return 2
    fi

    project_db_prepare "$requested" || return 1

    printf '\nDatabase status\n---------------\n'
    print_row "Project" "$INFO" "$(project_yaml_value "$PROJECT_DB_METADATA_FILE" name)"
    print_row "Service" "$OK" "$PROJECT_DB_SERVICE"
    print_row "Database" "$INFO" "$PROJECT_DB_NAME"
    print_row "Config source" "$INFO" "${PROJECT_DB_ENV_FILE#$ROOT_DIR/}"

    if project_db_exists; then
        print_row "Database exists" "$OK" "yes"
    else
        print_row "Database exists" "$WARN" "no"
        return 1
    fi
}

project_db_create() {
    local requested="${1:-}"
    if [[ -z "$requested" ]]; then
        project_error "Project name is required. Usage: dockavel db:create <project>"
        return 2
    fi

    project_db_prepare "$requested" || return 1

    if project_db_exists; then
        printf '%s Database already exists: %s\n' "$OK" "$PROJECT_DB_NAME"
        return 0
    fi

    case "$PROJECT_DB_SERVICE" in
        mysql)
            docker compose -f "$ROOT_DIR/docker-compose.yml" exec -T mysql sh -lc \
                'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot -e "CREATE DATABASE IF NOT EXISTS `'$PROJECT_DB_NAME'` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"'
            ;;
        postgres)
            docker compose -f "$ROOT_DIR/docker-compose.yml" exec -T postgres sh -lc \
                'PGPASSWORD="$POSTGRES_PASSWORD" createdb -U "$POSTGRES_USER" "$1"' sh "$PROJECT_DB_NAME"
            ;;
    esac

    printf '%s Database created: %s (%s)\n' "$OK" "$PROJECT_DB_NAME" "$PROJECT_DB_SERVICE"
}

project_db_export() {
    local requested="${1:-}" output="${2:-}" project_name timestamp
    if [[ -z "$requested" ]]; then
        project_error "Project name is required. Usage: dockavel db:export <project> [file.sql]"
        return 2
    fi

    project_db_prepare "$requested" || return 1
    if ! project_db_exists; then
        project_error "Database does not exist: $PROJECT_DB_NAME"
        return 1
    fi

    project_name="$(project_yaml_value "$PROJECT_DB_METADATA_FILE" name)"
    timestamp="$(date +%Y%m%d-%H%M%S)"
    output="${output:-./${project_name}-${PROJECT_DB_NAME}-${timestamp}.sql}"

    if [[ -e "$output" ]]; then
        project_error "Refusing to overwrite existing file: $output"
        return 1
    fi
    mkdir -p "$(dirname -- "$output")"

    case "$PROJECT_DB_SERVICE" in
        mysql)
            docker compose -f "$ROOT_DIR/docker-compose.yml" exec -T mysql sh -lc \
                'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysqldump -uroot --single-transaction --routines --triggers "$1"' sh "$PROJECT_DB_NAME" > "$output"
            ;;
        postgres)
            docker compose -f "$ROOT_DIR/docker-compose.yml" exec -T postgres sh -lc \
                'PGPASSWORD="$POSTGRES_PASSWORD" pg_dump -U "$POSTGRES_USER" --no-owner --no-privileges "$1"' sh "$PROJECT_DB_NAME" > "$output"
            ;;
    esac

    printf '%s Database exported: %s\n' "$OK" "$output"
}

project_db_import() {
    local requested="${1:-}" input="${2:-}"
    if [[ -z "$requested" || -z "$input" ]]; then
        project_error "Usage: dockavel db:import <project> <file.sql>"
        return 2
    fi
    if [[ ! -f "$input" ]]; then
        project_error "SQL file not found: $input"
        return 1
    fi

    project_db_prepare "$requested" || return 1
    if ! project_db_exists; then
        project_error "Database does not exist: $PROJECT_DB_NAME. Create it first with: dockavel db:create $requested"
        return 1
    fi

    printf '\nImport target\n-------------\n'
    print_row "Service" "$INFO" "$PROJECT_DB_SERVICE"
    print_row "Database" "$INFO" "$PROJECT_DB_NAME"
    print_row "Input" "$INFO" "$input"
    printf '%s Importing SQL can modify or delete existing data.\n' "$WARN"
    if ! project_prompt_yes_no "Continue with import?" n; then
        project_info "Cancelled. Database was not changed."
        return 0
    fi

    case "$PROJECT_DB_SERVICE" in
        mysql)
            docker compose -f "$ROOT_DIR/docker-compose.yml" exec -T mysql sh -lc \
                'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot "$1"' sh "$PROJECT_DB_NAME" < "$input"
            ;;
        postgres)
            docker compose -f "$ROOT_DIR/docker-compose.yml" exec -T postgres sh -lc \
                'PGPASSWORD="$POSTGRES_PASSWORD" psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$1"' sh "$PROJECT_DB_NAME" < "$input"
            ;;
    esac

    printf '%s Database import completed: %s\n' "$OK" "$PROJECT_DB_NAME"
}
