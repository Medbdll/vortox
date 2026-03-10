#!/bin/sh

set -e

cd /var/www

# Wait for database to be ready
echo "Waiting for database..."
while ! php artisan migrate:status > /dev/null 2>&1; do
    echo "Database not ready, waiting..."
    sleep 2
done

# Run migrations and seeds
php artisan migrate --force
php artisan db:seed --force

# Fix storage permissions for production
echo "Setting up storage permissions..."
sudo chown -R www-data:www-data storage bootstrap/cache
sudo chmod -R 775 storage bootstrap/cache
sudo chmod -R 777 storage/logs

# Ensure log file exists with proper permissions
echo "Setting up log file..."
sudo touch storage/logs/laravel.log || true
sudo chown www-data:www-data storage/logs/laravel.log || true
sudo chmod 666 storage/logs/laravel.log || true

# Create additional log files for different channels
sudo touch storage/logs/laravel-$(date +%Y-%m-%d).log || true
sudo chmod 666 storage/logs/laravel-$(date +%Y-%m-%d).log || true

# Create additional required directories
mkdir -p storage/app/public storage/framework/cache storage/framework/sessions storage/framework/views
sudo chown -R www-data:www-data storage/app/public storage/framework/cache storage/framework/sessions storage/framework/views

# Install and build assets for production
echo "Building assets..."
npm install
npm run build

# Clear caches and optimize for production
echo "Optimizing application..."
php artisan optimize:clear || echo "Warning: optimize:clear failed"
php artisan config:cache || echo "Warning: config:cache failed"
php artisan route:cache || echo "Warning: route:cache failed"
php artisan view:cache || echo "Warning: view:cache failed"

# Set environment to production
export APP_ENV=production
export APP_DEBUG=false

echo "Starting application server..."
php-fpm
apache2-foreground