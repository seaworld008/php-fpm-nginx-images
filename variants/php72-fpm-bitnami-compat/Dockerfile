# syntax=docker/dockerfile:1
# 生产容器主机 openresty 项目: php72 + php72-queue-wechat-msg 专用 (FPM-only)
# 替换 114.115.130.46/jlkj-base/php-fpm:7.2.34-bitnami-full (2021-01 构建)
# PHP 二进制沿用 wyveo-nginx-php-fpm-7.2.34:v20261022 (Sury 7.2.34-66; changelog 列出 CVE-2026-109618/109619 回移条目, 补丁状态 UNVERIFIED)
ARG BASE=114.115.130.46/jlkj-base/wyveo-nginx-php-fpm-7.2.34:v20261022
ARG PHPV=7.2.34-66+0~20261021.122+debian12~1.gbpe0bcd4

# phpredis 5.3.7: 与原 bitnami-full 镜像 (5.3.5) 保持同一主版本; Redis::delete() 在 5.x/6.x 中都存在且已 deprecated, 见 docs/12 §12.9
FROM ${BASE} AS redis5
ARG PHPV
RUN set -eux; apt-get update; \
    apt-get install -y --no-install-recommends php7.2-dev=${PHPV} build-essential autoconf pkg-config; \
    curl -fsSL -o /tmp/redis.tgz https://pecl.php.net/get/redis-5.3.7.tgz; \
    mkdir /tmp/redis && tar xzf /tmp/redis.tgz -C /tmp/redis --strip-components=1; cd /tmp/redis; \
    phpize7.2; ./configure --with-php-config=/usr/bin/php-config7.2; make -j"$(nproc)"; \
    cp modules/redis.so /redis.so

FROM ${BASE}
ARG PHPV
LABEL jlkj.php.package="${PHPV}" jlkj.php.redis="5.3.7" jlkj.replaces="114.115.130.46/jlkj-base/php-fpm:7.2.34-bitnami-full"
# 补齐原 bitnami-full 有而基础镜像没有的扩展 (ionCube / vips 经核查应用未使用, 不再引入)
RUN set -eux; apt-get update; \
    apt-get install -y --no-install-recommends \
      php7.2-soap=${PHPV} php7.2-ldap=${PHPV} php7.2-tidy=${PHPV} php7.2-xmlrpc=${PHPV} php7.2-amqp php7.2-apcu; \
    apt-get purge -y php7.2-redis; rm -rf /var/lib/apt/lists/*; \
    test "$(dpkg-query -W -f '${Version}' php7.2-fpm)" = "${PHPV}"
COPY --from=redis5 /redis.so /usr/lib/php/20170718/redis.so
COPY php-fpm.conf /etc/php/7.2/fpm/php-fpm.conf
COPY www-jlkj.conf /tmp/www-jlkj.conf
COPY zz-jlkj-runtime.ini /etc/php/7.2/mods-available/zz-jlkj-runtime.ini
COPY zz-jlkj-parity.ini /etc/php/7.2/mods-available/zz-jlkj-parity.ini
RUN set -eux; \
    printf '; priority=20\nextension=redis.so\n' > /etc/php/7.2/mods-available/redis.ini; \
    phpenmod -v 7.2 -s ALL redis zz-jlkj-runtime zz-jlkj-parity; \
    rm -f /etc/php/7.2/fpm/pool.d/*.conf; mv /tmp/www-jlkj.conf /etc/php/7.2/fpm/pool.d/www-jlkj.conf; \
    groupadd -g 1000 application; useradd -u 1000 -g application -m -s /bin/sh application; \
    mkdir -p /run/php; \
    php-fpm7.2 -t -y /etc/php/7.2/fpm/php-fpm.conf; php -v; php -m >/dev/null
HEALTHCHECK NONE
EXPOSE 9000
ENTRYPOINT []
CMD ["php-fpm7.2", "-F", "-y", "/etc/php/7.2/fpm/php-fpm.conf"]
