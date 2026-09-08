ARG PHP_VERSION=8.5

FROM php:${PHP_VERSION}-fpm

ARG UID=1000
ARG GID=1000
ARG DEBIAN_MIRROR=http://deb.debian.org/debian
ARG DEBIAN_SECURITY_MIRROR=http://deb.debian.org/debian-security
ARG COMPOSER_REPOSITORY=https://repo.packagist.org

ENV DEBIAN_FRONTEND=noninteractive \
    COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_HOME=/opt/composer \
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
    update-ca-certificates; \
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
        zip; \
    printf '\n\n\n\n\n\n' | pecl install redis; \
    docker-php-ext-enable redis; \
    php -m | grep -qx redis; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

RUN set -eux; \
    if ! getent group "${GID}" >/dev/null 2>&1; then \
        groupadd --gid "${GID}" app; \
    fi; \
    if ! getent passwd "${UID}" >/dev/null 2>&1; then \
        useradd \
            --uid "${UID}" \
            --gid "${GID}" \
            --home-dir /var/www \
            --shell /bin/bash \
            app; \
    fi; \
    mkdir -p \
        /opt/composer \
        /var/www/.composer-cache \
        /var/www/.config/psysh \
        /var/www/.local/share \
        /var/www/.psysh; \
    composer config --global repos.packagist composer "${COMPOSER_REPOSITORY}"; \
    chown -R "${UID}:${GID}" \
        /opt/composer \
        /var/www/.composer-cache \
        /var/www/.config \
        /var/www/.local \
        /var/www/.psysh
