#!/bin/bash
# 用法：php-fpm | supervisord | 其他命令
#   HOST_USERS="名称:uid:gid[:附加gid,...] ..."  建立与宿主机一致的用户，写出的文件属主不变
#   PHP_DISABLE_EXT="扩展 ..."                   关掉宿主机上没有的扩展
set -euo pipefail
id_of() { getent "$1" "$2" | cut -d: -f"$3" || true; }
for spec in ${HOST_USERS:-}; do
  IFS=: read -r name uid gid extra <<<"$spec"
  # 镜像自带的账号（例如 nginx 999、application 1000）与宿主机账号同名或同 id 时，让位给宿主机账号
  old=$(id_of passwd "$name" 3); if [ -n "$old" ] && [ "$old" != "$uid" ]; then userdel "$name"; fi
  old=$(id_of passwd "$uid" 1); if [ -n "$old" ] && [ "$old" != "$name" ]; then userdel "$old"; fi
  old=$(id_of group "$name" 3); if [ -n "$old" ] && [ "$old" != "$gid" ]; then groupdel "$name"; fi
  old=$(id_of group "$gid" 1)
  if [ -z "$old" ]; then groupadd -g "$gid" "$name"; elif [ "$old" != "$name" ]; then groupmod -n "$name" "$old"; fi
  # 以下只在需要时修改：账号工具每次写文件都会 fdatasync，磁盘忙时一次要几秒，重启容器时不应再付这个代价
  if ! getent passwd "$name" >/dev/null; then useradd -u "$uid" -g "$gid" -M -d /nonexistent -s /usr/sbin/nologin "$name"
  elif [ "$(id -g "$name")" != "$gid" ]; then usermod -g "$gid" "$name"; fi
  for g in ${extra//,/ }; do
    getent group "$g" >/dev/null || groupadd -g "$g" "hostgrp$g"
    case " $(id -G "$name") " in *" $g "*) ;; *) usermod -aG "$(id_of group "$g" 1)" "$name" ;; esac
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
