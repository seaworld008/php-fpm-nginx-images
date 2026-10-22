#!/bin/bash
# Container entrypoint for PHP-FPM + Nginx
# Handles initialization, configuration rendering, process management, and graceful shutdown

set -e
set -o pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Trap signals for graceful shutdown
GRACEFUL_SHUTDOWN=0
FPM_PID=""
NGINX_PID=""

handle_signal() {
    local signal=$1
    log_info "Received signal: $signal"

    if [ "$GRACEFUL_SHUTDOWN" -eq 1 ]; then
        log_warn "Already shutting down, ignoring signal"
        return
    fi

    GRACEFUL_SHUTDOWN=1

    # Set draining flag
    touch /run/app/draining
    log_info "Marked as draining, waiting 5 seconds for load balancer updates..."
    sleep 5

    # Gracefully stop Nginx first (QUIT = graceful)
    if [ -n "$NGINX_PID" ] && kill -0 "$NGINX_PID" 2>/dev/null; then
        log_info "Sending QUIT signal to Nginx (PID: $NGINX_PID)"
        kill -QUIT "$NGINX_PID" || true

        # Wait for Nginx to finish, with timeout
        local count=0
        while kill -0 "$NGINX_PID" 2>/dev/null && [ $count -lt 75 ]; do
            sleep 1
            count=$((count + 1))
        done

        if kill -0 "$NGINX_PID" 2>/dev/null; then
            log_warn "Nginx did not stop gracefully, sending TERM"
            kill -TERM "$NGINX_PID" || true
            sleep 2
        fi
    fi

    # Stop PHP-FPM
    if [ -n "$FPM_PID" ] && kill -0 "$FPM_PID" 2>/dev/null; then
        log_info "Sending QUIT signal to PHP-FPM (PID: $FPM_PID)"
        kill -QUIT "$FPM_PID" || true

        # Wait for FPM to finish, with timeout
        local count=0
        while kill -0 "$FPM_PID" 2>/dev/null && [ $count -lt 20 ]; then
            sleep 1
            count=$((count + 1))
        done

        if kill -0 "$FPM_PID" 2>/dev/null; then
            log_warn "PHP-FPM did not stop gracefully, sending TERM"
            kill -TERM "$FPM_PID" || true
            sleep 2
        fi
    fi

    log_info "Shutdown complete"
    exit 0
}

trap 'handle_signal SIGTERM' SIGTERM
trap 'handle_signal SIGINT' SIGINT
trap 'handle_signal SIGQUIT' SIGQUIT

# Check if running as CLI command (exec mode)
if [ "$1" = "php" ] || [ "$1" = "composer" ] || [ "$1" = "bash" ] || [ "$1" = "sh" ]; then
    log_info "Running in CLI mode: $*"
    exec "$@"
fi

# Main initialization
log_info "=== PHP 7.2.34 + Nginx Container Starting ==="
log_info "Image: jwxt-nginx-php72"
log_info "PHP Version: $(php -v | head -1)"
log_info "Nginx Version: $(nginx -v 2>&1)"

# Create required runtime directories
log_info "Creating runtime directories..."
mkdir -p /run/php /run/app \
         /usr/share/nginx/html/runtime/{cache,logs,session,temp} \
         /var/lib/nginx/{body,fastcgi,proxy} \
         /tmp/php-sessions

# Set permissions
chown -R nginx:nginx /run/php /run/app \
    /usr/share/nginx/html/runtime \
    /var/lib/nginx \
    /tmp/php-sessions 2>/dev/null || true

# Remove draining flag
rm -f /run/app/draining

# Render configuration templates with environment variables
log_info "Rendering configuration templates..."

# PHP-FPM pool configuration
if [ -f /etc/php/7.2/fpm/pool.d/www.conf.template ]; then
    envsubst < /etc/php/7.2/fpm/pool.d/www.conf.template \
        > /etc/php/7.2/fpm/pool.d/www.conf
fi

# Nginx configuration
if [ -f /etc/nginx/nginx.conf.template ]; then
    envsubst '$NGINX_WORKER_PROCESSES $NGINX_WORKER_CONNECTIONS $CLIENT_MAX_BODY_SIZE' \
        < /etc/nginx/nginx.conf.template \
        > /etc/nginx/nginx.conf
fi

# Validate PHP-FPM configuration
log_info "Validating PHP-FPM configuration..."
if ! php-fpm7.2 -t 2>&1 | tee /tmp/fpm-test.log; then
    log_error "PHP-FPM configuration test failed:"
    cat /tmp/fpm-test.log
    exit 1
fi

# Check for module loading issues
if grep -i "already loaded" /tmp/fpm-test.log; then
    log_error "Module already loaded warning detected - configuration error"
    exit 1
fi

# Validate Nginx configuration
log_info "Validating Nginx configuration..."
if ! nginx -t 2>&1 | tee /tmp/nginx-test.log; then
    log_error "Nginx configuration test failed:"
    cat /tmp/nginx-test.log
    exit 1
fi

# Start PHP-FPM in background
log_info "Starting PHP-FPM..."
php-fpm7.2 --nodaemon --fpm-config /etc/php/7.2/fpm/php-fpm.conf &
FPM_PID=$!

# Wait for FPM socket to be ready
log_info "Waiting for PHP-FPM socket..."
WAIT_COUNT=0
MAX_WAIT=30
while [ ! -S /run/php/php7.2-fpm.sock ] && [ $WAIT_COUNT -lt $MAX_WAIT ]; do
    sleep 1
    WAIT_COUNT=$((WAIT_COUNT + 1))

    # Check if FPM process died
    if ! kill -0 $FPM_PID 2>/dev/null; then
        log_error "PHP-FPM process died during startup"
        exit 1
    fi
done

if [ ! -S /run/php/php7.2-fpm.sock ]; then
    log_error "PHP-FPM socket not ready after ${MAX_WAIT}s"
    exit 1
fi

log_info "PHP-FPM started successfully (PID: $FPM_PID)"

# Start Nginx in background
log_info "Starting Nginx..."
nginx -g 'daemon off;' &
NGINX_PID=$!

log_info "Nginx started successfully (PID: $NGINX_PID)"
log_info "=== Container initialization complete ==="
log_info "Monitoring processes..."

# Monitor processes
while true; do
    # Check PHP-FPM
    if ! kill -0 $FPM_PID 2>/dev/null; then
        log_error "PHP-FPM process (PID: $FPM_PID) has died"

        # Kill Nginx
        if [ -n "$NGINX_PID" ] && kill -0 "$NGINX_PID" 2>/dev/null; then
            kill -TERM "$NGINX_PID" 2>/dev/null || true
        fi

        exit 1
    fi

    # Check Nginx
    if ! kill -0 $NGINX_PID 2>/dev/null; then
        log_error "Nginx process (PID: $NGINX_PID) has died"

        # Kill PHP-FPM
        if [ -n "$FPM_PID" ] && kill -0 "$FPM_PID" 2>/dev/null; then
            kill -TERM "$FPM_PID" 2>/dev/null || true
        fi

        exit 1
    fi

    sleep 5
done
