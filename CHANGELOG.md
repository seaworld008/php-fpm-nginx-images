# Changelog

## 2026-10-22 — 生产升级实施记录

- 新增 [docs/12](docs/12-生产升级实施经验-20261022.md)：CentOS 7 宿主机（Remi）和容器主机升级的过程、问题与验证方法。
- 记录事实：Remi EL7 `7.2.34-22`（2024-06）**不含** CVE-2026-109618/109619 的回移；Sury 7.2.34-66、7.4.33-31 的 changelog 列出了这两项，补丁状态仍为 `UNVERIFIED`。
- 新增变体 `variants/php72-fpm-bitnami-compat`（FPM-only，phpredis 5.3.7，对齐 bitnami-full 的行为）和 `variants/php74-apache-webdevops-compat`（兼容 webdevops 目录结构的 Apache + PHP 7.4）。
- 新增 `tools/fcgi_compare.py` 及其测试：对新旧 FPM 发送相同的只读请求，逐项比较结果。
- 已知问题：`v20261022` 自带 phpredis 6.0.2，ThinkPHP 5.0 的 Redis 缓存和 Session 驱动依赖已被删除的 `Redis::delete()`。

## 2026-10-22 — 初始公开方案

- 将私有容器重建任务整理为公开工程文档，移除组织、地址和生产配置。
- 保留 PHP 7.2.34 回移、Nginx stable、扩展兼容、资源预算及安全证据门禁。
- 新增 APT/RPM、本机源码并行安装、面板管理及 CLI/常驻 worker 修复路径。
- 增加只读清单工具、文档检查、测试、贡献与安全政策。
- 明确此版本尚未交付修复镜像、二进制或经验证的通用补丁，不创建误导性“安全版本”标签。
