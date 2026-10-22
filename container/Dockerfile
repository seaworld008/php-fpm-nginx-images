# Production-ready Nginx + PHP-FPM 7.2.34 with CVE patches
# Base: Debian 12 Bookworm
# PHP: 7.2.34-66 from Sury (includes CVE-2026-109618, CVE-2026-109619 patches)
# Nginx: Latest stable from official repository
#
# Build: docker build -t jwxt-nginx-php72:v100.20261022 -f Dockerfile.production .
#

#############################################
# Stage 1: Swoole Builder
#############################################
FROM debian:12-slim AS swoole-builder

# Install Sury repository for PHP 7.2 development files
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates curl gnupg2 lsb-release \
        build-essential autoconf \
        libssl-dev libcurl4-openssl-dev \
        zlib1g-dev libpcre3-dev && \
    curl -sSLo /usr/share/keyrings/deb.sury.org-php.gpg \
        https://packages.sury.org/php/apt.gpg && \
    sh -c 'echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list' && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        php7.2-dev=7.2.34-66+0~20261021.122+debian12~1.gbpe0bcd4 && \
    rm -rf /var/lib/apt/lists/*

# Build Swoole 4.8.13 (last stable for PHP 7.2)
RUN cd /tmp && \
    curl -sSLO https://pecl.php.net/get/swoole-4.8.13.tgz && \
    tar xzf swoole-4.8.13.tgz && \
    cd swoole-4.8.13 && \
    phpize && \
    ./configure \
        --enable-openssl \
        --enable-sockets \
        --enable-http2 \
        --enable-mysqlnd && \
    make -j$(nproc) && \
    make install && \
    echo "extension=swoole.so" > /tmp/swoole.ini

#############################################
# Stage 2: Runtime Image
#############################################
FROM debian:12-slim

LABEL maintainer="JLKJ DevOps <devops@jlkj.com>" \
      org.opencontainers.image.title="JWXT Nginx PHP-FPM 7.2.34" \
      org.opencontainers.image.description="Production Nginx + PHP-FPM 7.2.34 with CVE patches for JWXT" \
      org.opencontainers.image.version="v100.20261022" \
      org.opencontainers.image.base.name="debian:12-slim"

# Install Nginx from official repository
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates curl gnupg2 lsb-release && \
    curl -fsSL https://nginx.org/keys/nginx_signing.key | gpg --dearmor -o /usr/share/keyrings/nginx-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/debian $(lsb_release -cs) nginx" \
        > /etc/apt/sources.list.d/nginx.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends nginx && \
    rm -rf /var/lib/apt/lists/*

# Install Sury PHP 7.2.34 with all extensions
RUN curl -sSLo /usr/share/keyrings/deb.sury.org-php.gpg \
        https://packages.sury.org/php/apt.gpg && \
    sh -c 'echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list' && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        # PHP Core (locked version with CVE patches)
        php7.2-cli=7.2.34-66+0~20261021.122+debian12~1.gbpe0bcd4 \
        php7.2-fpm=7.2.34-66+0~20261021.122+debian12~1.gbpe0bcd4 \
        php7.2-common=7.2.34-66+0~20261021.122+debian12~1.gbpe0bcd4 \
        php7.2-opcache=7.2.34-66+0~20261021.122+debian12~1.gbpe0bcd4 \
        # Standard Extensions
        php7.2-bcmath \
        php7.2-bz2 \
        php7.2-curl \
        php7.2-gd \
        php7.2-gmp \
        php7.2-imap \
        php7.2-intl \
        php7.2-mbstring \
        php7.2-mysql \
        php7.2-pgsql \
        php7.2-readline \
        php7.2-sqlite3 \
        php7.2-xml \
        php7.2-zip \
        # Additional Extensions
        php7.2-imagick \
        # PECL Extensions (pre-compiled by Sury)
        php7.2-redis \
        php7.2-memcached \
        php7.2-mongodb \
        php7.2-igbinary && \
    rm -rf /var/lib/apt/lists/*

# Install utilities
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        procps \
        vim \
        nano \
        less \
        wget \
        telnet \
        net-tools \
        iputils-ping \
        dnsutils \
        zip \
        unzip \
        git \
        tzdata \
        supervisor && \
    rm -rf /var/lib/apt/lists/*

# Install Composer 2.8.4
RUN curl -sSLf https://getcomposer.org/installer | php -- \
        --version=2.8.4 \
        --install-dir=/usr/local/bin \
        --filename=composer && \
    chmod +x /usr/local/bin/composer && \
    composer --version

# Copy Swoole from builder
COPY --from=swoole-builder /usr/lib/php/20170718/swoole.so /usr/lib/php/20170718/
COPY --from=swoole-builder /tmp/swoole.ini /etc/php/7.2/mods-available/swoole.ini
RUN phpenmod swoole && \
    php -m | grep swoole

# Create nginx user with UID 101 (matches standard nginx)
RUN groupadd -g 101 nginx || true && \
    useradd -u 101 -g 101 -s /sbin/nologin -c "Nginx web server" nginx || true

# Create required directories
RUN mkdir -p \
        /usr/share/nginx/html \
        /usr/share/nginx/logs \
        /var/log/nginx \
        /var/log/php \
        /run/php \
        /var/lib/nginx/body \
        /var/lib/nginx/proxy && \
    chown -R nginx:nginx \
        /usr/share/nginx \
        /var/log/nginx \
        /var/log/php \
        /run/php \
        /var/lib/nginx

# Configure timezone
RUN ln -snf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo "Asia/Shanghai" > /etc/timezone

# Base PHP-FPM configuration
RUN set -eux; \
    CONF="/etc/php/7.2/fpm/pool.d/www.conf"; \
    # Basic pool settings
    sed -ri 's|^user\s*=.*|user = nginx|' "$CONF"; \
    sed -ri 's|^group\s*=.*|group = nginx|' "$CONF"; \
    sed -ri 's|^listen\s*=.*|listen = /run/php/php7.2-fpm.sock|' "$CONF"; \
    sed -ri 's|^;?listen\.owner\s*=.*|listen.owner = nginx|' "$CONF"; \
    sed -ri 's|^;?listen\.group\s*=.*|listen.group = nginx|' "$CONF"; \
    sed -ri 's|^;?listen\.mode\s*=.*|listen.mode = 0660|' "$CONF"; \
    # Process manager (conservative defaults for 1GB container)
    sed -ri 's|^;?pm\s*=.*|pm = dynamic|' "$CONF"; \
    sed -ri 's|^;?pm\.max_children\s*=.*|pm.max_children = 20|' "$CONF"; \
    sed -ri 's|^;?pm\.start_servers\s*=.*|pm.start_servers = 5|' "$CONF"; \
    sed -ri 's|^;?pm\.min_spare_servers\s*=.*|pm.min_spare_servers = 5|' "$CONF"; \
    sed -ri 's|^;?pm\.max_spare_servers\s*=.*|pm.max_spare_servers = 10|' "$CONF"; \
    sed -ri 's|^;?pm\.process_idle_timeout\s*=.*|pm.process_idle_timeout = 10s|' "$CONF"; \
    sed -ri 's|^;?pm\.max_requests\s*=.*|pm.max_requests = 500|' "$CONF"; \
    # Status and health
    grep -q '^pm.status_path' "$CONF" \
      && sed -ri 's|^;?pm\.status_path\s*=.*|pm.status_path = /fpm_status|' "$CONF" \
      || echo 'pm.status_path = /fpm_status' >> "$CONF"; \
    grep -q '^ping.path' "$CONF" \
      && sed -ri 's|^;?ping\.path\s*=.*|ping.path = /fpm_ping|' "$CONF" \
      || echo 'ping.path = /fpm_ping' >> "$CONF"; \
    grep -q '^ping.response' "$CONF" \
      && sed -ri 's|^;?ping\.response\s*=.*|ping.response = pong|' "$CONF" \
      || echo 'ping.response = pong' >> "$CONF"

# Base PHP configuration
RUN cat > /etc/php/7.2/fpm/conf.d/99-production.ini <<'EOF'
[PHP]
; Memory & Performance
memory_limit = 256M
max_execution_time = 60
max_input_time = 60
max_input_vars = 3000
post_max_size = 32M
upload_max_filesize = 32M

; Error Handling (production)
display_errors = Off
display_startup_errors = Off
log_errors = On
error_log = /var/log/php/error.log

; Session
session.save_handler = files
session.save_path = "/var/lib/php/sessions"
session.gc_probability = 1
session.gc_divisor = 1000
session.gc_maxlifetime = 1440

; Timezone
date.timezone = Asia/Shanghai
EOF

# Base OPcache configuration (update the mods-available file that's symlinked)
RUN cat > /etc/php/7.2/mods-available/opcache.ini <<'EOF'
; configuration for php opcache module
; priority=10
zend_extension=opcache.so

[opcache]
opcache.enable=1
opcache.enable_cli=0
opcache.memory_consumption=128
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=10000
opcache.validate_timestamps=1
opcache.revalidate_freq=2
opcache.fast_shutdown=1

realpath_cache_size=4096K
realpath_cache_ttl=600
EOF

# Base Nginx configuration
RUN cat > /etc/nginx/nginx.conf <<'EOF'
user nginx;
worker_processes auto;
pid /var/run/nginx.pid;
error_log /var/log/nginx/error.log warn;

events {
    worker_connections 1024;
    use epoll;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 32M;

    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript application/json application/javascript application/xml+rss application/rss+xml font/truetype font/opentype application/vnd.ms-fontobject image/svg+xml;

    include /etc/nginx/conf.d/*.conf;
}
EOF

# Minimal default server (will be overridden by Jenkins)
RUN mkdir -p /etc/nginx/conf.d && \
    cat > /etc/nginx/conf.d/default.conf <<'EOF'
server {
    listen 80 default_server;
    server_name _;
    root /usr/share/nginx/html;
    index index.php index.html index.htm;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass unix:/run/php/php7.2-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.(ht|git) {
        deny all;
    }
}
EOF

# Create placeholder index
RUN echo '<?php phpinfo();' > /usr/share/nginx/html/index.php && \
    chown nginx:nginx /usr/share/nginx/html/index.php

# Supervisor configuration
RUN cat > /etc/supervisord.conf <<'EOF'
[supervisord]
nodaemon=true
user=root
logfile=/var/log/supervisor/supervisord.log
pidfile=/var/run/supervisord.pid
loglevel=info

[program:php-fpm]
command=/usr/sbin/php-fpm7.2 -F
autostart=true
autorestart=true
priority=5
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:nginx]
command=/usr/sbin/nginx -g 'daemon off;'
autostart=true
autorestart=true
priority=10
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
EOF

RUN mkdir -p /var/log/supervisor

# Final validation
RUN php-fpm7.2 -t && nginx -t

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD curl -f http://localhost/fpm_ping || exit 1

# Expose ports
EXPOSE 80

# Default command
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
