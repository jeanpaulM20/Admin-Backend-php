FROM php:8.3-apache

# Install system dependencies and PHP extensions
RUN apt-get update && apt-get install -y \
    libzip-dev zip unzip \
    && docker-php-ext-install pdo_mysql

# Enable Apache mod_rewrite
RUN a2enmod rewrite

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Copy composer files and install dependencies first for better caching
COPY composer.json composer.lock /var/www/html/
RUN cd /var/www/html && composer install --no-dev --optimize-autoloader

# Now copy the rest of the application code
COPY . /var/www/html/

# Set correct permissions for runtime and assets folders
RUN mkdir -p /var/www/html/protected/runtime /var/www/html/assets \
    && chown -R www-data:www-data /var/www/html/protected/runtime /var/www/html/assets \
    && chmod -R 775 /var/www/html/protected/runtime /var/www/html/assets

EXPOSE 80
CMD ["apache2-foreground"]
