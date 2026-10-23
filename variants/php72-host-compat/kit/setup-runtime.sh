#!/bin/bash
# 第 1 步（不影响线上）：建立 /data/php72-runtime，用测试地址启动 php72-fpm，与宿主机现有 FPM 并行运行。
# 以文件方式执行：bash setup-runtime.sh。用环境变量配置：
#   HOST_USERS       必填，运行 FPM/队列/定时任务的用户，"名称:uid:gid[:附加gid,...]"，空格分隔
#                    （附加 gid 48 = apache，用于 Remi 的会话目录 /var/lib/php/session）
#   PHP_DISABLE_EXT  必填，宿主机没有加载、需要在容器里关闭的扩展（可以为空字符串）
#   PARITY_FPM       必填，tools/ini_parity.py 为 FPM 生成的补齐文件
#   PARITY_CLI       必填，tools/ini_parity.py 为 CLI 生成的补齐文件
#   MOUNTS           按原路径挂载进两个容器的目录（代码、上传文件、业务日志），默认 /data
#   FPM_EXTRA_MOUNTS 只挂给 FPM 的目录。宿主机 php-fpm 的 PrivateTmp=no 时自动加上 /tmp（会话常存放在这里）
#   CLI_EXTRA_MOUNTS 只挂给 php72-cli 的目录，默认 /tmp：宿主机上的命令行 PHP 本来就和其他程序共用 /tmp
#   POOL             宿主机 FPM 池配置，默认 /etc/php-fpm.d/www.conf
#   TEST_LISTEN      并行测试时的监听地址，默认 127.0.0.1:19000
#   IMAGE            镜像，默认 114.115.130.46/jlkj-base/php-fpm:7.2.34-sury-20261021-hostcompat-r2
set -euo pipefail
: "${HOST_USERS:?}" "${PHP_DISABLE_EXT?}" "${PARITY_FPM:?}" "${PARITY_CLI:?}"
R=/data/php72-runtime
B=/root/php_container_backup
D=$(cd "$(dirname "$0")" && pwd)
IMAGE=${IMAGE:-114.115.130.46/jlkj-base/php-fpm:7.2.34-sury-20261021-hostcompat-r2}
MOUNTS=${MOUNTS:-/data}
FPM_EXTRA_MOUNTS=${FPM_EXTRA_MOUNTS:-}
CLI_EXTRA_MOUNTS=${CLI_EXTRA_MOUNTS-/tmp}
POOL=${POOL:-/etc/php-fpm.d/www.conf}
TEST_LISTEN=${TEST_LISTEN:-127.0.0.1:19000}
# compose v2 插件优先，没有时用 v1；cutover.sh 和 README 用同一个命令
if docker compose version >/dev/null 2>&1; then DC="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then DC=docker-compose
else echo "没有 docker compose（v2）也没有 docker-compose（v1）" >&2; exit 1; fi
# 宿主机 FPM 不用私有 /tmp 时，会话和临时文件与其他程序共用 /tmp，容器 FPM 也要挂载（systemd 219 没有 --value）
if [ "$(systemctl show php-fpm -p PrivateTmp 2>/dev/null)" = PrivateTmp=no ]; then
  case " $FPM_EXTRA_MOUNTS " in *" /tmp "*) ;; *) FPM_EXTRA_MOUNTS="$FPM_EXTRA_MOUNTS /tmp" ;; esac
fi
# 池配置开了慢日志时，FPM master 要用 ptrace 读取 worker 的调用栈，容器默认没有这个权限
PTRACE=no
grep -qE '^[[:space:]]*request_slowlog_timeout[[:space:]]*=[[:space:]]*[1-9]' "$POOL" && PTRACE=yes
mkdir -p $R/conf $B
echo "$DC" > $R/.compose
tar czf $B/host-php-config-backup.tgz -C / etc/php.ini etc/php.d etc/php-fpm.conf etc/php-fpm.d \
  etc/supervisord.conf etc/supervisord.d var/spool/cron etc/rc.d/rc.local 2>/dev/null || true
