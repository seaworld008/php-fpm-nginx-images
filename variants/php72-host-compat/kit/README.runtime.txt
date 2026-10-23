本机 PHP 已从 Remi 7.2.34-22（不含 CVE-2026-109618/109619 补丁）迁到容器（Sury 7.2.34-66）。
来源：github.com/seaworld008/php-fpm-nginx-images 的 variants/php72-host-compat 和 docs/13

容器（docker-compose.yml，network_mode: host，restart: always）
  php72-fpm  : PHP-FPM，监听原来的地址（nginx 配置未改），运行用户与原来相同
  php72-cli  : supervisord，直接使用宿主机的 /etc/supervisord.conf 和 /etc/supervisord.d/*.conf
宿主机命令照旧可用
  php ...                      -> /usr/bin/php 转发到 php72-cli（保持调用者身份和当前目录）
                                  需要用管道传数据给 php 时：echo x | PHP72_STDIN=1 php ...
  supervisorctl status/restart -> 连接 php72-cli 里的 supervisord（同一个 socket）
  crontab 未改动
配置
  conf/php.ini                 原 /etc/php.ini 的副本
  conf/www.conf                原 FPM 池配置的副本
  conf/zz-host-parity-*.ini    与原环境实际生效配置的差异补齐（tools/ini_parity.py 生成）
  /etc/php72-exec.conf         转发脚本认可的挂载路径（MOUNTS）
常用操作
  cd /data/php72-runtime && @DC@ ps / logs php72-fpm / restart php72-fpm
  修改 php.ini 或池配置后：@DC@ restart php72-fpm php72-cli
  /tmp：php72-cli 与宿主机共用；php72-fpm 只有原来 PrivateTmp=no（例如会话存在 /tmp）时才共用
  慢日志：池配置开了 request_slowlog_timeout 时，php72-fpm 带 cap_add SYS_PTRACE，否则慢日志里没有调用栈

日常维护
  supervisor 任务（新增 / 修改 / 删除）：和以前一样
    1. 编辑 /etc/supervisord.d/xxx.conf
    2. supervisorctl reread && supervisorctl update
  定时任务：和以前一样，crontab -e 或 crontab -e -u 用户
    命令里的 /usr/bin/php 或 php 会在容器里以原用户、原当前目录执行；非 PHP 的任务仍在宿主机上执行
  发布代码：不需要任何变化（代码目录直接挂载进容器）

注意（与以前不同的地方）
  1. supervisor 程序都在 PHP 容器里运行，只能是 PHP 程序（或者 sh、curl 这类容器里有的命令）。
  2. 程序和脚本的路径必须在挂载目录（见 /etc/php72-exec.conf 和 docker-compose.yml）下面。
  3. 运行用户必须写在 docker-compose.yml 的 HOST_USERS 里，改完执行 @DC@ up -d php72-fpm php72-cli；
     如果这个用户的 crontab 也要调用 php，还要在 /etc/sudoers.d/php72-exec 里加一行。
  4. 修改 supervisord 主配置 /etc/supervisord.conf 后，执行 docker restart php72-cli，所有队列会随之重启。
  5. crontab 里定义的环境变量不会传进容器。
  6. supervisorctl pid 显示的是容器内的进程号；要对应到宿主机进程，用 docker top php72-cli。

回滚（恢复 Remi PHP，约 1 分钟）
  cd /data/php72-runtime && @DC@ down
  yum localinstall -y /root/php_container_backup/rpms/*.rpm
  tar xzf /root/php_container_backup/host-php-config-backup.tgz -C /     （其中包含 rc.local）
  rm -f /etc/sudoers.d/php72-exec /usr/local/bin/php72-exec /etc/php72-exec.conf
  systemctl enable --now php-fpm supervisord
