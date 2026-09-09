#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE="$REPO_ROOT/projects/.dockavel-detection-test"
trap 'rm -rf "$FIXTURE" "$REPO_ROOT/.env"' EXIT

mkdir -p "$FIXTURE"
cp "$REPO_ROOT/.env.example" "$REPO_ROOT/.env"
touch "$FIXTURE/artisan"
cat > "$FIXTURE/composer.json" <<'JSON'
{
  "require": {
    "php": "^8.5",
    "laravel/framework": "^12.0"
  }
}
JSON
cat > "$FIXTURE/package.json" <<'JSON'
{"scripts":{"dev":"vite"}}
JSON
touch "$FIXTURE/package-lock.json"
cat > "$FIXTURE/.env" <<'ENV'
DB_CONNECTION=pgsql
DB_DATABASE=detection_test
CACHE_STORE=redis
ENV

output="$(cd "$REPO_ROOT" && ./dockavel project:detect .dockavel-detection-test 2>&1)"

for expected in \
    'Type                     ℹ️  laravel' \
    'PHP requirement          ℹ️  ^8.5' \
    'Suggested PHP            ✅ 8.5' \
    'Package manager          ℹ️  npm' \
    'Database hint            ℹ️  postgres' \
    'Redis hint               ℹ️  yes'; do
    if ! grep -Fq "$expected" <<< "$output"; then
        printf 'Missing detection output: %s\n\n%s\n' "$expected" "$output" >&2
        exit 1
    fi
done

printf 'Smart project detection tests passed.\n'