rpm -qa 'php*' --qf '%{NAME}\n' | sort > $B/rpm-php.txt
cp -p /etc/php.ini $R/conf/php.ini
cp -p "$POOL" $R/conf/www.conf
awk -F= '/^[[:space:]]*listen[[:space:]]*=/{gsub(/[ \t]/, "", $2); print $2; exit}' $R/conf/www.conf > $R/conf/.original-listen
sed -i -E "s#^[[:space:]]*listen[[:space:]]*=.*#listen = $TEST_LISTEN#" $R/conf/www.conf
# 必须所有人可读：命令行 PHP 以业务用户身份运行，读不到的 ini 会被 PHP 静默跳过
install -m 644 "$PARITY_FPM" $R/conf/zz-host-parity-fpm.ini
install -m 644 "$PARITY_CLI" $R/conf/zz-host-parity-cli.ini
cat > $R/conf/php-fpm.conf <<'G'
[global]
pid = /run/php/php7.2-fpm.pid
error_log = /var/log/php-fpm/error-container.log
daemonize = no
include = /etc/php/7.2/fpm/pool.d/*.conf
G
optional() { for m in "$@"; do [ -e "$m" ] && echo "      - $m:$m"; done; return 0; }
same_path() { for m in "$@"; do echo "      - $m:$m"; done; }
{
  [ "$DC" = docker-compose ] && echo 'version: "3"'
  echo '# 宿主机 PHP 7.2（原 Remi 7.2.34-22）迁到 Sury 7.2.34-66 容器。网络用 host，代码与日志按原路径挂载。'
  echo 'x-php: &php'
  echo "  image: $IMAGE"
  echo '  network_mode: host'
  echo '  restart: always'
  echo '  environment:'
  echo '    TZ: Asia/Shanghai'
  echo "    HOST_USERS: \"$HOST_USERS\""
  echo "    PHP_DISABLE_EXT: \"$PHP_DISABLE_EXT\""
  echo 'services:'
  echo '  php72-fpm:'
  echo '    <<: *php'
  echo '    container_name: php72-fpm'
  echo '    command: ["php-fpm"]'
  echo '    stop_grace_period: 30s'
  [ $PTRACE = yes ] && echo '    cap_add: [SYS_PTRACE]'
  echo '    volumes:'
  same_path $MOUNTS $FPM_EXTRA_MOUNTS
  echo '      - /etc/localtime:/etc/localtime:ro'
  optional /usr/share/fonts /etc/php-cacert.pem /var/lib/php/session /var/lib/php/wsdlcache
  echo '      - /var/log/php-fpm:/var/log/php-fpm'
  echo '      - ./conf/php.ini:/etc/php/7.2/fpm/php.ini:ro'
  echo '      - ./conf/php-fpm.conf:/etc/php/7.2/fpm/php-fpm.conf:ro'
  echo '      - ./conf/www.conf:/etc/php/7.2/fpm/pool.d/www.conf:ro'
  echo '      - ./conf/zz-host-parity-fpm.ini:/etc/php/7.2/fpm/conf.d/99-zz-host-parity.ini:ro'
  echo '  php72-cli:'
  echo '    <<: *php'
  echo '    container_name: php72-cli'
  echo '    command: ["supervisord"]'
  echo '    stop_grace_period: 60s'
  echo '    volumes:'
  same_path $MOUNTS $CLI_EXTRA_MOUNTS
  echo '      - /etc/localtime:/etc/localtime:ro'
  optional /usr/share/fonts /etc/php-cacert.pem
  echo '      - ./conf/php.ini:/etc/php/7.2/cli/php.ini:ro'
  echo '      - ./conf/zz-host-parity-cli.ini:/etc/php/7.2/cli/conf.d/99-zz-host-parity.ini:ro'
  echo '      - /etc/supervisord.conf:/etc/supervisord.conf:ro'
  echo '      - /etc/supervisord.d:/etc/supervisord.d:ro'
  echo '      - /var/run/supervisor:/var/run/supervisor'
  echo '      - /var/log/supervisor:/var/log/supervisor'
} > $R/docker-compose.yml
sed -i 's#\(/usr/share/fonts:/usr/share/fonts\)$#\1:ro#; s#\(/etc/php-cacert.pem:/etc/php-cacert.pem\)$#\1:ro#' $R/docker-compose.yml
mkdir -p /var/log/php-fpm /var/run/supervisor /var/log/supervisor
sed "s/@DC@/$DC/g" "$D/README.runtime.txt" > $R/README.txt
cd $R && $DC config -q && $DC up -d php72-fpm >/dev/null 2>&1
for i in $(seq 1 30); do grep -q "ready to handle connections" /var/log/php-fpm/error-container.log 2>/dev/null && break; sleep 1; done
echo "php72-fpm: $(docker ps --filter name=^/php72-fpm$ --format '{{.Status}}') | 测试地址 $TEST_LISTEN 监听: $(ss -ltn | grep -c " ${TEST_LISTEN} ") | 原地址 $(cat $R/conf/.original-listen) 仍由宿主机 FPM 服务"
echo "compose: $DC | FPM 额外挂载: ${FPM_EXTRA_MOUNTS:-无} | CLI 额外挂载: ${CLI_EXTRA_MOUNTS:-无} | 慢日志 ptrace: $PTRACE"
