#!/usr/bin/env bash

PROJECTS_DIR="$ROOT_DIR/projects"
NGINX_CONF_DIR="$ROOT_DIR/nginx/conf.d"
LARAVEL_NGINX_TEMPLATE="$ROOT_DIR/nginx/template-laravel.conf.example"
NODE_NGINX_TEMPLATE="$ROOT_DIR/nginx/template-node.conf.example"

project_error() {
    printf '%s %s\n' "$FAIL" "$1" >&2
}

project_warn() {
    printf '%s %s\n' "$WARN" "$1"
}

project_info() {
    printf '%s %s\n' "$INFO" "$1"
}

project_yaml_value() {
    local file="$1" key="$2" value
    value="$(sed -n -E "s/^${key}:[[:space:]]*(.*)$/\\1/p" "$file" | head -n1)"
    value="${value#\"}"
    value="${value%\"}"
    printf '%s' "$value"
}

project_detect_type() {
    local path="$1"

    if [[ -f "$path/artisan" && -f "$path/composer.json" ]]; then
        printf 'laravel'
    elif [[ -f "$path/package.json" ]]; then
        printf 'node'
    else
        printf 'unknown'
    fi
}

project_prompt_yes_no() {
    local prompt="$1" default="${2:-n}" answer

    while true; do
        if [[ "$default" == "y" ]]; then
            read -r -p "$prompt [Y/n]: " answer
            answer="${answer:-y}"
        else
            read -r -p "$prompt [y/N]: " answer
            answer="${answer:-n}"
        fi

        case "$answer" in
            y|Y|yes|YES|Yes) return 0 ;;
            n|N|no|NO|No) return 1 ;;
            *) printf 'Please answer y or n.\n' ;;
        esac
    done
}

