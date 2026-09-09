#!/usr/bin/env bash

project_health_row() {
    local label="$1" state="$2" detail="${3:-}"
    case "$state" in
        ok) print_row "$label" "$OK" "$detail" ;;
        warn) print_row "$label" "$WARN" "$detail" ;;
        fail) print_row "$label" "$FAIL" "$detail" ;;
        *) print_row "$label" "$INFO" "$detail" ;;
    esac
}

project_health_service_state() {
    local service="$1" profile="$2"
    if ! profile_enabled "$profile"; then
        PROJECT_HEALTH_SERVICE_STATE="fail"
        PROJECT_HEALTH_SERVICE_DETAIL="not enabled"
    elif project_runtime_running "$service"; then
        PROJECT_HEALTH_SERVICE_STATE="ok"
        PROJECT_HEALTH_SERVICE_DETAIL="running"
    else
        PROJECT_HEALTH_SERVICE_STATE="fail"
        PROJECT_HEALTH_SERVICE_DETAIL="enabled but not running"
    fi
}

project_check() {
    local requested="${1:-}" metadata_file name type rel_path domain php database redis node nginx_file service
    local failures=0 warnings=0

    if [[ -z "$requested" ]]; then
        project_error "Project name is required. Usage: dockavel project:check <project>"
        return 2
    fi

    project_select_metadata "$requested" || return 1
    metadata_file="$PROJECT_METADATA_FILE"
    name="$(project_yaml_value "$metadata_file" name)"
    type="$(project_yaml_value "$metadata_file" type)"
    rel_path="$(project_yaml_value "$metadata_file" path)"
    domain="$(project_yaml_value "$metadata_file" domain)"
    php="$(project_yaml_value "$metadata_file" php)"
    database="$(project_yaml_value "$metadata_file" database)"
    redis="$(project_yaml_value "$metadata_file" redis)"
    node="$(project_yaml_value "$metadata_file" node)"
    nginx_file="$NGINX_CONF_DIR/$domain.conf"

    printf '\nProject health: %s\n' "$name"
    printf '%*s\n' "$((16 + ${#name}))" '' | tr ' ' '-'

    if [[ -f "$metadata_file" && -n "$name" && -n "$type" && -n "$rel_path" && -n "$domain" ]]; then
        project_health_row "Metadata" ok "valid core fields"
    else
        project_health_row "Metadata" fail "missing required fields"
        failures=$((failures + 1))
    fi

    if [[ -d "$PROJECTS_DIR/$rel_path" ]]; then
        project_health_row "Host path" ok "projects/$rel_path"
    else
        project_health_row "Host path" fail "projects/$rel_path missing"
        failures=$((failures + 1))
    fi

    case "$type" in
        laravel)
            if [[ -f "$PROJECTS_DIR/$rel_path/artisan" && -f "$PROJECTS_DIR/$rel_path/composer.json" ]]; then
                project_health_row "Project type" ok "Laravel markers found"
            else
                project_health_row "Project type" warn "Laravel metadata but artisan/composer.json incomplete"
                warnings=$((warnings + 1))
            fi
            service="$(project_command_php_service "$php" 2>/dev/null || true)"
            if [[ -n "$service" ]]; then
                project_health_service_state "$service" "$service"
                project_health_row "PHP runtime" "$PROJECT_HEALTH_SERVICE_STATE" "$service · $PROJECT_HEALTH_SERVICE_DETAIL"
                [[ "$PROJECT_HEALTH_SERVICE_STATE" == "fail" ]] && failures=$((failures + 1))
                if [[ "$PROJECT_HEALTH_SERVICE_STATE" == "ok" ]]; then
                    if docker compose -f "$ROOT_DIR/docker-compose.yml" exec -T "$service" test -d "/var/www/$rel_path" >/dev/null 2>&1; then
                        project_health_row "Runtime mount" ok "/var/www/$rel_path visible"
                    else
                        project_health_row "Runtime mount" fail "project not visible in $service"
                        failures=$((failures + 1))
                    fi
                fi
            else
                project_health_row "PHP runtime" fail "unsupported metadata version: ${php:-missing}"
                failures=$((failures + 1))
            fi
            ;;
        node)
            if [[ -f "$PROJECTS_DIR/$rel_path/package.json" ]]; then
                project_health_row "Project type" ok "Node package.json found"
            else
                project_health_row "Project type" warn "Node metadata but package.json missing"
                warnings=$((warnings + 1))
            fi
            project_health_service_state node node
            project_health_row "Node runtime" "$PROJECT_HEALTH_SERVICE_STATE" "$PROJECT_HEALTH_SERVICE_DETAIL"
            [[ "$PROJECT_HEALTH_SERVICE_STATE" == "fail" ]] && failures=$((failures + 1))
            ;;
        *)
            project_health_row "Project type" fail "unsupported type: ${type:-missing}"
            failures=$((failures + 1))
            ;;
    esac

    if [[ -f "$nginx_file" ]]; then
        if grep -Fq "server_name $domain;" "$nginx_file" 2>/dev/null; then
            project_health_row "Nginx config" ok "nginx/conf.d/$domain.conf"
        else
            project_health_row "Nginx config" warn "file exists but server_name does not match"
            warnings=$((warnings + 1))
        fi
    else
        project_health_row "Nginx config" fail "missing nginx/conf.d/$domain.conf"
        failures=$((failures + 1))
    fi

    if project_nginx_running; then
        if docker compose -f "$ROOT_DIR/docker-compose.yml" exec -T nginx nginx -t >/dev/null 2>&1; then
            project_health_row "Nginx validation" ok "configuration valid"
        else
            project_health_row "Nginx validation" fail "nginx -t failed"
            failures=$((failures + 1))
        fi
    else
        project_health_row "Nginx validation" warn "nginx is not running"
        warnings=$((warnings + 1))
    fi

    if [[ "$database" == "mysql" || "$database" == "postgres" ]]; then
        if project_db_prepare "$name" >/dev/null 2>&1; then
            if project_db_exists; then
                project_health_row "Database" ok "$database · $PROJECT_DB_NAME exists"
            else
                project_health_row "Database" warn "$database · $PROJECT_DB_NAME does not exist"
                warnings=$((warnings + 1))
            fi
        else
            project_health_row "Database" warn "$database configured but helper validation failed"
            warnings=$((warnings + 1))
        fi
    else
        project_health_row "Database" info "none"
    fi

    if [[ "$redis" == "true" ]]; then
        project_health_service_state redis redis
        project_health_row "Redis" "$PROJECT_HEALTH_SERVICE_STATE" "$PROJECT_HEALTH_SERVICE_DETAIL"
        [[ "$PROJECT_HEALTH_SERVICE_STATE" == "fail" ]] && warnings=$((warnings + 1))
    else
        project_health_row "Redis" info "not used by metadata"
    fi

    if [[ "$node" == "true" && "$type" != "node" ]]; then
        project_health_service_state node node
        project_health_row "Frontend Node" "$PROJECT_HEALTH_SERVICE_STATE" "$PROJECT_HEALTH_SERVICE_DETAIL"
        [[ "$PROJECT_HEALTH_SERVICE_STATE" == "fail" ]] && warnings=$((warnings + 1))
    fi

    printf '\nHealth summary\n--------------\n'
    if [[ "$failures" -eq 0 && "$warnings" -eq 0 ]]; then
        printf '%s Project is healthy.\n' "$OK"
    elif [[ "$failures" -eq 0 ]]; then
        printf '%s %d warning(s), no hard failures.\n' "$WARN" "$warnings"
    else
        printf '%s %d failure(s), %d warning(s).\n' "$FAIL" "$failures" "$warnings"
        return 1
    fi
}

