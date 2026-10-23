# Release v20261023.1 — 宿主机 nginx 平滑升级与 PHP 容器化

**发布日期**：2026-10-23
**性质**：文档、变体镜像定义（Dockerfile、入口脚本、实施工具包）和工具。**不包含任何二进制或镜像制品**。补丁状态为 `UNVERIFIED`，本版本不构成安全声明。

## 主要内容

- **[docs/13](docs/13-宿主机nginx升级与PHP容器化-20261023.md)**：2026-10-23 的实施记录。
  - 源码编译的 nginx 平滑升级：1.16.1 + OpenSSL 1.1.1d → 1.30.6 + OpenSSL 3.5.9。沿用原编译参数，在相同的 CentOS 7 环境里编译，源码核对 PGP 签名，用 `USR2` → `WINCH` → `QUIT` 切换，零中断。
  - 宿主机 PHP 迁到容器：把 Remi `php-7.2.34-22.el7.remi`（不含 2026-10 补丁，Remi 已停止 EL7 构建）换成 Sury 7.2.34-66 容器，不改代码、nginx 配置、crontab 和目录。内容包括设计、7 个实施步骤、32 个踩过的坑、日常维护和回滚。
  - 两台测试主机、两台生产主机的实施记录（[§13.8](docs/13-宿主机nginx升级与PHP容器化-20261023.md#138-生产实施记录)）：
    - FPM 切换中断 0.76～2.2 秒，队列在 1 秒内停止后在容器中恢复。
    - 验证项：经 nginx 的全站对比、新旧 FPM 的 FastCGI 并行对比、实际生效配置、`think list`、队列、定时任务退出码，以及切换后的 5xx、P95 耗时和宿主机 CPU。
  - Jenkins 发布兼容性：四台主机的发布脚本只做 rsync、`chown`、`nginx -t`，opcache 在 2 秒内自动加载新代码；迁移后已有一次真实发布。
  - 实施中发现的既有问题及处理原则：不改变业务数据和业务行为，先备份再改，涉及资金的任务只停用、不修复。
- **变体 [`variants/php72-host-compat`](variants/php72-host-compat/README.md)（r2）**：
  - 同一个镜像既可以跑 php-fpm，也可以跑 supervisord。tini 作为 1 号进程。
  - 入口脚本按 `HOST_USERS` 建立与宿主机 uid 相同的账号；镜像自带的同名或同 id 账号会先让位。按 `PHP_DISABLE_EXT` 关闭宿主机上没有的扩展。
  - 加装同一版本的 php7.2-dba、php7.2-recode。
  - `kit/`：
    - `setup-runtime.sh`：并行验证。自动选择 compose v1/v2，按 `PrivateTmp` 和慢日志配置决定是否挂载 /tmp、是否添加 `SYS_PTRACE`。
    - `cutover.sh`：切换。从原仓库保存回滚 RPM，删除旧包的时机避开整分钟，用 `env -i` 验证转发脚本。
    - `/usr/bin/php` 转发脚本、sudo 规则和运维说明。
- **工具**（都附单元测试）：
  - [`tools/nginx_targets.py`](tools/nginx_targets.py)：从 `nginx -T` 生成探测目标；`--prefix` 支持以 `nginx -p` 启动的配置。
  - [`tools/http_probe.sh`](tools/http_probe.sh) 和 [`tools/probe_compare.py`](tools/probe_compare.py)：变更前后的全站探测与对比。
  - [`tools/ini_parity.py`](tools/ini_parity.py)：对比新旧环境的实际生效配置，生成补齐文件；"只有新环境才有"的指令不写入。

## 补丁状态（CVE-2026-109618 / CVE-2026-109619）

与 [v20261023](https://github.com/seaworld008/php-fpm-nginx-images/releases/tag/v20261023) 相同：Sury PHP 7.2/7.4 和 Ubuntu php8.3 的 changelog 列出了回移条目，状态为 `UNVERIFIED`；Remi EL7 `php-7.2.34-22.el7.remi` **不包含**这两项。本次实施的四台 CentOS 7 主机已不再安装 Remi PHP。

## 已知限制

- 登录和业务流程没有逐项回归；没有做压测，也没有实际演练回滚（回滚包和配置已备份）。
- 镜像只在实施环境中本地构建，用 `docker save` / `docker load` 分发，没有推送到任何仓库。
- 宿主机上 `#!/usr/bin/env php` 开头、又不在挂载目录里的脚本（例如 `/usr/local/bin/composer`），经转发后会找不到文件。处理方法见 docs/13 §13.6。
- 有一个迁移前就一直失败、且涉及资金的定时任务，已在业务负责人确认后停用。它积压的记录需要业务方核对，详见 §13.8。

## 验证

- `python3 -m unittest discover -s tests`：`Ran 48 tests ... OK`
- `python3 tools/check_docs.py`：`PASS: local Markdown file links/fences and JSON syntax; not runtime/security validation.`
