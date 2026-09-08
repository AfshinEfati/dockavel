ARG PHP_VERSION=8.5
ARG DOCKER_LIBRARY_PREFIX=
ARG GHCR_PREFIX=ghcr.io/

FROM ${GHCR_PREFIX}php/pie:bin AS pie
FROM ${DOCKER_LIBRARY_PREFIX}composer:2 AS composer
FROM ${DOCKER_LIBRARY_PREFIX}php:${PHP_VERSION}-fpm

# Use HTTP for the initial apt bootstrap. Slim base images may not contain a
# usable CA bundle yet; apt still verifies Debian repository signatures.
ARG DEBIAN_MIRROR=http://deb.debian.org/debian
ARG DEBIAN_SECURITY_MIRROR=http://deb.debian.org/debian-security
ARG COMPOSER_REPOSITORY=https://repo.packagist.org

ENV DEBIAN_FRONTEND=noninteractive \
    COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_HOME=/var/www/.composer \
    COMPOSER_CACHE_DIR=/var/www/.composer-cache \
    COMPOSER_PROCESS_TIMEOUT=600 \
    HOME=/var/www \
    PSYSH_CONFIG_DIR=/var/www/.psysh \
    XDG_CONFIG_HOME=/var/www/.config \
    XDG_DATA_HOME=/var/www/.local/share

WORKDIR /var/www

RUN set -eux; \
    if [ -f /etc/apt/sources.list ]; then \
        sed -i \
            -e "s|http://deb.debian.org/debian|${DEBIAN_MIRROR}|g" \
            -e "s|https://deb.debian.org/debian|${DEBIAN_MIRROR}|g" \
            -e "s|http://deb.debian.org/debian-security|${DEBIAN_SECURITY_MIRROR}|g" \
            -e "s|https://deb.debian.org/debian-security|${DEBIAN_SECURITY_MIRROR}|g" \
            -e "s|http://security.debian.org/debian-security|${DEBIAN_SECURITY_MIRROR}|g" \
            -e "s|https://security.debian.org/debian-security|${DEBIAN_SECURITY_MIRROR}|g" \
            /etc/apt/sources.list; \
    fi; \
    if [ -d /etc/apt/sources.list.d ]; then \
        find /etc/apt/sources.list.d -type f \
            \( -name "*.list" -o -name "*.sources" \) \
            -exec sed -i \
                -e "s|http://deb.debian.org/debian|${DEBIAN_MIRROR}|g" \
                -e "s|https://deb.debian.org/debian|${DEBIAN_MIRROR}|g" \
                -e "s|http://deb.debian.org/debian-security|${DEBIAN_SECURITY_MIRROR}|g" \
                -e "s|https://deb.debian.org/debian-security|${DEBIAN_SECURITY_MIRROR}|g" \
                -e "s|http://security.debian.org/debian-security|${DEBIAN_SECURITY_MIRROR}|g" \
                -e "s|https://security.debian.org/debian-security|${DEBIAN_SECURITY_MIRROR}|g" \
                {} +; \
    fi

RUN set -eux; \
    apt-get \
        -o Acquire::Retries=5 \
        -o Acquire::http::Timeout=60 \
        -o Acquire::https::Timeout=60 \
        update; \
    apt-get \
        -o Acquire::Retries=5 \
        -o Acquire::http::Timeout=60 \
        -o Acquire::https::Timeout=60 \
        install -y --no-install-recommends \
        autoconf \
        automake \
        ca-certificates \
        curl \
        g++ \
        gcc \
        git \
        gnupg \
        libexif-dev \
        libfreetype6-dev \
        libicu-dev \
        libjpeg-dev \
        libonig-dev \
        libpng-dev \
        libpq-dev \
        libssl-dev \
        libtool \
        libxml2-dev \
        libzip-dev \
        m4 \
        make \
        pkg-config \
        re2c \
        unzip \
        zip; \
    update-ca-certificates

RUN set -eux; \
    docker-php-ext-configure gd --with-freetype --with-jpeg; \
    docker-php-ext-configure intl; \
    docker-php-ext-install -j"$(nproc)" \
        exif \
        gd \
        intl \
        mbstring \
        pcntl \
        pdo_mysql \
        pdo_pgsql \
        zip

COPY --from=pie /pie /usr/local/bin/pie
COPY --from=composer /usr/bin/composer /usr/bin/composer

RUN set -eux; \
    chmod +x /usr/local/bin/pie; \
    pie repository:remove packagist.org || true; \
    pie repository:add composer "${COMPOSER_REPOSITORY}"; \
    pie install --no-cache "phpredis/phpredis:^6.3"; \
    php -m | grep -qx redis; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY docker/php/entrypoint.sh /usr/local/bin/dockavel-php-entrypoint
RUN chmod +x /usr/local/bin/dockavel-php-entrypoint

ENTRYPOINT ["dockavel-php-entrypoint"]
CMD ["php-fpm"]
