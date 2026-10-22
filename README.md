# PHP-FPM + Nginx Legacy Repair Playbook

**面向 PHP 7.2.x 遗留应用的安全回移、镜像重建与本机修复方案。**

A community-maintained, evidence-first guide for PHP 7.2.x backports, Nginx/PHP-FPM container rebuilds, and native Linux runtime repair.

> **当前状态：方案与审计工具，不是已验证的修复镜像发行版。**
> 本仓库没有发布可直接用于生产的 PHP 二进制、通用补丁、Docker 镜像或自动修复脚本。
> 不要把文档存在、CI 通过或 `php -v` 显示 7.2.34 当作漏洞修复证明。

## 项目解决什么问题

为暂时不能升级 ThinkPHP 5 等旧业务的团队，提供两条可审计的过渡路线：

| 场景 | 路线 | 首先阅读 |
|---|---|---|
| Docker / Kubernetes | 干净基础镜像 + 已核验 PHP 7.2.34 回移包 + Nginx stable | [镜像构建方案](docs/02-container-build-plan.md) |
| APT / RPM 安装的本机 PHP | 同发行版、同供应商包更新，核验 CLI、FPM 与常驻进程 | [包管理修复](docs/03-native-package-repair.md) |
| 源码安装 / 自定义路径 / 面板管理 | 可追溯补丁 + 独立前缀并行安装，或面板官方支持的升级流程 | [源码与面板修复](docs/04-native-source-repair.md) |

**不把 PHP 7.2 升级到原版 7.2.34 当作此次修复，不把 Nginx 更新当作 PHP 内核修复。**
PHP 7.2 已结束上游支持；本项目是迁移前的风险控制工作，不是恢复 PHP 官方维护。
依据与核验日期见 [安全事实与来源](docs/01-security-and-sources.md)。

## 快速开始

1. 阅读 [状态与边界](docs/00-project-status.md)，判断你需要的是容器还是本机路线。
2. 在授权环境采集最小清单，再验证供应商公告、匹配源码、签名与目标包。
3. 按对应方案在隔离环境实施，完成兼容性、回归和回滚验证后再申请生产变更。

可选只读采集工具，要求 **Python 3.8+**；仅调用你指定或本机 PATH 中可信的 PHP/FPM：

```bash
umask 077
python3 tools/inventory.py --php /usr/bin/php --fpm /usr/sbin/php-fpm7.2 > inventory.local.json
```

FPM 路径不同请使用实际路径；省略 `--fpm` 时不会猜测正在服务的 FPM。工具不安装包、不改配置、不重启服务，不输出环境变量、完整 `phpinfo` 或业务配置。报告仍含本机路径和启动诊断，**人工脱敏后才能公开**。其 `UNVERIFIED` 状态不是漏洞扫描结论。

本仓库的离线自检：

```bash
python3 -m unittest discover -s tests -v
python3 tools/check_docs.py
```

这些命令只验证工具和文档结构，不构建 PHP，不验证目标 CVE，也不访问生产系统。

## 文档导航

- [补丁证据、事实边界和权威来源](docs/01-security-and-sources.md)
- [容器重建](docs/02-container-build-plan.md) · [本机包管理修复](docs/03-native-package-repair.md) · [本机源码/面板修复](docs/04-native-source-repair.md)
- [高并发与运行时](docs/05-runtime-and-performance.md) · [扩展与验证矩阵](docs/06-compatibility-and-testing.md)
- [Jenkins、Docker 和 Kubernetes 接入](docs/07-jenkins-and-kubernetes.md)
- [发布、回滚和证据交付](docs/08-release-and-rollback.md)
- [给 Codex 的完整任务书](docs/09-codex-execution-plan.md)
- [安全证据模板](examples/security-evidence.example.json) · [验收报告模板](templates/validation-report.md)

## 实现状态

| 项目 | 状态 |
|---|---|
| 两条修复路线、配置原则、验收和回滚规范 | 已提供 |
| 本机最小清单工具、离线文档检查及单元测试 | 已提供；验证范围见测试 |
| 每个 PHP 7.2 供应商包的签名/补丁/二进制闭环 | 未完成，不作覆盖承诺 |
| 可复现 Dockerfile、扩展构建和进程管理实现 | 待按任务书实现 |
| 真实 FPM 漏洞回归、两类业务测试、压测 | 未执行 |
| 生产可用镜像、本机安装包、多架构制品 | 尚未发布 |

未来发布必须附带完整供应商版本、制品哈希、逐 CVE 证据、测试范围和剩余风险；不能仅提供 `latest` 标签或“已安全”口号。

## 参与与许可

欢迎通过 Issue / PR 提交来源明确的补丁线索、脱敏测试结果、兼容性修复和文档改进。请先阅读 [贡献指南](CONTRIBUTING.md) 与 [安全政策](SECURITY.md)。

本仓库原创文档和工具采用 [MIT License](LICENSE)。PHP、Nginx、发行包、扩展及第三方补丁的权利不由本项目重新授权，详见 [NOTICE](NOTICE.md)。
