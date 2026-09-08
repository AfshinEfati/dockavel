ARG PHP_VERSION=8.5
ARG DOCKER_NAMESPACE_PREFIX=docker.io/

FROM ${DOCKER_NAMESPACE_PREFIX}serversideup/php:${PHP_VERSION}-fpm

ARG UID=1000
ARG GID=1000
ARG DEBIAN_MIRROR=https://deb.debian.org/debian
ARG DEBIAN_SECURITY_MIRROR=https://deb.debian.org/debian-security
ARG COMPOSER_REPOSITORY=https://repo.packagist.org

ENV COMPOSER_HOME=/opt/dockavel/composer \
    COMPOSER_CACHE_DIR=/var/cache/composer \
    COMPOSER_PROCESS_TIMEOUT=600 \
    HOME=/var/www \
    PSYSH_CONFIG_DIR=/var/www/.psysh \
    XDG_CONFIG_HOME=/var/www/.config \
    XDG_DATA_HOME=/var/www/.local/share

USER root

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
    docker-php-serversideup-set-id www-data "${UID}:${GID}"; \
    mkdir -p \
        /opt/dockavel/composer \
        /var/cache/composer \
        /var/www/.psysh \
        /var/www/.config \
        /var/www/.local/share; \
    COMPOSER_HOME=/opt/dockavel/composer composer config --global repo.packagist composer "${COMPOSER_REPOSITORY}"; \
    chown -R "${UID}:${GID}" \
        /opt/dockavel \
        /var/cache/composer \
        /var/www/.psysh \
        /var/www/.config \
        /var/www/.local

USER www-data
WORKDIR /var/www
