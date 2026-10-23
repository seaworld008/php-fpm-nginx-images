#!/bin/bash
# 第 2 步（切换）：宿主机 FPM、supervisord 换成容器，删除 Remi PHP，/usr/bin/php 改为转发到容器。
# 前提：第 1 步的并行对比（tools/fcgi_compare.py）全部一致。
# 以文件方式执行：bash cutover.sh。脚本会关闭标准输入，用 bash -s 管道执行时后面的内容会丢失。
# 环境变量：
#   PROBE_TARGETS  必填，tools/nginx_targets.py --probe 生成的目标文件，切换前后各探测一次
#   PROBE          tools/http_probe.sh 的路径，默认与本脚本同目录
#   EXEC_USERS     需要通过 sudo 调用 php 的非 root 用户（其定时任务调用 php），默认取 HOST_USERS 中的名称
#   ROLLBACK_REPOS 下载回滚用 RPM 的仓库（逗号分隔），默认取这些包安装时的来源仓库
#   PROBE_PATHS    传给 http_probe.sh 的路径（空格分隔），默认 / 和一个不存在的地址
set -u
exec < /dev/null
R=/data/php72-runtime
B=/root/php_container_backup
D=$(cd "$(dirname "$0")" && pwd)
PROBE=${PROBE:-$D/http_probe.sh}
: "${PROBE_TARGETS:?}"
cd $R || exit 1
DC=$(cat $R/.compose 2>/dev/null || echo docker-compose)   # setup-runtime.sh 选定的 compose 命令
users=$(grep -oE 'HOST_USERS: "[^"]*"' docker-compose.yml | sed -E 's/HOST_USERS: "(.*)"/\1/')
EXEC_USERS=${EXEC_USERS:-$(for s in $users; do echo "${s%%:*}"; done | grep -v '^root$' | tr '\n' ' ')}
ORIG_LISTEN=$(cat conf/.original-listen)
step() { echo "== $*"; }
fail() { echo "!! $*，停止（已完成的步骤见上方，回滚见 README）"; exit 1; }

