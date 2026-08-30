ARG PHP_VERSION=8.3
ARG NODE_VERSION=22

FROM node:${NODE_VERSION}-bookworm-slim AS node
FROM php:${PHP_VERSION}-fpm-bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    unzip \
    zip \
    libzip-dev \
    libonig-dev \
    libxml2-dev \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libicu-dev \
    pkg-config \
    libssl-dev \
    autoconf \
    make \
    gcc \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j"$(nproc)" zip pdo_mysql mbstring pcntl gd bcmath intl \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer
COPY --from=node /usr/local/ /usr/local/

RUN corepack enable \
    && npm install --global pm2

ENV COMPOSER_CACHE_DIR=/var/www/.composer-cache

WORKDIR /var/www
