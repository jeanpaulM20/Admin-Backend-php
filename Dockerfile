FROM php:8.2-apache

# Install required PHP extensions
RUN docker-php-ext-install pdo_mysql
# OpenSSL is built into the base image; ensure it is enabled
# RUN docker-php-ext-enable openssl

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

COPY . /var/www/html/

EXPOSE 80
CMD ["apache2-foreground"]
