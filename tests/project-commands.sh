#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
LOG_FILE="$TEST_ROOT/docker.log"
trap 'rm -rf "$TEST_ROOT"' EXIT

mkdir -p "$TEST_ROOT/lib" "$TEST_ROOT/projects/api" "$TEST_ROOT/projects/frontend" "$TEST_ROOT/bin"
cp "$REPO_ROOT/dockavel" "$TEST_ROOT/dockavel"
cp "$REPO_ROOT/docker-compose.yml" "$TEST_ROOT/docker-compose.yml"
cp "$REPO_ROOT/.env.example" "$TEST_ROOT/.env.example"
cp "$REPO_ROOT/VERSION" "$TEST_ROOT/VERSION"
cp "$REPO_ROOT/lib/"*.sh "$TEST_ROOT/lib/"
chmod +x "$TEST_ROOT/dockavel"

cat > "$TEST_ROOT/.env" <<'ENV'
COMPOSE_PROFILES=php85,node
ENV

cat > "$TEST_ROOT/projects/api/.dockavel.yml" <<'YAML'
version: 1
name: "api"
type: "laravel"
path: "api"
domain: "api.local"
php: "8.5"
database: "none"
redis: false
node: true
YAML

touch "$TEST_ROOT/projects/api/artisan"
printf '{}\n' > "$TEST_ROOT/projects/api/composer.json"
printf '{}\n' > "$TEST_ROOT/projects/api/package.json"

cat > "$TEST_ROOT/projects/frontend/.dockavel.yml" <<'YAML'
version: 1
name: "frontend"
type: "node"
path: "frontend"
domain: "frontend.local"
port: 3000
database: "none"
redis: false
node: true
YAML
printf '{}\n' > "$TEST_ROOT/projects/frontend/package.json"

cat > "$TEST_ROOT/bin/docker" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "compose" ]]; then
    shift
    if [[ "${1:-}" == "-f" ]]; then
        shift 2
    fi

    case "${1:-}" in
        ps)
            service="${3:-}"
            printf 'fake-%s\n' "$service"
            exit 0
            ;;
        exec)
            if [[ "$*" == *" test -d "* ]]; then
                exit 0
            fi
            printf '%s\n' "$*" >> "$DOCKAVEL_TEST_LOG"
            exit 0
            ;;
    esac
fi

if [[ "${1:-}" == "inspect" ]]; then
    printf 'true\n'
    exit 0
fi

printf 'unexpected docker call: %s\n' "$*" >&2
exit 1
MOCK
chmod +x "$TEST_ROOT/bin/docker"

run_cli() {
    (
        cd "$TEST_ROOT"
        DOCKAVEL_TEST_LOG="$LOG_FILE" PATH="$TEST_ROOT/bin:$PATH" ./dockavel "$@"
    )
}

assert_log() {
    local expected="$1"
    if ! grep -Fq -- "$expected" "$LOG_FILE"; then
        printf 'Expected Docker invocation not found:\n%s\n\nActual log:\n' "$expected" >&2
        cat "$LOG_FILE" >&2
        exit 1
    fi
}

: > "$LOG_FILE"
run_cli artisan api migrate --force
assert_log "exec -w /var/www/api php85 php artisan migrate --force"

: > "$LOG_FILE"
run_cli composer api install --no-interaction
assert_log "exec -w /var/www/api php85 composer install --no-interaction"

: > "$LOG_FILE"
run_cli npm api install
assert_log "exec -w /var/www/api node npm install"

: > "$LOG_FILE"
run_cli shell api
assert_log "exec -w /var/www/api php85 bash"

: > "$LOG_FILE"
run_cli npm frontend run dev
assert_log "exec -w /var/www/frontend node npm run dev"

: > "$LOG_FILE"
run_cli shell frontend
assert_log "exec -w /var/www/frontend node bash"

if run_cli artisan frontend migrate >/dev/null 2>&1; then
    printf 'Expected Artisan on a Node project to fail.\n' >&2
    exit 1
fi

printf 'Project command routing tests passed.\n'
