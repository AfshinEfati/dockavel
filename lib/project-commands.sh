#!/usr/bin/env bash

project_command_usage_error() {
    local command="$1"
    project_error "Project name is required. Usage: ./dockavel $command <project> [arguments...]"
}

project_command_resolve() {
    local requested="$1" metadata_file rel_path type php_version node_enabled

    if [[ -z "$requested" ]]; then
        return 1
    fi

    project_select_metadata "$requested" || return 1
    metadata_file="$PROJECT_METADATA_FILE"
    rel_path="$(project_yaml_value "$metadata_file" path)"
    type="$(project_yaml_value "$metadata_file" type)"
    php_version="$(project_yaml_value "$metadata_file" php)"
    node_enabled="$(project_yaml_value "$metadata_file" node)"

    if [[ -z "$rel_path" || "$rel_path" == /* || "$rel_path" == *".."* ]]; then
        project_error "Invalid project path in metadata: $rel_path"
        return 1
    fi

    if [[ ! -d "$PROJECTS_DIR/$rel_path" ]]; then
        project_error "Project directory no longer exists: projects/$rel_path"
        return 1
    fi

    PROJECT_COMMAND_METADATA_FILE="$metadata_file"
    PROJECT_COMMAND_PATH="$rel_path"
    PROJECT_COMMAND_TYPE="$type"
    PROJECT_COMMAND_PHP="$php_version"
    PROJECT_COMMAND_NODE_ENABLED="$node_enabled"
    PROJECT_COMMAND_WORKDIR="/var/www/$rel_path"
}

project_command_php_service() {
    local version="$1"

    case "$version" in
        8.2) printf 'php82' ;;
        8.3) printf 'php83' ;;
        8.4) printf 'php84' ;;
        8.5) printf 'php85' ;;
        *)
            project_error "Unsupported PHP runtime in project metadata: ${version:-missing}"
            return 1
            ;;
    esac
}

project_command_require_service() {
    local service="$1" profile="$2"

    if ! profile_enabled "$profile"; then
        project_error "$service is required by this project but is not enabled. Run ./setup.sh and enable it first."
        return 1
    fi

    if ! project_runtime_running "$service"; then
        project_error "$service is enabled but not running. Start the selected Dockavel stack first."
        return 1
    fi
}

project_command_require_visible_path() {
    local service="$1"

    if docker compose -f "$ROOT_DIR/docker-compose.yml" exec -T "$service" test -d "$PROJECT_COMMAND_WORKDIR" >/dev/null 2>&1; then
        return 0
    fi

    project_error "Project exists on the host but is not visible inside $service: $PROJECT_COMMAND_WORKDIR"
    project_info "Check the Docker projects bind mount. If Docker Desktop has a stale mount, restart Docker Desktop and retry."
    return 1
}

project_command_prepare_php() {
    local service

    if [[ "$PROJECT_COMMAND_TYPE" != "laravel" ]]; then
        project_error "This command requires a Laravel project; '$PROJECT_COMMAND_TYPE' project selected."
        return 1
    fi

    service="$(project_command_php_service "$PROJECT_COMMAND_PHP")" || return 1
    project_command_require_service "$service" "$service" || return 1
    project_command_require_visible_path "$service" || return 1
    PROJECT_COMMAND_SERVICE="$service"
}

project_command_prepare_node() {
    if [[ "$PROJECT_COMMAND_TYPE" != "node" && "$PROJECT_COMMAND_NODE_ENABLED" != "true" ]]; then
        project_error "Node.js is not enabled for this project. Run ./dockavel project:edit and enable the shared Node runtime first."
        return 1
    fi

    project_command_require_service node node || return 1
    project_command_require_visible_path node || return 1
    PROJECT_COMMAND_SERVICE="node"
}

project_shell() {
    local requested="${1:-}"

    if [[ -z "$requested" ]]; then
        project_command_usage_error shell
        return 2
    fi

    project_command_resolve "$requested" || return 1

    if [[ "$PROJECT_COMMAND_TYPE" == "node" ]]; then
        project_command_prepare_node || return 1
    else
        project_command_prepare_php || return 1
    fi

    printf '%s Opening %s shell in projects/%s\n' "$INFO" "$PROJECT_COMMAND_SERVICE" "$PROJECT_COMMAND_PATH"
    docker compose -f "$ROOT_DIR/docker-compose.yml" exec \
        -w "$PROJECT_COMMAND_WORKDIR" \
        "$PROJECT_COMMAND_SERVICE" bash
}

project_artisan() {
    local requested="${1:-}"
    shift || true

    if [[ -z "$requested" ]]; then
        project_command_usage_error artisan
        return 2
    fi

    project_command_resolve "$requested" || return 1
    project_command_prepare_php || return 1

    if [[ ! -f "$PROJECTS_DIR/$PROJECT_COMMAND_PATH/artisan" ]]; then
        project_error "artisan was not found in projects/$PROJECT_COMMAND_PATH"
        return 1
    fi

    docker compose -f "$ROOT_DIR/docker-compose.yml" exec \
        -w "$PROJECT_COMMAND_WORKDIR" \
        "$PROJECT_COMMAND_SERVICE" php artisan "$@"
}

project_composer() {
    local requested="${1:-}"
    shift || true

    if [[ -z "$requested" ]]; then
        project_command_usage_error composer
        return 2
    fi

    project_command_resolve "$requested" || return 1
    project_command_prepare_php || return 1

    if [[ ! -f "$PROJECTS_DIR/$PROJECT_COMMAND_PATH/composer.json" ]]; then
        project_error "composer.json was not found in projects/$PROJECT_COMMAND_PATH"
        return 1
    fi

    docker compose -f "$ROOT_DIR/docker-compose.yml" exec \
        -w "$PROJECT_COMMAND_WORKDIR" \
        "$PROJECT_COMMAND_SERVICE" composer "$@"
}

project_npm() {
    local requested="${1:-}"
    shift || true

    if [[ -z "$requested" ]]; then
        project_command_usage_error npm
        return 2
    fi

    project_command_resolve "$requested" || return 1
    project_command_prepare_node || return 1

    docker compose -f "$ROOT_DIR/docker-compose.yml" exec \
        -w "$PROJECT_COMMAND_WORKDIR" \
        "$PROJECT_COMMAND_SERVICE" npm "$@"
}