step "0. 保存回滚用的 Remi RPM"
mkdir -p $B/rpms
# 只从这些包原来的仓库下载（例如默认禁用的 phpup-remi-php72），可用 ROLLBACK_REPOS 指定
repos=${ROLLBACK_REPOS:-$(yum list installed $(cat $B/rpm-php.txt) 2>/dev/null | awk 'NR>1 && $3 ~ /^@/{sub(/^@/, "", $3); print $3}' | sort -u | paste -sd, -)}
echo "   仓库: ${repos:-（未识别，用已启用的仓库）}"
yum reinstall -y -q --downloadonly --downloaddir=$B/rpms ${repos:+--disablerepo=* --enablerepo=$repos} $(cat $B/rpm-php.txt) >/dev/null 2>&1
n=$(ls $B/rpms/*.rpm 2>/dev/null | wc -l); echo "   $n 个"
[ "$n" -ge "$(wc -l < $B/rpm-php.txt)" ] || fail "RPM 未保存完整"

step "1. 切换前基线"
bash "$PROBE" < "$PROBE_TARGETS" > $B/probe-before-cutover.tsv
supervisorctl status > $B/supervisor-before.txt 2>&1
echo "   探测 $(wc -l < $B/probe-before-cutover.tsv) 条 | 队列 $(awk '{print $2}' $B/supervisor-before.txt | sort | uniq -c | tr -s ' ' | tr '\n' ',')"

step "2. FPM 切到容器（$ORIG_LISTEN）"
sed -i -E "s#^listen = .*#listen = $ORIG_LISTEN#" conf/www.conf
sed -i 's#error-container.log#error.log#' conf/php-fpm.conf
T0=$(date +%s%N)
systemctl stop php-fpm
$DC restart php72-fpm >/dev/null 2>&1
for i in $(seq 1 100); do ss -ltn | grep -q " ${ORIG_LISTEN} " && break; sleep 0.1; done
ss -ltnp | grep " ${ORIG_LISTEN} " | grep -q php-fpm7.2 || { systemctl start php-fpm; fail "容器 FPM 没有接管 $ORIG_LISTEN，已重新启动宿主机 FPM"; }
echo "   恢复用时 $(( ($(date +%s%N) - T0) / 1000000 ))ms"
systemctl disable php-fpm >/dev/null 2>&1
if grep -qE '^[^#]*\b(php-fpm|supervisord)\b' /etc/rc.d/rc.local 2>/dev/null; then
  cp -p /etc/rc.d/rc.local $B/rc.local.before-cutover
  sed -i -E 's@^([^#]*\b(php-fpm|supervisord)\b.*)$@# 已迁到 php72 容器（见 /data/php72-runtime/README.txt）: \1@' /etc/rc.d/rc.local
  echo "   rc.local 里启动 php-fpm/supervisord 的行已注释，原文件 $B/rc.local.before-cutover"
fi

step "3. 队列（supervisord）切到容器"
T1=$(date +%s)
timeout 300 supervisorctl stop all > $B/supervisor-stop.txt 2>&1
echo "   旧队列停止用时 $(( $(date +%s) - T1 ))s"
systemctl stop supervisord; systemctl disable supervisord >/dev/null 2>&1
for u in supervisor.service; do
  if [ -f /etc/systemd/system/$u ]; then
    systemctl disable --now $u >/dev/null 2>&1; mv /etc/systemd/system/$u $B/; systemctl daemon-reload
    echo "   移除了重复的 $u（与 supervisord.service 争抢同一个 socket）"
  fi
done
$DC up -d php72-cli >/dev/null 2>&1
want=$(grep -c RUNNING $B/supervisor-before.txt)
for i in $(seq 1 90); do [ "$(supervisorctl status 2>/dev/null | grep -c RUNNING)" -ge "$want" ] && break; sleep 1; done
supervisorctl status > $B/supervisor-after.txt 2>&1
echo "   容器 supervisord $(supervisorctl version 2>&1) | $(awk '{print $2}' $B/supervisor-after.txt | sort | uniq -c | tr -s ' ' | tr '\n' ',') | 切换前 RUNNING=$want"

step "4. 删除 Remi PHP，/usr/bin/php 改为转发"
for d in /var/lib/php/session /var/lib/php/wsdlcache; do [ -d $d ] && touch $d/.keep; done
mounts=$(awk '/^  php72-cli:/{c=1} c && /^      - \//{split($2, a, ":"); print a[1]}' docker-compose.yml | grep -vE '^/(etc|var/run|var/log/supervisor|usr/share/fonts)' | tr '\n' ' ')
printf 'MOUNTS="%s"\nCONTAINER=php72-cli\n' "$mounts" > /etc/php72-exec.conf
install -m 755 $D/php72-exec /usr/local/bin/php72-exec
{
  echo '# 允许这些用户的定时任务经 /usr/bin/php 在 php72-cli 容器里以自己的身份执行 PHP（只放行这一个脚本）'
  echo 'Defaults!/usr/local/bin/php72-exec !requiretty, !syslog, !pam_session, env_keep += "PHP72_STDIN"'
  for u in $EXEC_USERS; do echo "$u ALL=(root) NOPASSWD: /usr/local/bin/php72-exec"; done
} > /tmp/php72-sudoers
visudo -cf /tmp/php72-sudoers >/dev/null || fail "sudoers 校验失败"
install -m 440 /tmp/php72-sudoers /etc/sudoers.d/php72-exec; rm -f /tmp/php72-sudoers
for f in /etc/init.d/php-fpm; do
  if [ -f $f ] && grep -q 'prefix=/usr/local/php' $f; then chkconfig --del php-fpm 2>/dev/null; mv $f $B/init.d-php-fpm.old; echo "   移除了指向旧路径的 $f"; fi
done
# 删除 Remi 到装好转发脚本之间没有 /usr/bin/php；等到某分钟的第 5 秒再开始，避开整分钟触发的定时任务
while [ "$(date +%-S)" -lt 5 ] || [ "$(date +%-S)" -gt 15 ]; do sleep 1; done
T2=$(date +%s%N)
yum remove -y -q $(cat $B/rpm-php.txt) >/dev/null 2>&1
install -m 755 $D/php /usr/bin/php; hash -r
echo "   没有 /usr/bin/php 的时间 $(( ($(date +%s%N) - T2) / 1000000 ))ms（$(date +%T) 结束）"
# 用 env -i 模拟 cron 的干净环境：转发脚本或 /etc/php72-exec.conf 依赖了当前 shell 的变量时，这里会报错
echo "   剩余 php 包: $(rpm -qa 'php*' | wc -l) | root: $(env -i PATH=/usr/bin:/bin /usr/bin/php -r 'echo posix_geteuid(), " ", PHP_VERSION;' 2>&1 | cut -c1-80)"
for u in $EXEC_USERS; do echo "   $u: $(env -i PATH=/usr/bin:/bin sudo -u $u /usr/bin/php -r 'echo posix_geteuid(), " ", PHP_VERSION;' 2>&1 | cut -c1-80)"; done
mv /etc/php.ini.rpmsave $B/ 2>/dev/null; true

step "5. 切换后验证"
bash "$PROBE" < "$PROBE_TARGETS" > $B/probe-after-cutover.tsv
echo "   探测 $(wc -l < $B/probe-after-cutover.tsv) 条（用 tools/probe_compare.py 对比 probe-before/after-cutover.tsv）"
echo "   容器: $(docker ps --filter name=php72 --format '{{.Names}}={{.Status}}' | tr '\n' ' ')"
echo "   开机: docker=$(systemctl is-enabled docker) supervisord=$(systemctl is-enabled supervisord) php-fpm=$(systemctl is-enabled php-fpm 2>&1 | tail -1)"
