# php72-fpm-bitnami-compat

替换 `114.115.130.46/jlkj-base/php-fpm:7.2.34-bitnami-full`（2021-01 构建，只运行 FPM），供生产容器主机上 openresty 项目的 `php72` 服务和 `php72-queue-wechat-msg` 队列使用。

- 基础镜像：`wyveo-nginx-php-fpm-7.2.34:v20261022`，PHP 二进制不变，是 Sury `7.2.34-66+0~20261021.122+debian12~1.gbpe0bcd4`。
- 补丁状态：`UNVERIFIED`。Sury changelog 列出了 CVE-2026-109618/109619 的回移条目，补丁本身未审计。见 [docs/12](../../docs/12-生产升级实施经验-20261022.md#122-补丁状态与证据)。
- 2026-10-22 构建并部署的镜像 ID：`sha256:5f04db691f45a293c146a8238c185212526779c288b3735c1aca0dd80c51d4e0`，标签 `114.115.130.46/jlkj-base/php-fpm:7.2.34-sury-20261021`。该标签**尚未推送**到私有仓库。

## 与原 bitnami-full 镜像的差异

| 项目 | 原镜像 | 本镜像 |
|---|---|---|
| 运行方式 | 入口脚本 + `php-fpm -F`，以 root 运行 master | `php-fpm7.2 -F`，`ENTRYPOINT []`，`HEALTHCHECK NONE` |
| 监听 / 用户 | `0.0.0.0:9000` / `application`(1000) | 相同（见 `www-jlkj.conf`） |
| 运行时 ini | `zz-jlkj-runtime.ini` | 相同，另加 `zz-jlkj-parity.ini` 对齐 Debian/Sury 默认值的差异 |
| redis 扩展 | 5.3.5 | **5.3.7**（源码编译）。Sury 只提供 6.x，而 6.x 删除了 `Redis::delete()`，ThinkPHP 5.0 的缓存和 Session 驱动依赖它 |
| 扩展 | 69 个 | 70 个。去掉 ionCube、vips（已核查应用未使用）；新增 igbinary、msgpack、swoole、wddx |
| 有意保留的差异 | `opcache.revalidate_freq=60`，`max_accelerated_files=4000` | 2 和 10000 |

## 构建

```bash
docker build -t 114.115.130.46/jlkj-base/php-fpm:7.2.34-sury-20261021 .
docker run --rm --entrypoint php-fpm7.2 114.115.130.46/jlkj-base/php-fpm:7.2.34-sury-20261021 -i > new_fpm_ini.txt   # 与旧镜像逐项对比
```

## 部署（docker compose）

只把服务的 `image:` 改成新标签，其余配置不动。保持多副本数量并且不牵动网关：

```bash
docker compose up -d --no-deps php72
docker compose up -d --no-deps --scale php72-queue-wechat-msg=4 php72-queue-wechat-msg
```

回滚：恢复 compose 文件里的旧镜像名，再执行同样的命令。旧镜像在本机保留 1-2 周。

## 验证

1. 先起一个只监听本机端口的测试容器（挂载和安全选项与线上相同），再并行对比：
   ```bash
   python3 tools/fcgi_compare.py --old HOST:9000 --new 127.0.0.1:19000 --scan /data/openresty/html /usr/local/openresty/nginx/html
   ```
2. 队列：以 `su -s /bin/sh application -c "cd <应用> && php think list"` 验证 CLI 和用户切换，这一步不消费任务。
3. 切换后：经网关逐站点对比状态码；检查网关错误日志、`php72` 日志和队列日志。

## 发布状态（2026-10-22）

| 步骤 | 状态 |
|---|---|
| 1 来源 / 包 | Sury 签名包，版本锁定 |
| 2 CVE 证据 | 只核对了 changelog（`UNVERIFIED`） |
| 3 构建 | 已完成（本地构建，未推送） |
| 4 CLI + 真实 FPM | 已验证：10 个应用入口、13 个网关站点并行对比一致 |
| 5 业务回归 | 部分：只验证了入口页，未做登录和业务流程 |
| 6 压测 / 回滚演练 | 未完成 |
| 7 授权部署 | 已部署到生产容器主机 |
