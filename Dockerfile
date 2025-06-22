FROM php:8.2-apache

# Install system dependencies and PHP extensions
RUN apt-get update && apt-get install -y \
    libzip-dev zip unzip \
    && docker-php-ext-install pdo_mysql

# Enable Apache mod_rewrite
RUN a2enmod rewrite

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Copy application code
COPY . /var/www/html/

# Set correct permissions for runtime and assets folders
RUN mkdir -p /var/www/html/protected/runtime /var/www/html/assets \
    && chown -R www-data:www-data /var/www/html/protected/runtime /var/www/html/assets \
    && chmod -R 775 /var/www/html/protected/runtime /var/www/html/assets

# (Optional) Run Composer install if you have composer.json
# RUN cd /var/www/html && composer install --no-dev --optimize-autoloader

EXPOSE 80
CMD ["apache2-foreground"]