project_choose_one() {
    local prompt="$1"
    shift
    local items=("$@") index choice

    printf '\n%s\n' "$prompt"
    for ((index = 0; index < ${#items[@]}; index++)); do
        printf '  %d) %s\n' "$((index + 1))" "${items[index]}"
    done

    while true; do
        read -r -p '> ' choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#items[@]} )); then
            PROJECT_CHOICE_INDEX=$((choice - 1))
            return 0
        fi
        printf 'Choose a number from 1 to %d.\n' "${#items[@]}"
    done
}

project_validate_domain() {
    local domain="$1"
    [[ "$domain" =~ ^[A-Za-z0-9][A-Za-z0-9.-]*[A-Za-z0-9]$ || "$domain" =~ ^[A-Za-z0-9]$ ]]
}

project_domain_exists() {
    local domain="$1" metadata existing

    while IFS= read -r -d '' metadata; do
        existing="$(project_yaml_value "$metadata" domain)"
        [[ "$existing" == "$domain" ]] && return 0
    done < <(find "$PROJECTS_DIR" -type f -name .dockavel.yml -print0 2>/dev/null)

    return 1
}

project_enabled_php_services() {
    PROJECT_PHP_SERVICES=()
    PROJECT_PHP_LABELS=()

    if profile_enabled php82; then PROJECT_PHP_SERVICES+=(php82); PROJECT_PHP_LABELS+=("PHP 8.2"); fi
    if profile_enabled php83; then PROJECT_PHP_SERVICES+=(php83); PROJECT_PHP_LABELS+=("PHP 8.3"); fi
    if profile_enabled php84; then PROJECT_PHP_SERVICES+=(php84); PROJECT_PHP_LABELS+=("PHP 8.4"); fi
    if profile_enabled php85; then PROJECT_PHP_SERVICES+=(php85); PROJECT_PHP_LABELS+=("PHP 8.5"); fi
}

project_database_choice() {
    local labels=("None") keys=("none")

    if profile_enabled mysql; then labels+=("MySQL 8"); keys+=("mysql"); fi
    if profile_enabled postgres; then labels+=("PostgreSQL 17"); keys+=("postgres"); fi

    project_choose_one "Database" "${labels[@]}"
    PROJECT_DATABASE="${keys[PROJECT_CHOICE_INDEX]}"
}

project_render_laravel_nginx() {
    local output="$1" domain="$2" project_path="$3" php_service="$4"

    sed \
        -e "s|{{DOMAIN}}|$domain|g" \
        -e "s|{{PROJECT_NAME}}|$project_path|g" \
        -e "s|{{PHP_SERVICE}}|$php_service|g" \
        "$LARAVEL_NGINX_TEMPLATE" > "$output"
}

project_render_node_nginx() {
    local output="$1" domain="$2" port="$3"

    sed \
        -e "s|{{DOMAIN}}|$domain|g" \
        -e "s|{{PORT}}|$port|g" \
        "$NODE_NGINX_TEMPLATE" > "$output"
}

project_nginx_running() {
    [[ "$(docker inspect -f '{{.State.Running}}' dockavel-nginx 2>/dev/null || true)" == "true" ]]
}

project_runtime_running() {
    local service="$1" container
    container="$(docker compose -f "$ROOT_DIR/docker-compose.yml" ps -q "$service" 2>/dev/null | head -n1)"
    [[ -n "$container" ]] && [[ "$(docker inspect -f '{{.State.Running}}' "$container" 2>/dev/null || true)" == "true" ]]
}

project_apply_nginx() {
    if ! project_nginx_running; then
        project_warn "Nginx is not running. Configuration was created but not reloaded."
        return 0
    fi

    if ! docker compose -f "$ROOT_DIR/docker-compose.yml" exec -T nginx nginx -t >/dev/null 2>&1; then
        project_error "Nginx configuration validation failed."
        return 1
    fi

    if docker compose -f "$ROOT_DIR/docker-compose.yml" exec -T nginx nginx -s reload >/dev/null 2>&1; then
        printf '%s Nginx configuration reloaded.\n' "$OK"
    else
        project_error "Nginx configuration is valid but reload failed."
        return 1
    fi
}

project_add() {
    local input rel_path project_dir name detected_type type domain metadata_file nginx_file
    local php_service php_version database redis_enabled=false node_enabled=false node_port=""
    local metadata_tmp nginx_tmp

    mkdir -p "$PROJECTS_DIR" "$NGINX_CONF_DIR"

    printf '\nAdd project\n-----------\n'
    printf 'Project directory must already exist inside: %s\n' "$PROJECTS_DIR"
    read -r -p 'Project directory (example: my-api): ' input

    rel_path="${input#./}"
    rel_path="${rel_path#projects/}"
    rel_path="${rel_path%/}"

    if [[ -z "$rel_path" || "$rel_path" == /* || "$rel_path" == *".."* || "$rel_path" == *" "* ]]; then
        project_error "Use a relative directory inside projects/ without spaces or '..'."
        return 1
    fi

    project_dir="$PROJECTS_DIR/$rel_path"
    if [[ ! -d "$project_dir" ]]; then
        project_error "Project directory does not exist: projects/$rel_path"
        return 1
    fi

    metadata_file="$project_dir/.dockavel.yml"
    if [[ -f "$metadata_file" ]]; then
        project_error "This project is already registered: $metadata_file"
        return 1
    fi

    name="$(basename "$rel_path")"
    detected_type="$(project_detect_type "$project_dir")"

    case "$detected_type" in
        laravel)
            printf '%s Detected Laravel project.\n' "$OK"
            type="laravel"
            ;;
        node)
            printf '%s Detected Node.js project.\n' "$OK"
            type="node"
            ;;
        *)
            project_choose_one "Project type" "Laravel" "Node.js"
            [[ "$PROJECT_CHOICE_INDEX" -eq 0 ]] && type="laravel" || type="node"
            ;;
    esac

    read -r -p "Project name [$name]: " input
    name="${input:-$name}"
    if [[ ! "$name" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]]; then
        project_error "Project name may contain letters, numbers, dash and underscore only."
        return 1
    fi

    domain="${name//_/-}.local"
    read -r -p "Local domain [$domain]: " input
    domain="${input:-$domain}"
    domain="${domain#http://}"
    domain="${domain#https://}"
    domain="${domain%/}"

    if ! project_validate_domain "$domain"; then
        project_error "Invalid local domain: $domain"
        return 1
    fi

    if project_domain_exists "$domain" || [[ -e "$NGINX_CONF_DIR/$domain.conf" ]]; then
        project_error "Domain is already registered: $domain"
        return 1
    fi

    project_database_choice
    database="$PROJECT_DATABASE"

    if profile_enabled redis && project_prompt_yes_no "Use Redis for this project?" n; then
        redis_enabled=true
    fi

    if [[ "$type" == "laravel" ]]; then
        project_enabled_php_services
        if [[ "${#PROJECT_PHP_SERVICES[@]}" -eq 0 ]]; then
            project_error "No PHP runtime is enabled. Run ./setup.sh first."
            return 1
        fi

        project_choose_one "PHP runtime" "${PROJECT_PHP_LABELS[@]}"
        php_service="${PROJECT_PHP_SERVICES[PROJECT_CHOICE_INDEX]}"
        php_version="${php_service#php}"
        php_version="${php_version:0:1}.${php_version:1:1}"

        if ! project_runtime_running "$php_service"; then
            project_error "$php_service is enabled but not running. Start the selected Dockavel stack first."
            return 1
        fi

        if profile_enabled node && project_prompt_yes_no "Use the shared Node.js runtime for frontend commands?" y; then
            node_enabled=true
        fi
    else
        if ! profile_enabled node; then
            project_error "Node.js is not enabled. Run ./setup.sh and enable Node.js first."
            return 1
        fi
        if ! project_runtime_running node; then
            project_error "Node.js is enabled but not running. Start the selected Dockavel stack first."
            return 1
        fi

        while true; do
            read -r -p 'Application port [3000]: ' input
            node_port="${input:-3000}"
            if [[ "$node_port" =~ ^[0-9]+$ ]] && (( node_port >= 3000 && node_port <= 3099 )); then
                break
            fi
            printf 'Choose a port from 3000 to 3099.\n'
        done
        node_enabled=true
    fi

    nginx_file="$NGINX_CONF_DIR/$domain.conf"
    metadata_tmp="$(mktemp)"
    nginx_tmp="$(mktemp)"

    {
        printf 'version: 1\n'
        printf 'name: "%s"\n' "$name"
        printf 'type: "%s"\n' "$type"
        printf 'path: "%s"\n' "$rel_path"
        printf 'domain: "%s"\n' "$domain"
        if [[ "$type" == "laravel" ]]; then
            printf 'php: "%s"\n' "$php_version"
        else
            printf 'port: %s\n' "$node_port"
        fi
        printf 'database: "%s"\n' "$database"
        printf 'redis: %s\n' "$redis_enabled"
        printf 'node: %s\n' "$node_enabled"
    } > "$metadata_tmp"

    if [[ "$type" == "laravel" ]]; then
        project_render_laravel_nginx "$nginx_tmp" "$domain" "$rel_path" "$php_service"
    else
        project_render_node_nginx "$nginx_tmp" "$domain" "$node_port"
    fi

    mv "$metadata_tmp" "$metadata_file"
    mv "$nginx_tmp" "$nginx_file"

    if ! project_apply_nginx; then
        rm -f "$metadata_file" "$nginx_file"
        project_error "Generated project files were rolled back."
        return 1
    fi

    printf '\nProject registered\n------------------\n'
    print_row "Name" "$OK" "$name"
    print_row "Type" "$OK" "$type"
    print_row "Domain" "$OK" "$domain"
    if [[ "$type" == "laravel" ]]; then
        print_row "PHP" "$OK" "$php_version"
    else
        print_row "Node port" "$OK" "$node_port"
    fi
    print_row "Database" "$INFO" "$database"
    print_row "Redis" "$INFO" "$redis_enabled"
    print_row "Node" "$INFO" "$node_enabled"

    printf '\nAdd this entry to your host machine hosts file:\n\n'
    printf '127.0.0.1 %s\n' "$domain"
    printf '\nMetadata: projects/%s/.dockavel.yml\n' "$rel_path"
    printf 'Nginx   : nginx/conf.d/%s.conf\n' "$domain"
}

project_list() {
    local metadata name type domain php port database runtime count=0

    printf '\nDockavel Projects\n=================\n\n'
    printf '%-20s %-10s %-28s %-14s %-12s\n' "NAME" "TYPE" "DOMAIN" "RUNTIME" "DATABASE"
    printf '%-20s %-10s %-28s %-14s %-12s\n' "--------------------" "----------" "----------------------------" "--------------" "------------"

    while IFS= read -r -d '' metadata; do
        name="$(project_yaml_value "$metadata" name)"
        type="$(project_yaml_value "$metadata" type)"
        domain="$(project_yaml_value "$metadata" domain)"
        database="$(project_yaml_value "$metadata" database)"

        if [[ "$type" == "laravel" ]]; then
            php="$(project_yaml_value "$metadata" php)"
            runtime="PHP $php"
        else
            port="$(project_yaml_value "$metadata" port)"
            runtime="Node :$port"
        fi

        printf '%-20s %-10s %-28s %-14s %-12s\n' "$name" "$type" "$domain" "$runtime" "$database"
        count=$((count + 1))
    done < <(find "$PROJECTS_DIR" -type f -name .dockavel.yml -print0 2>/dev/null | sort -z)

    if [[ "$count" -eq 0 ]]; then
        printf '\nNo projects registered yet. Use: ./dockavel project:add\n'
    fi
}
