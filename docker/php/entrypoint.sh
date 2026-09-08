#!/usr/bin/env sh
set -eu

if [ -n "${COMPOSER_REPOSITORY:-}" ]; then
    mkdir -p "${COMPOSER_HOME:-/var/www/.composer}"

    if ! composer config --global repo.packagist composer "$COMPOSER_REPOSITORY" >/dev/null 2>&1; then
        echo "Warning: could not configure Composer repository: $COMPOSER_REPOSITORY" >&2
    fi
fi

exec docker-php-entrypoint "$@"
