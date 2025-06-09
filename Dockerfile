FROM php:8.2-fpm

# پارامترهای کاربر
ARG UID=1000
ARG GID=1000

# نصب ابزارها و اکستنشن‌ها
RUN apt-get update && apt-get install -y \
    curl git unzip zip gnupg2 libzip-dev libonig-dev libxml2-dev libpng-dev libjpeg-dev libfreetype6-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install zip pdo_mysql mbstring pcntl gd

# نصب Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# تنظیمات Composer cache
ENV COMPOSER_CACHE_DIR=/var/www/.composer-cache
RUN mkdir -p /var/www/.composer-cache && chown -R ${UID}:${GID} /var/www/.composer-cache

# نصب nvm, node, pnpm, pm2
ENV NVM_DIR=/root/.nvm
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash && \
    bash -c ". $NVM_DIR/nvm.sh && nvm install node && npm install -g pnpm pm2"

# مسیر کاری
WORKDIR /var/www
