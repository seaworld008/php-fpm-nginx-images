# syntax=docker/dockerfile:1
# 把 CentOS 7 宿主机上的 Remi PHP 7.2.34-22（不含 2026-10 补丁）换成容器。
# 同一个镜像既可以跑 php-fpm，也可以跑 supervisord（队列）；php.ini、FPM 池、supervisord 配置都从宿主机挂载，
# 网络用 host，代码和日志路径与宿主机一致。
ARG BASE=114.115.130.46/jlkj-base/php-fpm:7.2.34-sury-20261021
FROM ${BASE}
RUN set -eux; \
    apt-get update; apt-get install -y --no-install-recommends tini; rm -rf /var/lib/apt/lists/*; \
    phpdismod -v 7.2 -s ALL zz-jlkj-runtime zz-jlkj-parity; \
    rm -f /etc/php/7.2/fpm/pool.d/*.conf /etc/php/7.2/fpm/conf.d/99-production.ini; \
    phpdismod -v 7.2 -s fpm readline; \
    mkdir -p /run/php /var/log/php-fpm /var/run/supervisor /var/log/supervisor
COPY host-compat-entrypoint.sh /usr/local/bin/host-compat-entrypoint
RUN chmod 755 /usr/local/bin/host-compat-entrypoint
LABEL jlkj.variant="php72-host-compat" \
      jlkj.php.package="7.2.34-66+0~20261021.122+debian12~1.gbpe0bcd4" \
      jlkj.php.redis="5.3.7"
HEALTHCHECK NONE
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/host-compat-entrypoint"]
CMD ["php-fpm"]
