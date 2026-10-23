# Release v20261023 — 生产升级实施记录、复查与勘误

**发布日期**：2026-10-23
**性质**：文档、变体镜像定义（Dockerfile 与配置）和工具。**不包含任何二进制或镜像制品**。补丁状态为 `UNVERIFIED`，本版本不构成安全声明。

## 主要内容

- **[docs/12](docs/12-生产升级实施经验-20261022.md)**：2026-10-22 测试与生产 PHP 运行时升级的实施记录。
  - CentOS 7 宿主机（Remi）：FPM 运行用户、扩展与 ini 的对齐方法，无中断换包，回滚准备。
  - 容器主机：两个兼容变体镜像，新旧 FPM 并行对比，网关的容器名解析缓存，compose 细节。
  - 10-23 复查：发现 6 个遗漏并处理；FPM 运行态探针；只读入侵排查的清单与结论；勘误；后续事项。
- **变体镜像定义**
  - [`variants/php72-fpm-bitnami-compat`](variants/php72-fpm-bitnami-compat/README.md)：只运行 FPM，替换 bitnami-full 7.2 镜像。Sury 7.2.34-66，phpredis 5.3.7。
  - [`variants/php74-apache-webdevops-compat`](variants/php74-apache-webdevops-compat/README.md)：Apache + PHP 7.4，兼容 webdevops 的目录结构。Sury 7.4.33-31。
- **工具**：[`tools/fcgi_compare.py`](tools/fcgi_compare.py) 向新旧两个 FPM 发送相同的只读 FastCGI GET 请求，比较返回结果，附 8 个单元测试。

## 补丁状态（CVE-2026-109618 / CVE-2026-109619）

| 运行时 | 版本 | 状态 |
|---|---|---|
| Sury PHP 7.2（Debian 12） | `7.2.34-66+0~20261021.122+debian12~1.gbpe0bcd4` | changelog 列出回移条目，`UNVERIFIED` |
| Sury PHP 7.4（Debian 12） | `1:7.4.33-31+0~20261021.121+debian12~1.gbpe9c428` | changelog 列出回移条目，`UNVERIFIED` |
| Ubuntu 24.04 php8.3 | `8.3.6-0ubuntu0.24.04.13` | changelog 列出 `CVE-2026-109618_109619.patch`，`UNVERIFIED` |
| Remi EL7 | `php-7.2.34-22.el7.remi` | **不包含**（changelog 最后一条是 2024-06-04） |

`UNVERIFIED` 表示只核对了供应商 changelog，补丁没有逐行审计，也没有做针对性的漏洞回归。

## 勘误

- `Redis::delete()` 在 phpredis 5.x 和 6.x 中都存在，都已 deprecated。ThinkPHP 5.0.24 的 Redis 缓存 `rm()` 在 5.3.7 和 6.0.2 上抛出同样的异常，所以这是既有问题，与升级无关。此前"6.x 删除了该方法"的说法有误。
- 仓库里的 `RELEASE_NOTES_v20261022.md`（对应 tag `v20261022`，没有作为 GitHub Release 发布）以及根目录的总结类文档中，"CVE 已修复 / 验证通过"等说法证据不足，组件版本也与实测不符。相关文件顶部已加勘误提示，以 [README 勘误](README.md#勘误2026-10-23) 为准。

## 已知限制

- 业务回归只覆盖了入口页和公开页面。登录、业务流程、队列消费的回归，压测，以及真实回滚演练，都还没有完成。
- 变体镜像只在实施环境中本地构建，没有推送到任何公共仓库。本仓库不提供二进制。
- 使用 Remi EL7 构建的 CentOS 7 主机仍然缺这两个补丁，处理方案见 [docs/12 §12.10](docs/12-生产升级实施经验-20261022.md#1210-后续事项)。

## 验证

- `python3 -m unittest discover -s tests`：`Ran 31 tests ... OK`
- `python3 tools/check_docs.py`：`PASS: local Markdown file links/fences and JSON syntax; not runtime/security validation.`
