# php72-host-compat

把 CentOS 7 宿主机上安装的 PHP 7.2 换成容器，不改 nginx 配置、crontab、代码目录和日志路径。适用于用 Remi `php-7.2.34-22.el7.remi` 的主机：这个版本不含 2026-10 的补丁，而 Remi 已停止 EL7 构建（见 [docs/12 §12.2](../../docs/12-生产升级实施经验-20261022.md#122-补丁状态与证据)）。

- 基础镜像：[`php72-fpm-bitnami-compat`](../php72-fpm-bitnami-compat/README.md)，即 Sury `7.2.34-66+0~20261021.122+debian12~1.gbpe0bcd4` 加源码编译的 phpredis 5.3.7。补丁状态为 `UNVERIFIED`，只核对了 changelog。
- 在基础镜像上增加的内容：
  - tini 作为 1 号进程，负责回收 `popen("php ... &")` 这类后台进程。
  - 入口脚本 `host-compat-entrypoint.sh`。
- 在基础镜像上去掉的内容：
  - 基础镜像自带的 `99-production.ini`，以及 41 专用的两个 ini。
  - FPM 中的 readline。
- 完整的实施过程与踩过的坑见 [docs/13](../../docs/13-宿主机nginx升级与PHP容器化-20261023.md)。

## 工作方式

同一个镜像启动两个容器，都使用 `network_mode: host` 和 `restart: always`：

| 容器 | 命令 | 作用 |
|---|---|---|
| `php72-fpm` | `php-fpm` | 监听宿主机原来的地址（如 `127.0.0.1:9000`），nginx 配置不变 |
| `php72-cli` | `supervisord` | **直接使用宿主机的 `/etc/supervisord.conf` 和 `/etc/supervisord.d`**。socket（`/var/run/supervisor`）和日志（`/var/log/supervisor`）都挂载自宿主机，所以宿主机上的 `supervisorctl`、9001 管理端口和监控脚本照常可用 |

- 宿主机的 `/usr/bin/php` 换成转发脚本 [`kit/php`](kit/php)，它调用 [`kit/php72-exec`](kit/php72-exec)，后者执行 `docker exec -u 调用者 -w 当前目录 php72-cli php …`，所以 crontab、发布脚本和手工命令都不用改。
  - root 直接执行。
  - 其他用户（例如 www）通过 `/etc/sudoers.d/php72-exec` 执行，这条规则只放行这一个脚本。
- 入口脚本读取两个环境变量：
  - `HOST_USERS="名称:uid:gid[:附加gid]"`：在容器里建立与宿主机 uid 相同的用户，写出的文件属主不变。
  - `PHP_DISABLE_EXT`：关掉宿主机上没有加载的扩展。
- php.ini 和 FPM 池是宿主机原文件的副本。剩余差异由 [`tools/ini_parity.py`](../../tools/ini_parity.py) 对比新旧环境的实际生效配置后生成补齐文件。

## 工具包 `kit/`

| 文件 | 用途 |
|---|---|
| `setup-runtime.sh` | 第 1 步：建立 `/data/php72-runtime`，用测试地址启动 `php72-fpm`，与宿主机 FPM 并行运行，不影响线上 |
| `cutover.sh` | 第 2 步：保存回滚用 RPM → 记录基线 → 切换 FPM → 切换 supervisord → 删除 Remi PHP → 安装转发脚本 → 再次探测 |
| `php`、`php72-exec`、`sudoers-php72.example` | 转发脚本及其 sudo 规则 |
| `ini_dump.php`、`fcgi_get.php` | 通过真实的 SAPI 导出实际生效配置：FPM 用 FastCGI 请求，CLI 直接执行 |
| `README.runtime.txt` | 放到主机 `/data/php72-runtime/README.txt` 的运维说明 |

另外还用到这几个工具：[`tools/nginx_targets.py`](../../tools/nginx_targets.py)、[`tools/http_probe.sh`](../../tools/http_probe.sh)、[`tools/probe_compare.py`](../../tools/probe_compare.py)、[`tools/fcgi_compare.py`](../../tools/fcgi_compare.py)。

## 限制

- `/etc/supervisord.d` 里只能放 PHP 程序，容器里没有 node、python、java。
- 程序路径、脚本路径和日志路径必须在挂载目录之下。
- 运行用户必须事先写在 `HOST_USERS` 里。
- 用管道给 php 传数据时要写 `PHP72_STDIN=1`。`docker exec -i` 会把调用方的标准输入全部读走，原生 php 不会，所以转发脚本只在交互终端下接管标准输入。
- 主配置 `/etc/supervisord.conf` 以单个文件的方式挂载，修改后要执行 `docker restart php72-cli`。

## 发布状态（2026-10-23）

| 步骤 | 状态 |
|---|---|
| 1 来源 / 包 | 与基础镜像相同（Sury 签名包，版本锁定） |
| 2 CVE 证据 | 只核对了 changelog，状态 `UNVERIFIED` |
| 3 构建 | 已完成，在本地构建，没有推送 |
| 4 CLI + 真实 FPM | 已验证：两台测试主机经 nginx 的全站对比全部一致，新旧 FPM 并行对比一致 |
| 5 业务回归 | 部分完成：入口页、队列、定时任务已验证，登录和业务流程没有验证 |
| 6 压测 / 回滚演练 | 回滚包和配置已备份，没有实际演练 |
| 7 授权部署 | 已部署到两台测试主机，生产两台见 docs/13 |
