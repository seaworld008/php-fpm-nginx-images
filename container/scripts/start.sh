#!/bin/bash
# Container startup script
# Compatible with legacy wyveo/nginx-php-fpm image behavior

set -e

echo "==================================="
echo "PHP 7.2.34 + Nginx Container"
echo "Security Patched: CVE-2026-109618, CVE-2026-109619"
echo "==================================="
echo ""

# Display versions
echo "PHP Version:"
php -v | head -1
echo ""

echo "Nginx Version:"
nginx -v 2>&1
echo ""

echo "PHP Extensions:"
php -m | grep -E '(redis|memcached|mongodb|swoole|igbinary|opcache)' || true
echo ""

# Create required directories if not exists
mkdir -p /run/php /usr/share/nginx/logs /usr/share/nginx/html/runtime

# Set timezone
if [ -n "$TZ" ]; then
    echo "Setting timezone to: $TZ"
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime
    echo $TZ > /etc/timezone
fi

# Validate PHP-FPM configuration
echo "Validating PHP-FPM configuration..."
if ! php-fpm7.2 -t 2>&1; then
    echo "ERROR: PHP-FPM configuration test failed"
    exit 1
fi

# Validate Nginx configuration
echo "Validating Nginx configuration..."
if ! nginx -t 2>&1; then
    echo "ERROR: Nginx configuration test failed"
    exit 1
fi

echo ""
echo "Starting services with Supervisor..."
echo "==================================="

# Start supervisor
exec /usr/local/bin/supervisord -c /etc/supervisord.conf
