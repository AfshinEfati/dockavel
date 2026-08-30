ARG PIE_IMAGE=ghcr.io/php/pie:bin
FROM ${PIE_IMAGE} AS pie

FROM php:8.2-fpm

ARG UID=1000
ARG GID=1000
ARG DEBIAN_MIRROR=http://deb.debian.org/debian
ARG DEBIAN_SECURITY_MIRROR=http://deb.debian.org/debian-security
ARG COMPOSER_REPOSITORY=https://repo.packagist.org

ENV DEBIAN_FRONTEND=noninteractive \
    COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_HOME=/opt/composer \
    COMPOSER_CACHE_DIR=/var/www/.composer-cache \
    COMPOSER_PROCESS_TIMEOUT=600

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
    fi; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        autoconf \
        automake \
        ca-certificates \
        curl \
        g++ \
        gcc \
        git \
        gnupg2 \
        libfreetype6-dev \
        libjpeg-dev \
        libonig-dev \
        libpng-dev \
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
    update-ca-certificates; \
    docker-php-ext-configure gd --with-freetype --with-jpeg; \
    docker-php-ext-install -j"$(nproc)" \
        gd \
        mbstring \
        pcntl \
        pdo_mysql \
        zip; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY --from=pie /pie /usr/local/bin/pie
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

RUN set -eux; \
    chmod +x /usr/local/bin/pie; \
    pie repository:remove packagist.org || true; \
    pie repository:add composer "${COMPOSER_REPOSITORY}"; \
    pie install --no-cache "phpredis/phpredis:^6.3"; \
    php -m | grep -qx redis; \
    mkdir -p \
        /opt/composer \
        /var/www/.composer-cache; \
    composer config --global repos.packagist composer "${COMPOSER_REPOSITORY}"; \
    chown -R "${UID}:${GID}" \
        /opt/composer \
        /var/www/.composer-cache

WORKDIR /var/www