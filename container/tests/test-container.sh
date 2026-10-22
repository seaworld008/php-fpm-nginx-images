#!/bin/bash
# Container validation test suite
# Tests image configuration, extensions, and lifecycle

set -euo pipefail

IMAGE_NAME="${IMAGE_NAME:-php72-fpm-nginx:production}"
CONTAINER_NAME="test-php72-$$"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

cleanup() {
    log_info "Cleaning up test container..."
    docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
}

trap cleanup EXIT

test_version() {
    log_info "Testing PHP version..."
    local php_ver=$(docker run --rm "$IMAGE_NAME" php -v | head -1)
    echo "$php_ver"
    if ! echo "$php_ver" | grep -q "PHP 7.2"; then
        log_error "Expected PHP 7.2, got: $php_ver"
        return 1
    fi
    log_info "✓ PHP version correct"
}

test_extensions() {
    log_info "Testing required extensions..."
    local extensions=(
        "bcmath" "calendar" "Core" "ctype" "curl" "date" "dom" "exif"
        "fileinfo" "filter" "ftp" "gd" "gettext" "hash" "iconv" "imagick"
        "json" "libxml" "mbstring" "mysqli" "mysqlnd" "openssl" "pcntl"
        "pcre" "PDO" "pdo_mysql" "Phar" "posix" "readline" "redis"
        "Reflection" "session" "shmop" "SimpleXML" "soap" "sockets"
        "sodium" "SPL" "standard" "swoole" "sysvmsg" "sysvsem" "sysvshm"
        "tokenizer" "xml" "xmlreader" "xmlwriter" "xsl" "Zend OPcache" "zip" "zlib"
    )

    local loaded=$(docker run --rm "$IMAGE_NAME" php -m)
    local missing=()

    for ext in "${extensions[@]}"; do
        if ! echo "$loaded" | grep -qw "$ext"; then
            missing+=("$ext")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing extensions: ${missing[*]}"
        return 1
    fi
    log_info "✓ All required extensions loaded"
}

test_configuration() {
    log_info "Testing PHP configuration..."
    docker run --rm "$IMAGE_NAME" php -i > /tmp/phpinfo-$$.txt

    # Check critical settings
    if ! grep -q "opcache.enable => On" /tmp/phpinfo-$$.txt; then
        log_warn "OPcache not enabled"
    fi

    if ! grep -q "expose_php => Off" /tmp/phpinfo-$$.txt; then
        log_warn "expose_php not disabled"
    fi

    rm -f /tmp/phpinfo-$$.txt
    log_info "✓ Configuration checked"
}

test_nginx() {
    log_info "Testing Nginx..."
    local nginx_ver=$(docker run --rm "$IMAGE_NAME" nginx -v 2>&1)
    echo "$nginx_ver"
    if ! echo "$nginx_ver" | grep -q "nginx/1"; then
        log_error "Nginx not found or version unexpected"
        return 1
    fi
    log_info "✓ Nginx version correct"
}

test_startup() {
    log_info "Testing container startup..."
    docker run -d --name "$CONTAINER_NAME" "$IMAGE_NAME"

    sleep 5

    if ! docker ps | grep -q "$CONTAINER_NAME"; then
        log_error "Container failed to start"
        docker logs "$CONTAINER_NAME"
        return 1
    fi

    log_info "✓ Container started successfully"
}

test_health() {
    log_info "Testing health endpoint..."
    local health=$(docker exec "$CONTAINER_NAME" curl -sf http://localhost/health || echo "FAILED")
    if [ "$health" = "FAILED" ]; then
        log_error "Health endpoint not responding"
        return 1
    fi
    log_info "✓ Health endpoint accessible"
}

test_php_fpm() {
    log_info "Testing PHP-FPM processing..."
    docker exec "$CONTAINER_NAME" sh -c 'echo "<?php phpinfo(); ?>" > /usr/share/nginx/html/test.php'

    local response=$(docker exec "$CONTAINER_NAME" curl -sf http://localhost/test.php | head -c 100)
    if ! echo "$response" | grep -qi "php"; then
        log_error "PHP-FPM not processing files"
        return 1
    fi

    docker exec "$CONTAINER_NAME" rm /usr/share/nginx/html/test.php
    log_info "✓ PHP-FPM processing works"
}

test_graceful_shutdown() {
    log_info "Testing graceful shutdown..."
    docker stop -t 30 "$CONTAINER_NAME"

    local exit_code=$(docker inspect "$CONTAINER_NAME" --format='{{.State.ExitCode}}')
    if [ "$exit_code" != "0" ]; then
        log_warn "Container exited with code $exit_code"
    fi
    log_info "✓ Graceful shutdown completed"
}

main() {
    log_info "Starting validation tests for $IMAGE_NAME"

    test_version
    test_extensions
    test_configuration
    test_nginx
    test_startup
    test_health
    test_php_fpm
    test_graceful_shutdown

    log_info "All tests passed!"
}

main "$@"
