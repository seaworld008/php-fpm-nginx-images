# Changelog

## 2026-10-23 — 宿主机 nginx 升级与 PHP 容器化

- 新增 [docs/13](docs/13-宿主机nginx升级与PHP容器化-20261023.md)：源码编译 nginx 的平滑升级（1.16.1 → 1.30.6，OpenSSL 3.5.9）；把宿主机 Remi PHP 迁到容器的设计、步骤、17 个踩过的坑、日常维护和回滚。
- 新增变体 [`variants/php72-host-compat`](variants/php72-host-compat/README.md)：同一镜像跑 php-fpm 或 supervisord，按环境变量建立与宿主机 uid 相同的用户、关闭宿主机上没有的扩展；`kit/` 提供 `setup-runtime.sh`、`cutover.sh`、`/usr/bin/php` 转发脚本和运维说明。
- 新增工具及测试：`tools/nginx_targets.py`、`tools/http_probe.sh`、`tools/probe_compare.py`、`tools/ini_parity.py`。`ini_parity.py` 对"只有新环境才有"的指令只给提示，不写入。
- 生产两台（P1、P2）完成迁移，过程与验证见 [docs/13 §13.8](docs/13-宿主机nginx升级与PHP容器化-20261023.md#138-生产实施记录)；新增踩坑记录 #18～#32。
- `php72-host-compat` r2：
  - 入口脚本先删除与宿主机账号同名或同 id 的镜像账号，再建立宿主机账号；重启容器时不再调用账号工具。
  - 加装同一版本的 `php7.2-dba`、`php7.2-recode`。
- `kit/` 改进：
  - compose v1/v2 自动选择。
  - 根据 `PrivateTmp` 和慢日志配置，自动挂载 /tmp、添加 `SYS_PTRACE`。
  - 补齐文件以 0644 安装。
  - 回滚用 RPM 从原仓库下载。
  - 注释 rc.local 里启动 php-fpm 的行。
  - 删除 Remi 的时机避开整分钟触发的定时任务。
  - 用 `env -i` 验证转发脚本。
- `tools/nginx_targets.py` 新增 `--prefix`，支持以 `nginx -p` 启动、root 为相对路径的配置。

## 2026-10-23 — 复查、只读入侵排查与勘误

- [docs/12](docs/12-生产升级实施经验-20261022.md) 新增 12.6～12.10：
  - 复查发现的 6 个遗漏及处理方法：ini 和池配置未迁移、cron 调用的脚本里写死旧路径、宿主机自带的 php8.3、手工编译的扩展、CI 业务镜像仍用旧基础镜像、遗留的后台脚本。
  - FPM 运行态探针。
  - 只读入侵排查清单与结论（六台主机未发现入侵迹象，并写明局限）。
  - 勘误与后续事项。
- 勘误：`Redis::delete()` 在 phpredis 5.x 和 6.x 中都存在，都已 deprecated。ThinkPHP 5.0.24 的 Redis 缓存 `rm()` 在 5.3.7 和 6.0.2 上抛出同样的异常，所以这是既有问题，不是升级引入的。已同步修正变体 README 和 Dockerfile 注释。
- 勘误：根目录总结类文档中"CVE 已修复 / 验证通过"的说法以 `UNVERIFIED` 为准；补充 `v20261022` 镜像的实测组件版本。相关文档顶部已加勘误提示。
- 修复 3 个失效的本地链接，`tools/check_docs.py` 已全部通过。

## 2026-10-22 — 生产升级实施记录

- 新增 [docs/12](docs/12-生产升级实施经验-20261022.md)：CentOS 7 宿主机（Remi）和容器主机升级的过程、问题与验证方法。
- 记录事实：Remi EL7 `7.2.34-22`（2024-06）**不含** CVE-2026-109618/109619 的回移；Sury 7.2.34-66、7.4.33-31 的 changelog 列出了这两项，补丁状态仍为 `UNVERIFIED`。
- 新增变体 `variants/php72-fpm-bitnami-compat`（FPM-only，phpredis 5.3.7，对齐 bitnami-full 的行为）和 `variants/php74-apache-webdevops-compat`（兼容 webdevops 目录结构的 Apache + PHP 7.4）。
- 新增 `tools/fcgi_compare.py` 及其测试：对新旧 FPM 发送相同的只读请求，逐项比较结果。
- ~~已知问题：`v20261022` 自带 phpredis 6.0.2，ThinkPHP 5.0 的 Redis 缓存和 Session 驱动依赖已被删除的 `Redis::delete()`。~~ 该说法有误，已在 2026-10-23 更正（见上）。

## 2026-10-22 — 初始公开方案

- 将私有容器重建任务整理为公开工程文档，移除组织、地址和生产配置。
- 保留 PHP 7.2.34 回移、Nginx stable、扩展兼容、资源预算及安全证据门禁。
- 新增 APT/RPM、本机源码并行安装、面板管理及 CLI/常驻 worker 修复路径。
- 增加只读清单工具、文档检查、测试、贡献与安全政策。
- 明确此版本尚未交付修复镜像、二进制或经验证的通用补丁，不创建误导性“安全版本”标签。
