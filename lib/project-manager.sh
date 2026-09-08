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

project_choose_one_default() {
    local prompt="$1" default_index="$2"
    shift 2
    local items=("$@") index choice

    printf '\n%s\n' "$prompt"
    for ((index = 0; index < ${#items[@]}; index++)); do
        if [[ "$index" -eq "$default_index" ]]; then
            printf '  %d) %s (current)\n' "$((index + 1))" "${items[index]}"
        else
            printf '  %d) %s\n' "$((index + 1))" "${items[index]}"
        fi
    done

    while true; do
        read -r -p "> [$((default_index + 1))] " choice
        choice="${choice:-$((default_index + 1))}"
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
    local domain="$1" exclude="${2:-}" metadata existing

    while IFS= read -r -d '' metadata; do
        [[ -n "$exclude" && "$metadata" == "$exclude" ]] && continue
        existing="$(project_yaml_value "$metadata" domain)"
        [[ "$existing" == "$domain" ]] && return 0
    done < <(find "$PROJECTS_DIR" -type f -name .dockavel.yml -print0 2>/dev/null)

    return 1
}

project_name_exists() {
    local name="$1" exclude="${2:-}" metadata existing

    while IFS= read -r -d '' metadata; do
        [[ -n "$exclude" && "$metadata" == "$exclude" ]] && continue
        existing="$(project_yaml_value "$metadata" name)"
        [[ "$existing" == "$name" ]] && return 0
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
    local current="${1:-}" labels=("None") keys=("none") index default_index=0

    if profile_enabled mysql; then labels+=("MySQL 8"); keys+=("mysql"); fi
    if profile_enabled postgres; then labels+=("PostgreSQL 17"); keys+=("postgres"); fi

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

project_write_metadata() {
    local output="$1" name="$2" type="$3" rel_path="$4" domain="$5" php_version="$6"
    local node_port="$7" database="$8" redis_enabled="$9" node_enabled="${10}"

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
    } > "$output"
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
        project_warn "Nginx is not running. Configuration was changed but not reloaded."
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

project_select_metadata() {
    local requested="${1:-}" metadata name domain path normalized count=0
    local files=() labels=() matches=()

    while IFS= read -r -d '' metadata; do
        files+=("$metadata")
        name="$(project_yaml_value "$metadata" name)"
        domain="$(project_yaml_value "$metadata" domain)"
        path="$(project_yaml_value "$metadata" path)"
        labels+=("$name · $domain · projects/$path")
    done < <(find "$PROJECTS_DIR" -type f -name .dockavel.yml -print0 2>/dev/null | sort -z)

    if [[ "${#files[@]}" -eq 0 ]]; then
        project_error "No projects are registered yet."
        return 1
    fi

    if [[ -n "$requested" ]]; then
        normalized="${requested#./}"
        normalized="${normalized#projects/}"
        normalized="${normalized%/}"

        for ((count = 0; count < ${#files[@]}; count++)); do
            metadata="${files[count]}"
            name="$(project_yaml_value "$metadata" name)"
            path="$(project_yaml_value "$metadata" path)"
            domain="$(project_yaml_value "$metadata" domain)"
            if [[ "$requested" == "$name" || "$normalized" == "$path" || "$requested" == "$domain" ]]; then
                matches+=("$metadata")
            fi
        done

        if [[ "${#matches[@]}" -eq 0 ]]; then
            project_error "Project not found: $requested"
            return 1
        fi
        if [[ "${#matches[@]}" -gt 1 ]]; then
            project_error "Project selector is ambiguous: $requested"
            return 1
        fi

        PROJECT_METADATA_FILE="${matches[0]}"
        return 0
    fi

    project_choose_one "Select project" "${labels[@]}"
    PROJECT_METADATA_FILE="${files[PROJECT_CHOICE_INDEX]}"
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
    if project_name_exists "$name"; then
        project_error "Project name is already registered: $name"
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

    project_write_metadata "$metadata_tmp" "$name" "$type" "$rel_path" "$domain" "$php_version" "$node_port" "$database" "$redis_enabled" "$node_enabled"

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

project_edit() {
    local requested="${1:-}" metadata_file project_dir rel_path type
    local current_name current_domain current_php current_database current_redis current_node current_port
    local input name domain php_service php_version database redis_enabled=false node_enabled=false node_port=""
    local old_nginx_file new_nginx_file metadata_tmp nginx_tmp metadata_backup nginx_backup old_nginx_exists=false
    local default_php_index=0 index current_php_service

    printf '\nEdit project\n------------\n'
    project_select_metadata "$requested" || return 1
    metadata_file="$PROJECT_METADATA_FILE"

    rel_path="$(project_yaml_value "$metadata_file" path)"
    type="$(project_yaml_value "$metadata_file" type)"
    current_name="$(project_yaml_value "$metadata_file" name)"
    current_domain="$(project_yaml_value "$metadata_file" domain)"
    current_database="$(project_yaml_value "$metadata_file" database)"
    current_redis="$(project_yaml_value "$metadata_file" redis)"
    current_node="$(project_yaml_value "$metadata_file" node)"
    current_php="$(project_yaml_value "$metadata_file" php)"
    current_port="$(project_yaml_value "$metadata_file" port)"
    project_dir="$PROJECTS_DIR/$rel_path"

    if [[ ! -d "$project_dir" ]]; then
        project_error "Project directory no longer exists: projects/$rel_path"
        project_info "Use project:remove if you only want to remove the stale registration."
        return 1
    fi

    printf 'Path: projects/%s\n' "$rel_path"
    printf 'Type: %s (not changed by edit)\n' "$type"

    read -r -p "Project name [$current_name]: " input
    name="${input:-$current_name}"
    if [[ ! "$name" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]]; then
        project_error "Project name may contain letters, numbers, dash and underscore only."
        return 1
    fi
    if project_name_exists "$name" "$metadata_file"; then
        project_error "Project name is already registered: $name"
        return 1
    fi

    read -r -p "Local domain [$current_domain]: " input
    domain="${input:-$current_domain}"
    domain="${domain#http://}"
    domain="${domain#https://}"
    domain="${domain%/}"

    if ! project_validate_domain "$domain"; then
        project_error "Invalid local domain: $domain"
        return 1
    fi
    if project_domain_exists "$domain" "$metadata_file"; then
        project_error "Domain is already registered: $domain"
        return 1
    fi

    old_nginx_file="$NGINX_CONF_DIR/$current_domain.conf"
    new_nginx_file="$NGINX_CONF_DIR/$domain.conf"
    if [[ "$new_nginx_file" != "$old_nginx_file" && -e "$new_nginx_file" ]]; then
        project_error "Nginx config already exists for domain: $domain"
        return 1
    fi

    project_database_choice "$current_database"
    database="$PROJECT_DATABASE"

    if profile_enabled redis; then
        if project_prompt_yes_no "Use Redis for this project?" "$( [[ "$current_redis" == "true" ]] && printf y || printf n )"; then
            redis_enabled=true
        fi
    elif [[ "$current_redis" == "true" ]]; then
        project_warn "Redis is no longer enabled in the Dockavel stack; this project will be set to redis=false."
    fi

    if [[ "$type" == "laravel" ]]; then
        project_enabled_php_services
        if [[ "${#PROJECT_PHP_SERVICES[@]}" -eq 0 ]]; then
            project_error "No PHP runtime is enabled. Run ./setup.sh first."
            return 1
        fi

        current_php_service="php${current_php/.}"
        default_php_index=0
        for ((index = 0; index < ${#PROJECT_PHP_SERVICES[@]}; index++)); do
            if [[ "${PROJECT_PHP_SERVICES[index]}" == "$current_php_service" ]]; then
                default_php_index="$index"
                break
            fi
        done

        project_choose_one_default "PHP runtime" "$default_php_index" "${PROJECT_PHP_LABELS[@]}"
        php_service="${PROJECT_PHP_SERVICES[PROJECT_CHOICE_INDEX]}"
        php_version="${php_service#php}"
        php_version="${php_version:0:1}.${php_version:1:1}"

        if ! project_runtime_running "$php_service"; then
            project_error "$php_service is enabled but not running. Start the selected Dockavel stack first."
            return 1
        fi

        if profile_enabled node; then
            if project_prompt_yes_no "Use the shared Node.js runtime for frontend commands?" "$( [[ "$current_node" == "true" ]] && printf y || printf n )"; then
                node_enabled=true
            fi
        elif [[ "$current_node" == "true" ]]; then
            project_warn "Node.js is no longer enabled in the Dockavel stack; this project will be set to node=false."
        fi
    else
        if ! profile_enabled node; then
            project_error "Node.js is not enabled. Run ./setup.sh and enable Node.js before editing this Node project."
            return 1
        fi
        if ! project_runtime_running node; then
            project_error "Node.js is enabled but not running. Start the selected Dockavel stack first."
            return 1
        fi

        while true; do
            read -r -p "Application port [$current_port]: " input
            node_port="${input:-$current_port}"
            if [[ "$node_port" =~ ^[0-9]+$ ]] && (( node_port >= 3000 && node_port <= 3099 )); then
                break
            fi
            printf 'Choose a port from 3000 to 3099.\n'
        done
        node_enabled=true
    fi

    metadata_tmp="$(mktemp)"
    nginx_tmp="$(mktemp)"
    metadata_backup="$(mktemp)"
    nginx_backup="$(mktemp)"

    project_write_metadata "$metadata_tmp" "$name" "$type" "$rel_path" "$domain" "$php_version" "$node_port" "$database" "$redis_enabled" "$node_enabled"
    if [[ "$type" == "laravel" ]]; then
        project_render_laravel_nginx "$nginx_tmp" "$domain" "$rel_path" "$php_service"
    else
        project_render_node_nginx "$nginx_tmp" "$domain" "$node_port"
    fi

    cp "$metadata_file" "$metadata_backup"
    if [[ -f "$old_nginx_file" ]]; then
        cp "$old_nginx_file" "$nginx_backup"
        old_nginx_exists=true
    fi

    mv "$metadata_tmp" "$metadata_file"
    if [[ "$new_nginx_file" != "$old_nginx_file" ]]; then
        rm -f "$old_nginx_file"
    fi
    mv "$nginx_tmp" "$new_nginx_file"

    if ! project_apply_nginx; then
        rm -f "$new_nginx_file"
        cp "$metadata_backup" "$metadata_file"
        if [[ "$old_nginx_exists" == "true" ]]; then
            cp "$nginx_backup" "$old_nginx_file"
        fi
        project_apply_nginx >/dev/null 2>&1 || true
        rm -f "$metadata_backup" "$nginx_backup"
        project_error "Project edit was rolled back."
        return 1
    fi

    rm -f "$metadata_backup" "$nginx_backup"

    printf '\nProject updated\n---------------\n'
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

    if [[ "$current_domain" != "$domain" ]]; then
        printf '\nUpdate your host machine hosts file:\n\n'
        printf 'Remove: 127.0.0.1 %s\n' "$current_domain"
        printf 'Add   : 127.0.0.1 %s\n' "$domain"
    else
        printf '\nHosts entry remains:\n\n127.0.0.1 %s\n' "$domain"
    fi
}

project_remove() {
    local requested="${1:-}" metadata_file name domain rel_path nginx_file
    local metadata_backup nginx_backup nginx_exists=false

    printf '\nRemove project registration\n---------------------------\n'
    project_select_metadata "$requested" || return 1
    metadata_file="$PROJECT_METADATA_FILE"

    name="$(project_yaml_value "$metadata_file" name)"
    domain="$(project_yaml_value "$metadata_file" domain)"
    rel_path="$(project_yaml_value "$metadata_file" path)"
    nginx_file="$NGINX_CONF_DIR/$domain.conf"

    printf 'Project : %s\n' "$name"
    printf 'Path    : projects/%s\n' "$rel_path"
    printf 'Domain  : %s\n' "$domain"
    printf '\nProject source files will NOT be deleted.\n'

    if ! project_prompt_yes_no "Remove this Dockavel registration?" n; then
        project_info "Cancelled. Nothing was changed."
        return 0
    fi

    metadata_backup="$(mktemp)"
    nginx_backup="$(mktemp)"
    cp "$metadata_file" "$metadata_backup"
    if [[ -f "$nginx_file" ]]; then
        cp "$nginx_file" "$nginx_backup"
        nginx_exists=true
    fi

    rm -f "$metadata_file" "$nginx_file"

    if ! project_apply_nginx; then
        cp "$metadata_backup" "$metadata_file"
        if [[ "$nginx_exists" == "true" ]]; then
            cp "$nginx_backup" "$nginx_file"
        fi
        project_apply_nginx >/dev/null 2>&1 || true
        rm -f "$metadata_backup" "$nginx_backup"
        project_error "Removal failed and the Dockavel registration was restored."
        return 1
    fi

    rm -f "$metadata_backup" "$nginx_backup"

    printf '\n%s Dockavel registration removed.\n' "$OK"
    printf '%s Project files kept: projects/%s\n' "$OK" "$rel_path"
    printf '\nRemove this hosts entry from your host machine if it exists:\n\n'
    printf '127.0.0.1 %s\n' "$domain"
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
