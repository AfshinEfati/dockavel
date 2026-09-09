#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
LOG_FILE="$TEST_ROOT/docker.log"
trap 'rm -rf "$TEST_ROOT"' EXIT

mkdir -p "$TEST_ROOT/lib" "$TEST_ROOT/projects/api" "$TEST_ROOT/bin" "$TEST_ROOT/nginx/conf.d"
cp "$REPO_ROOT/dockavel" "$TEST_ROOT/dockavel"
cp "$REPO_ROOT/docker-compose.yml" "$TEST_ROOT/docker-compose.yml"
cp "$REPO_ROOT/.env.example" "$TEST_ROOT/.env.example"
cp "$REPO_ROOT/VERSION" "$TEST_ROOT/VERSION"
cp "$REPO_ROOT/lib/"*.sh "$TEST_ROOT/lib/"
chmod +x "$TEST_ROOT/dockavel"

cat > "$TEST_ROOT/.env" <<'ENV'
COMPOSE_PROFILES=mysql
ENV
cat > "$TEST_ROOT/projects/api/.dockavel.yml" <<'YAML'
version: 1
name: "api"
type: "laravel"
path: "api"
domain: "api.local"
php: "8.5"
database: "mysql"
redis: false
node: false
YAML
cat > "$TEST_ROOT/projects/api/.env" <<'ENV'
DB_CONNECTION=mysql
DB_DATABASE=api_test
ENV

cat > "$TEST_ROOT/bin/docker" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "compose" ]]; then
    shift
    if [[ "${1:-}" == "-f" ]]; then shift 2; fi
    case "${1:-}" in
        ps)
            printf 'fake-%s\n' "${3:-service}"
            exit 0
            ;;
        exec)
            args="$*"
            if [[ "$args" == *"INFORMATION_SCHEMA.SCHEMATA"* ]]; then
                printf 'api_test\n'
                exit 0
            fi
            if [[ "$args" == *"mysqldump"* ]]; then
                printf '%s\n' '-- dockavel test dump'
                exit 0
            fi
            printf '%s\n' "$args" >> "$DOCKAVEL_TEST_LOG"
            cat >/dev/null || true
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
    (cd "$TEST_ROOT" && DOCKAVEL_TEST_LOG="$LOG_FILE" PATH="$TEST_ROOT/bin:$PATH" ./dockavel "$@")
}

status_output="$(run_cli db:status api)"
if ! grep -Fq 'api_test' <<< "$status_output"; then
    printf 'Database status did not include the configured database name.\n%s\n' "$status_output" >&2
    exit 1
fi

run_cli db:export api "$TEST_ROOT/backup.sql" >/dev/null
grep -Fq -- '-- dockavel test dump' "$TEST_ROOT/backup.sql"

if run_cli db:export api "$TEST_ROOT/backup.sql" >/dev/null 2>&1; then
    printf 'Expected export to refuse overwriting an existing file.\n' >&2
    exit 1
fi

printf 'y\n' | run_cli db:import api "$TEST_ROOT/backup.sql" >/dev/null
if ! grep -Fq 'mysql -uroot "$1"' "$LOG_FILE"; then
    printf 'Expected MySQL import invocation was not routed.\n' >&2
    cat "$LOG_FILE" >&2
    exit 1
fi

printf 'Database helper tests passed.\n'
