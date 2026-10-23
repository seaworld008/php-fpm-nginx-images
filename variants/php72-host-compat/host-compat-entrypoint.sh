#!/bin/bash
# 用法：php-fpm | supervisord | 其他命令
#   HOST_USERS="名称:uid:gid[:附加gid,...] ..."  建立与宿主机一致的用户，写出的文件属主不变
#   PHP_DISABLE_EXT="扩展 ..."                   关掉宿主机上没有的扩展
set -euo pipefail
for spec in ${HOST_USERS:-}; do
  IFS=: read -r name uid gid extra <<<"$spec"
  getent group "$gid" >/dev/null || groupadd -g "$gid" "$name"
  getent passwd "$uid" >/dev/null || useradd -u "$uid" -g "$gid" -M -d /nonexistent -s /usr/sbin/nologin "$name"
  for g in ${extra//,/ }; do
    getent group "$g" >/dev/null || groupadd -g "$g" "hostgrp$g"
    usermod -aG "$(getent group "$g" | cut -d: -f1)" "$(getent passwd "$uid" | cut -d: -f1)"
  done
done
if [ -n "${PHP_DISABLE_EXT:-}" ]; then
  phpdismod -v 7.2 -s ALL ${PHP_DISABLE_EXT}
fi
case "${1:-php-fpm}" in
  php-fpm)
    php-fpm7.2 -t -y /etc/php/7.2/fpm/php-fpm.conf
    exec php-fpm7.2 -F -y /etc/php/7.2/fpm/php-fpm.conf
    ;;
  supervisord)
    mkdir -p /var/run/supervisor /var/log/supervisor
    exec supervisord -n -c /etc/supervisord.conf
    ;;
  *)
    exec "$@"
    ;;
esac
