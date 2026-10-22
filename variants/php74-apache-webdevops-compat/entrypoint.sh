#!/bin/bash
# Apache + PHP-FPM; 任一进程退出则整个容器退出, 由 restart 策略拉起
set -e
mkdir -p /run/php /var/run/apache2 /var/lock/apache2
php-fpm7.4 -t -y /etc/php/7.4/fpm/php-fpm.conf
apache2ctl -t
php-fpm7.4 -F -y /etc/php/7.4/fpm/php-fpm.conf & fpm=$!
apache2ctl -D FOREGROUND & httpd=$!
set +e
wait -n "$fpm" "$httpd"; code=$?
echo "entrypoint: 进程退出 (code=$code), 停止容器" >&2
kill -TERM "$fpm" "$httpd" 2>/dev/null; wait
exit $code
