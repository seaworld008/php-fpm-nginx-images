# 1. 安全事实、补丁证据与来源

核验日期：**2026-10-22**。外部页面可能更新；正式构建必须再次查证并保存版本化证据。

## 1.1 本次已核实的外部事实

| 项目 | 核实范围 | 不应推出的结论 |
|---|---|---|
| PHP 官方两份公告 | CVE-2026-109618 / CVE-2026-109619；正式修复分支列出 8.2.35、8.3.36、8.4.27、8.5.12 [S1–S3] | 不能把这些 PHP 8 包安装进 PHP 7.2 目录 |
| PHP EOL 说明 | 官方说明旧分支停止维护；本次提供 7.4/8.0/8.1 最小源码回移 [S1] | 不存在本项目已核实的“PHP 官方新版 7.2 安全发行版” |
| Sury PHP 7.2 目录 | 可见 `7.2.34-66+0~20261021.122+…` 候选构建 [S4] | 尚未验证匹配源包、签名到二进制和两个 CVE 的完整覆盖 |
| Nginx 下载/安全公告 | 当日 stable 为 1.30.6，mainline 为 1.31.8 [S6–S8] | 不保证未来仍是最新，不代表所有模块/运行库无漏洞 |

本仓库未下载并验证候选 PHP 二进制/匹配源包，未运行目标漏洞回归。网上出现的商业包、面板补丁或社区 guard 扩展不得仅凭名称列为本仓库支持制品。

## 1.2 证据链

维护者公告 → 对应源包/提交与补丁 → 签名仓库元数据 → 目标平台包哈希 → 实际安装文件/运行进程 → 隔离回归。

APT 的常规信任链是签名 InRelease/Release 及其索引哈希、包哈希，不是宣称每个 `.deb` 都有独立签名。RPM 需核验对应供应商密钥及包签名。原始签名、索引、哈希和版本应归档到受控制品库；公开报告必须脱敏。

PHP cli/fpm/common/opcache 及源包内模块应保持一致核心修订；PECL 扩展有自己的版本，不要求等于 PHP 包版本。不要把不同发行版、glibc/musl、架构或 NTS/ZTS 混装。

逐 CVE 记录，模板见 [JSON](../examples/security-evidence.example.json)：

| 状态 | 含义 |
|---|---|
| `UNVERIFIED` | 只有候选或版本信息，证据不完整 |
| `CONFIG_MITIGATED` | 仅配置/入口缓解，未修复 |
| `VENDOR_MINIMAL_BACKPORT` | 已核验供应商最小回移，保留限制与残余风险 |
| `VENDOR_FIXED_VERIFIED` | 供应商明确覆盖，实际制品和测试证据与声明一致 |

最后一种状态也只表示记录范围内的验证，不是“无漏洞认证”。不得以修改 JSON 字段代替证据审核；不得把最小回移包装为与新分支完整补丁等价。

## 1.3 临时缓解不等于修复

FPM pool 可评估 `php_admin_flag[session.upload_progress.enabled] = off`；普通上传与 Session 仍需回归，不能依赖应用 `ini_set()` 或 `.user.ini` 来拦截初始化前的路径。[S1][S3]

对于另一条已知路径，上游提出管理级 `memory_limit=-1` 的不完整缓解；它可能放大容器/主机 OOM 风险，本项目不自动启用。不要用 `RLIMIT_AS`/`RLIMIT_DATA` 替代。有限内存的正常运行配置只在补丁证据审查后评估，不能宣称其缓解两个漏洞。[S1][S2]

不需要 multipart 的接口可在前端限制；需要上传的业务不能一刀切封禁。头部 buffer、限流、WAF 和 `pm.max_requests` 都不能代替内核补丁。所有临时修改须审批、测试并使全部相关 worker 生效。[S2][S3]

## 1.4 权威核验入口

- **S1 PHP 安全公告与 EOL 范围：** https://www.php.net/archive/2026.php
- **S2 OOM 公告：** https://github.com/php/php-src/security/advisories/GHSA-w8hw-w9fx-j79w
- **S3 全局状态公告：** https://github.com/php/php-src/security/advisories/GHSA-6wmf-4rv5-p3rp
- **S4 Sury 包目录：** https://packages.sury.org/php/pool/main/p/php7.2/
- **S5 Sury 仓库配置：** https://packages.sury.org/php/README.txt
- **S6 Nginx 下载：** https://nginx.org/en/download.html
- **S7 Nginx 安全公告：** https://nginx.org/en/security_advisories.html
- **S8 Nginx 官方包：** https://nginx.org/en/linux_packages.html
- **S9 FPM 配置：** https://www.php.net/manual/en/install.fpm.configuration.php
- **S10 OPcache：** https://www.php.net/manual/en/opcache.configuration.php
- **S11 Nginx FastCGI：** https://nginx.org/en/docs/http/ngx_http_fastcgi_module.html
- **S12 Nginx 信号：** https://nginx.org/en/docs/control.html
- **S13 Docker 多服务容器：** https://docs.docker.com/engine/containers/multi-service_container/
- **S14 Docker 构建密钥：** https://docs.docker.com/build/building/secrets/
- **S15 Kubernetes 终止：** https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/
- **S16 Kubernetes 探针：** https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/
- **S17 Composer 要求：** https://getcomposer.org/doc/00-intro.md
- **S18 Composer 命令：** https://getcomposer.org/doc/03-cli.md
- **S19 PECL：** https://pecl.php.net/
- **S20 PHP 源码安装：** https://www.php.net/manual/en/install.unix.nginx.php

S9/S10 为跨版本手册，不能把 PHP 7.3/8.x 新增指令直接写入 7.2。S20 为基础安装说明，不是本次补丁集或现代完整部署模板。各文档的工程建议与上述外部事实分开理解。
