FROM php:8.2-fpm

ARG UID=1000
ARG GID=1000

# نصب پکیج‌های مورد نیاز به همراه libwebp-dev برای WebP
RUN apt-get update && apt-get install -y \
    curl git unzip zip gnupg2 libzip-dev libonig-dev libxml2-dev \
    libpng-dev libjpeg-dev libfreetype6-dev libwebp-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install zip pdo_mysql mbstring pcntl gd \
    && pecl install redis && docker-php-ext-enable redis

# نصب Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

ENV COMPOSER_CACHE_DIR=/var/www/.composer-cache
RUN mkdir -p /var/www/.composer-cache && chown -R ${UID}:${GID} /var/www/.composer-cache

# نصب NVM + Node.js + PNPM + PM2
ENV NVM_DIR=/root/.nvm
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash && \
    bash -c ". $NVM_DIR/nvm.sh && nvm install node && npm install -g pnpm pm2"

WORKDIR /var/www
