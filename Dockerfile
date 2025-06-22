FROM php:8.2-apache

# Install required PHP extensions
RUN docker-php-ext-install pdo_mysql
# OpenSSL is built into the base image; ensure it is enabled
# RUN docker-php-ext-enable openssl

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

COPY . /var/www/html/
# Set correct permissions for runtime and assets folders
RUN mkdir -p /var/www/html/protected/runtime /var/www/html/assets \
    && chown -R www-data:www-data /var/www/html/protected/runtime /var/www/html/assets \
    && chmod -R 775 /var/www/html/protected/runtime /var/www/html/assets \
    && ls -ld /var/www/html/protected /var/www/html/protected/runtime /var/www/html/assets

EXPOSE 80
CMD ["apache2-foreground"]
