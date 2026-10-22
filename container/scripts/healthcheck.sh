#!/bin/bash
# Health check script for container probes
# Checks Nginx and PHP-FPM availability

set -e

# Check if draining
if [ -f /run/app/draining ]; then
    echo "Container is draining"
    exit 1
fi

# Check Nginx is responding on loopback
if ! curl -sf -m 2 http://127.0.0.1:8081/live > /dev/null 2>&1; then
    echo "Nginx liveness check failed"
    exit 1
fi

# Check FPM via readiness endpoint
if ! curl -sf -m 3 http://127.0.0.1:8081/ready > /dev/null 2>&1; then
    echo "FPM readiness check failed"
    exit 1
fi

exit 0
