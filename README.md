# Admin Backend PHP

This project contains the source code of the admin backend built with the Yii PHP framework.

## Requirements

- **PHP 8.2** or newer
- PHP extensions: `pdo`, `pdo_mysql`, and `openssl`
- A MySQL database
- Composer (optional if you want to manage dependencies)

After migrating from `mcrypt`, the application relies on the OpenSSL extension for encryption and decryption. Ensure the `openssl` extension is installed and enabled in your PHP environment.

## Installation

1. Clone this repository:
   ```bash
   git clone <repository-url>
   cd Admin-Backend-php
   ```
2. Install PHP 8.2 and required extensions. For example on Debian/Ubuntu:
   ```bash
   sudo apt-get install php8.2 php8.2-mysql php8.2-openssl
   ```
3. Configure database credentials in `protected/config/main.php`.
4. (Optional) Install Composer and run `composer install` if using the provided `composer.json`.
5. Serve the application using your web server of choice. The entry point is `index.php` in the project root.

## Docker

A `Dockerfile` is included for convenience. Build and run the container with:
```bash
docker build -t admin-backend-php .
docker run -p 8080:80 admin-backend-php
```
The container is based on PHP 8.2 and enables the necessary extensions.