doctor_project_checks() {
    local metadata rel_path registered=0 stale=0

    printf '\nProjects\n--------\n'
    while IFS= read -r -d '' metadata; do
        registered=$((registered + 1))
        rel_path="$(project_yaml_value "$metadata" path)"
        [[ -d "$PROJECTS_DIR/$rel_path" ]] || stale=$((stale + 1))
    done < <(find "$PROJECTS_DIR" -type f -name .dockavel.yml -print0 2>/dev/null)

    if [[ "$registered" -eq 0 ]]; then
        print_row "Registered projects" "$INFO" "none"
    else
        print_row "Registered projects" "$OK" "$registered"
        if [[ "$stale" -eq 0 ]]; then
            print_row "Stale registrations" "$OK" "none"
        else
            print_row "Stale registrations" "$WARN" "$stale project path(s) missing"
        fi
    fi

    if env | grep -qiE '^(HTTP|HTTPS|ALL)_PROXY='; then
        print_row "Proxy environment" "$WARN" "proxy variables are set in this shell"
    else
        print_row "Proxy environment" "$OK" "no HTTP/HTTPS/ALL proxy variables"
    fi

    if [[ -f "$HOME/.docker/config.json" ]] && grep -q '"proxies"[[:space:]]*:' "$HOME/.docker/config.json" 2>/dev/null; then
        print_row "Docker client proxy" "$WARN" "proxies block found in ~/.docker/config.json"
    else
        print_row "Docker client proxy" "$INFO" "no client proxies block detected"
    fi
}
