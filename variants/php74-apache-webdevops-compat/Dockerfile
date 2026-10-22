# syntax=docker/dockerfile:1
# 替换 webdevops/php-apache:7.4 (PHP 7.4.26 / Debian 10 / Apache 2.4.38)
# PHP: Sury 7.4.33-31 (2026-10-21; changelog 列出 CVE-2026-109618/109619 回移条目, 补丁状态 UNVERIFIED); 目录结构与 webdevops 兼容
FROM debian:bookworm-slim
ARG PHPV=1:7.4.33-31+0~20261021.121+debian12~1.gbpe9c428
ENV DEBIAN_FRONTEND=noninteractive TZ=Asia/Shanghai
LABEL jlkj.php.package="${PHPV}" jlkj.replaces="webdevops/php-apache:7.4"
RUN set -eux; apt-get update; apt-get install -y --no-install-recommends ca-certificates curl tzdata; \
    curl -fsSL -o /usr/share/keyrings/deb.sury.org-php.gpg https://packages.sury.org/php/apt.gpg; \
    echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ bookworm main" > /etc/apt/sources.list.d/php.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends apache2 tini \
      php7.4-fpm=${PHPV} php7.4-cli=${PHPV} php7.4-common=${PHPV} php7.4-opcache=${PHPV} php7.4-readline=${PHPV} php7.4-json=${PHPV} \
      php7.4-bcmath=${PHPV} php7.4-bz2=${PHPV} php7.4-curl=${PHPV} php7.4-gd=${PHPV} php7.4-imap=${PHPV} php7.4-intl=${PHPV} \
      php7.4-ldap=${PHPV} php7.4-mbstring=${PHPV} php7.4-mysql=${PHPV} php7.4-pgsql=${PHPV} php7.4-soap=${PHPV} \
      php7.4-sqlite3=${PHPV} php7.4-xml=${PHPV} php7.4-xmlrpc=${PHPV} php7.4-zip=${PHPV} \
      php7.4-amqp php7.4-apcu php7.4-imagick php7.4-memcached php7.4-mongodb php7.4-redis; \
    test "$(dpkg-query -W -f '${Version}' php7.4-fpm)" = "${PHPV}"; \
    rm -rf /var/lib/apt/lists/*
COPY rootfs/ /
COPY php-fpm.conf /etc/php/7.4/fpm/php-fpm.conf
COPY www.conf /tmp/www.conf
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY zz-jlkj-parity.ini /etc/php/7.4/mods-available/zz-jlkj-parity.ini
RUN set -eux; \
    groupadd -g 1000 application; useradd -u 1000 -g application -m -s /bin/sh application; \
    rm -f /etc/php/7.4/fpm/pool.d/*.conf; mv /tmp/www.conf /etc/php/7.4/fpm/pool.d/www.conf; \
    rm -f /etc/php/7.4/fpm/php.ini /etc/php/7.4/cli/php.ini; \
    for s in fpm cli; do ln -s /opt/docker/etc/php/php.webdevops.ini /etc/php/7.4/$s/conf.d/98-webdevops.ini; ln -s /opt/docker/etc/php/php.ini /etc/php/7.4/$s/conf.d/99-docker.ini; done; \
    ln -s /proc/1/fd/1 /docker.stdout; ln -s /proc/1/fd/2 /docker.stderr; \
    a2dissite 000-default; a2enmod actions expires headers proxy proxy_fcgi rewrite setenvif deflate; \
    echo 'IncludeOptional /opt/docker/etc/httpd/main.conf' > /etc/apache2/conf-available/zz-docker.conf; a2enconf zz-docker; \
    phpenmod -v 7.4 -s ALL zz-jlkj-parity; chmod +x /usr/local/bin/entrypoint.sh; mkdir -p /app /run/php; \
    php-fpm7.4 -t -y /etc/php/7.4/fpm/php-fpm.conf; apache2ctl -t; php -v
WORKDIR /app
EXPOSE 80
ENTRYPOINT ["/usr/bin/tini", "-g", "--", "/usr/local/bin/entrypoint.sh"]
