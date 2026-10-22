#!/bin/bash
# Native PHP 7.2 binary verification script
# Verifies installed PHP packages and CVE patches

set -euo pipefail

PHP_BIN="${PHP_BIN:-/usr/bin/php}"
FPM_BIN="${FPM_BIN:-/usr/sbin/php-fpm7.2}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

check_php_version() {
    log_info "Checking PHP version..."
    if [ ! -x "$PHP_BIN" ]; then
        log_error "PHP binary not found at $PHP_BIN"
        return 1
    fi

    local version=$("$PHP_BIN" -v | head -1)
    echo "$version"

    if ! echo "$version" | grep -q "PHP 7.2"; then
        log_error "Expected PHP 7.2, found: $version"
        return 1
    fi

    log_info "✓ PHP version is 7.2"
}

check_fpm() {
    log_info "Checking PHP-FPM..."
    if [ ! -x "$FPM_BIN" ]; then
        log_warn "PHP-FPM binary not found at $FPM_BIN"
        return 0
    fi

    local fpm_version=$("$FPM_BIN" -v | head -1)
    echo "$fpm_version"

    if ! echo "$fpm_version" | grep -q "PHP 7.2"; then
        log_error "PHP-FPM version mismatch"
        return 1
    fi

    log_info "✓ PHP-FPM version correct"
}

check_debian_packages() {
    log_info "Checking Debian/Ubuntu packages..."

    if ! command -v dpkg &> /dev/null; then
        log_warn "Not a Debian-based system, skipping package check"
        return 0
    fi

    local packages=$(dpkg -l | grep "php7.2" | awk '{print $2, $3}')
    if [ -z "$packages" ]; then
        log_warn "No php7.2 packages found"
        return 0
    fi

    echo "$packages"

    # Check for Sury repository
    if [ -f /etc/apt/sources.list.d/php.list ]; then
        log_info "✓ Sury repository configured"
        local sury_line=$(grep -v "^#" /etc/apt/sources.list.d/php.list | head -1)
        echo "  $sury_line"
    fi
}

check_extensions() {
    log_info "Checking loaded extensions..."
    local extensions=$("$PHP_BIN" -m)
    local count=$(echo "$extensions" | wc -l)

    log_info "Loaded $count extensions"

    # Check critical extensions
    local critical=("mysqli" "pdo_mysql" "json" "mbstring" "xml" "curl")
    for ext in "${critical[@]}"; do
        if ! echo "$extensions" | grep -qw "$ext"; then
            log_warn "Critical extension missing: $ext"
        fi
    done
}

check_configuration() {
    log_info "Checking PHP configuration..."

    local expose_php=$("$PHP_BIN" -r "echo ini_get('expose_php');" 2>/dev/null || echo "unknown")
    if [ "$expose_php" != "" ] && [ "$expose_php" != "0" ]; then
        log_warn "expose_php is enabled (security risk)"
    fi

    local opcache=$("$PHP_BIN" -r "echo extension_loaded('Zend OPcache') ? 'yes' : 'no';" 2>/dev/null || echo "unknown")
    if [ "$opcache" = "no" ]; then
        log_warn "OPcache not loaded (performance impact)"
    fi
}

check_security_info() {
    log_info "Security information..."
    echo ""
    echo "This script verifies PHP installation but does NOT confirm CVE patches."
    echo "For CVE verification, check:"
    echo "  1. Package version matches Sury/vendor security advisory"
    echo "  2. Package changelog mentions specific CVEs"
    echo "  3. Binary signature matches official release"
    echo ""
    echo "Debian/Ubuntu: apt-cache show php7.2-common | grep Version"
    echo "Changelog: zcat /usr/share/doc/php7.2-common/changelog.Debian.gz | head -50"
    echo ""
}

generate_inventory() {
    log_info "Generating inventory..."
    local output="php-inventory-$(date +%Y%m%d-%H%M%S).txt"

    {
        echo "=== PHP Binary Inventory ==="
        echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo ""
        echo "--- PHP Version ---"
        "$PHP_BIN" -v
        echo ""
        echo "--- Loaded Extensions ---"
        "$PHP_BIN" -m
        echo ""
        echo "--- Debian Packages ---"
        if command -v dpkg &> /dev/null; then
            dpkg -l | grep php7.2 || echo "No php7.2 packages"
        fi
        echo ""
        echo "--- Configuration ---"
        "$PHP_BIN" -i | grep -E "(expose_php|opcache|memory_limit|upload_max|post_max)"
    } > "$output"

    log_info "Inventory saved to: $output"
    echo "Review this file before sharing (may contain sensitive paths)"
}

main() {
    log_info "Starting PHP verification..."
    echo ""

    check_php_version
    check_fpm
    check_debian_packages
    check_extensions
    check_configuration
    check_security_info

    if [ "${GENERATE_INVENTORY:-}" = "1" ]; then
        generate_inventory
    fi

    log_info "Verification complete"
}

main "$@"
