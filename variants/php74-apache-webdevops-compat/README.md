# php74-apache-webdevops-compat

替换 `webdevops/php-apache:7.4`（PHP 7.4.26 / Debian 10 / Apache 2.4.38）。目录结构与 webdevops 兼容，原来挂载的 vhost 配置和 php.ini 不用改。

- 基础：`debian:bookworm-slim` + Sury `php7.4 1:7.4.33-31+0~20261021.121+debian12~1.gbpe9c428` + Debian Apache 2.4.68。
- 补丁状态：`UNVERIFIED`。Sury changelog 列出了 CVE-2026-109618/109619 的回移条目，补丁本身未审计。见 [docs/12](../../docs/12-生产升级实施经验-20261022.md#122-补丁状态与证据)。
- 2026-10-22 构建并部署的镜像 ID：`sha256:ab6d5697b9fa3e2deb5dc73da94fa1ac50973240194f6499fc5d16e0c90b0c9a`，标签 `114.115.130.46/jlkj-base/php-apache:7.4.33-sury-20261021`。该标签**尚未推送**。

## 兼容的挂载点

| 路径 | 用途 |
|---|---|
| `/opt/docker/etc/httpd/conf.d/*.conf` | 业务 vhost，通过 `main.conf` 引入；先于内置的 `docker.vm` vhost 加载，即为默认站点 |
| `/opt/docker/etc/php/php.ini` | 以 `99-docker.ini` 生效（FPM 和 CLI） |
| `/app`、`/app/logs` | 代码和日志目录 |

## 与 webdevops 的差异

- 不加载 php.ini，只用内置默认值，加上 `98-webdevops.ini`（webdevops 原值）和 `99-docker.ini`，与原镜像一致。`zz-jlkj-parity.ini` 把 Sury 的 `memcached.serializer`（igbinary）对齐回 `php`。
- FPM 池：`application`(1000)、`127.0.0.1:9000`、pm 5/2/1/3，与原值一致。
- 进程：用 tini 启动 `entrypoint.sh`，同时运行 FPM 和 Apache，任一进程退出整个容器就退出。不再运行 supervisord、cron、syslog-ng、postfix（原容器里没有定时任务，应用也不发邮件）。
- 扩展：去掉 ionCube、vips（已核查应用未使用）；FPM 下没有 pcntl（Sury 只给 CLI 提供 pcntl）；新增 ffi、igbinary、msgpack。
- 不启用 443/SSL：原镜像的 443 用的是自签证书，而且没有对外映射。

## 构建与部署

```bash
docker build -t 114.115.130.46/jlkj-base/php-apache:7.4.33-sury-20261021 .
# compose 中只改 image:，然后执行
docker compose up -d
```

**如果网关按容器名转发**（例如 `proxy_pass http://wslndx_web1:80`），容器重建后必须立即重载网关，否则网关会继续发往旧 IP：

```bash
docker exec <网关容器> openresty -t && docker exec <网关容器> openresty -s reload
```

## 验证（2026-10-22 实测）

- 本地链路：Apache 到 FPM 正常，`.htaccess` 伪静态正常，`info.php` 直接访问返回 403，compose 健康检查通过，`docker stop` 0.3 秒退出。
- 生产容器主机上并行对比：访问日志里的 15 个真实页面，新旧状态码和字节数全部一致。切换后经网关访问 200（重载网关之后）。

| 步骤 | 状态 |
|---|---|
| 1 来源 / 包 | Sury 签名包，版本锁定 |
| 2 CVE 证据 | 只核对了 changelog（`UNVERIFIED`） |
| 3 构建 | 已完成（本地构建，未推送） |
| 4 真实 FPM 链路 | 已验证 |
| 5 业务回归 | 部分：只验证了公开页面，未做后台和表单 |
| 6 压测 / 回滚演练 | 未完成 |
| 7 授权部署 | 已部署到生产容器主机 |
