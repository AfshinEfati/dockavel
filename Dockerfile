FROM php:8.2-fpm

# نصب ابزارهای لازم
RUN apt-get update && apt-get install -y \
    curl git unzip zip gnupg2 libzip-dev libonig-dev libxml2-dev \
    && docker-php-ext-install zip pdo_mysql mbstring

# نصب Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# نصب nvm, node, pnpm, pm2
ENV NVM_DIR=/root/.nvm
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash && \
    bash -c ". $NVM_DIR/nvm.sh && nvm install node && npm install -g pnpm pm2"
RUN docker-php-ext-install pcntl
# تنظیمات محیط
WORKDIR /var/www
ENV COMPOSER_CACHE_DIR=/tmp/composer-cache
