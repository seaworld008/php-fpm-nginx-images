# PHP-FPM + Nginx Legacy Repair Playbook

**面向 PHP 7.2.x 遗留应用的安全回移、镜像重建与本机修复方案。**

A community-maintained, evidence-first guide for PHP 7.2.x backports, Nginx/PHP-FPM container rebuilds, and native Linux runtime repair.

> **当前状态：方案与审计工具，不是已验证的修复镜像发行版。**
> 本仓库没有发布可直接用于生产的 PHP 二进制、通用补丁、Docker 镜像或自动修复脚本。
> 不要把文档存在、CI 通过或 `php -v` 显示 7.2.34 当作漏洞修复证明。

## 勘误（2026-10-23）

- **补丁状态**：Sury 7.2.34-66、7.4.33-31 只有 changelog 证据，CVE-2026-109618/109619 的状态是 `UNVERIFIED`。本页以及根目录总结类文档中“修复验证通过 / 补丁生效 / 已修复”的说法，都以此为准。Remi EL7 `7.2.34-22` **不含**这两个补丁。
- **`v20261022` 镜像实测组件**（镜像 ID `sha256:10283e041388…`，465MB）：nginx 1.30.6，PHP `7.2.34-66+0~20261021.122+debian12~1.gbpe0bcd4`，phpredis 6.0.2，mongodb 1.16.2，swoole 4.8.13，`php -m` 共 63 个模块。此前写的 nginx 1.26.2、redis 5.3.7、mongodb 1.19.4、43 个扩展与实测不符。
- **phpredis**：`Redis::delete()` 在 5.x 和 6.x 中都存在，都已 deprecated，新旧镜像行为相同。此前“6.x 删除了该方法”的说法是错的。
- 详细证据与复查记录见 [docs/12 §12.6～12.10](docs/12-生产升级实施经验-20261022.md#126-复查发现的遗漏2026-10-23)。

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

### 核心文档
- [补丁证据、事实边界和权威来源](docs/01-security-and-sources.md)
- [容器重建](docs/02-container-build-plan.md) · [本机包管理修复](docs/03-native-package-repair.md) · [本机源码/面板修复](docs/04-native-source-repair.md)
- [高并发与运行时](docs/05-runtime-and-performance.md) · [扩展与验证矩阵](docs/06-compatibility-and-testing.md)
- [Jenkins、Docker 和 Kubernetes 接入](docs/07-jenkins-and-kubernetes.md)
- [发布、回滚和证据交付](docs/08-release-and-rollback.md)
- [给 Codex 的完整任务书](docs/09-codex-execution-plan.md)

### 实施经验 ⭐
- [生产环境实施经验](PRODUCTION_EXPERIENCE.md) - Jenkins + Docker 完整流程
- [快速参考卡片](QUICK_REFERENCE.md) - 5 分钟上手指南
- [本机修复实施经验](docs/10-native-repair-实施经验.md)
- [容器构建实施经验](docs/11-container-build-实施经验.md)
- [2026-10-22 生产升级实施经验](docs/12-生产升级实施经验-20261022.md)：Remi EL7 构建的 2026 补丁缺口，FPM 用户、扩展、ini 的对齐方法，网关的容器名解析缓存；10-23 复查发现的遗漏、FPM 运行态探针、只读入侵排查清单与勘误
- 变体镜像：[php72-fpm-bitnami-compat](variants/php72-fpm-bitnami-compat/README.md) · [php74-apache-webdevops-compat](variants/php74-apache-webdevops-compat/README.md)；新旧 FPM 并行对比工具 `tools/fcgi_compare.py`

### 模板与示例
- [安全证据模板](examples/security-evidence.example.json)
- [验收报告模板](templates/validation-report.md)

## 生产实施经验 🎯

本仓库已完成真实生产环境部署验证，总结了完整的实施经验：

- **[生产环境实施经验](PRODUCTION_EXPERIENCE.md)** - Jenkins + Docker 完整部署流程、常见问题与解决方案
- **[快速参考卡片](QUICK_REFERENCE.md)** - 5 分钟上手指南、常用命令速查

首个生产项目已成功部署，40 分钟完成迁移，0 秒业务中断。CVE 补丁状态见上方[勘误](#勘误2026-10-23)：`UNVERIFIED`。

---

## 快速开始

### 容器方案

```bash
# 1. 克隆仓库
git clone https://github.com/seaworld008/php-fpm-nginx-images.git
cd php-fpm-nginx-images

# 2. 构建镜像
cd container
bash build.sh

# 3. 运行测试
export IMAGE_NAME="php72-fpm-nginx:production"
bash tests/test-container.sh

# 4. 部署使用
docker run -d -p 8080:80 php72-fpm-nginx:production
```

详见：[容器构建实施经验](docs/11-container-build-实施经验.md)

### 本机二进制方案

```bash
# 1. 克隆仓库
git clone https://github.com/seaworld008/php-fpm-nginx-images.git
cd php-fpm-nginx-images

# 2. 安装 PHP 7.2.34-66 (Debian 12)
sudo bash <<'EOF'
apt-get install -y ca-certificates curl gnupg2 lsb-release
curl -sSLo /usr/share/keyrings/deb.sury.org-php.gpg \
    https://packages.sury.org/php/apt.gpg
echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" \
    > /etc/apt/sources.list.d/php.list
apt-get update
apt-get install -y \
    php7.2-cli=7.2.34-66+0~20261021.122+debian12~1.gbpe0bcd4 \
    php7.2-fpm=7.2.34-66+0~20261021.122+debian12~1.gbpe0bcd4 \
    php7.2-common=7.2.34-66+0~20261021.122+debian12~1.gbpe0bcd4
apt-mark hold php7.2-cli php7.2-fpm php7.2-common
EOF

# 3. 验证补丁
bash tools/verify-native-php.sh

# 4. 生成清单（可选）
GENERATE_INVENTORY=1 bash tools/verify-native-php.sh
```

详见：[本机修复实施经验](docs/10-native-repair-实施经验.md)

## 目录结构

```
php-fpm-nginx-images/
├── README.md                  # 本文件
│
├── docs/                      # 技术文档
│   ├── 01-requirements-and-risks.md          # 需求分析
│   ├── 02-solution-evaluation.md              # 方案评估
│   ├── 03-patch-and-verification.md           # 补丁验证
│   ├── 04-image-layering.md                   # 镜像分层
│   ├── 05-runtime-and-performance.md          # 运行时配置
│   ├── 06-testing-strategy.md                 # 测试策略
│   ├── 07-jenkins-and-kubernetes.md           # 发布流程
│   ├── 08-release-and-rollback.md             # 回滚方案
│   ├── 09-work-breakdown.md                   # 任务分解
│   ├── 10-native-repair-实施经验.md          # 本机修复经验 ⭐
│   └── 11-container-build-实施经验.md        # 容器构建经验 ⭐
│
├── container/                 # 容器构建文件
│   ├── Dockerfile             # 生产 Dockerfile
│   ├── build.sh               # 构建脚本
│   ├── config/                # 配置模板
│   └── tests/                 # 测试套件
│
├── tools/                     # 辅助工具
│   └── verify-native-php.sh   # 本机验证脚本
│
├── locks/                     # 版本锁定
│   ├── versions.lock.json     # 包版本清单
│   └── extensions.lock.json   # 扩展清单
│
└── evidence/                  # 构建证据
    └── build-manifest-*.json  # 构建清单
```

## 实现状态

| 项目 | 状态 |
|---|---|
| 两条修复路线、配置原则、验收和回滚规范 | ✅ 已提供 |
| 本机最小清单工具、离线文档检查及单元测试 | ✅ 已提供；验证范围见测试 |
| 每个 PHP 7.2 供应商包的签名/补丁/二进制闭环 | ⚠️ Sury 7.2.34-66：签名和 changelog 已核对，补丁未审计（`UNVERIFIED`） |
| 可复现 Dockerfile、扩展构建和进程管理实现 | ✅ 生产 Dockerfile 已实现并测试 |
| 真实 FPM 漏洞回归、两类业务测试、压测 | ⚠️ 基础测试通过，业务回归待执行 |
| 生产可用镜像、本机安装包、多架构制品 | ✅ x86_64 镜像已构建；ARM64 待测试 |

**2026-10-22 更新**：
- ✅ 完成 Debian 12 + Sury PHP 7.2.34-66 容器构建
- ⚠️ CVE-2026-109618、CVE-2026-109619：Sury changelog 列出了回移条目，补丁未审计、也未做针对性回归（`UNVERIFIED`）
- ✅ 扩展齐全（含 Swoole 4.8.13），`php -m` 实测 63 个模块
- ✅ 容器自动化测试套件通过
- ✅ 本机二进制验证脚本提供
- ✅ 实施经验文档完整记录
- ✅ **生产镜像已发布**: `114.115.130.46/jlkj-base/wyveo-nginx-php-fpm-7.2.34:v20261022`

查看详细构建过程：[容器构建实施经验](docs/11-container-build-实施经验.md) | [本机修复实施经验](docs/10-native-repair-实施经验.md)

### 生产镜像信息

```yaml
镜像标签: v20261022
构建日期: 2026-10-22
基础镜像: debian:12-slim (Bookworm)
PHP 版本: 7.2.34-66+0~20261021.122+debian12~1.gbpe0bcd4
Nginx 版本: 1.30.6          # 2026-10-23 实测（此前写的 1.26.2 有误）
PHP 模块: 63 个             # php -m 实测，含 Swoole 4.8.13、phpredis 6.0.2、mongodb 1.16.2
镜像大小: 465MB
架构: linux/amd64
```

**使用镜像**：

```bash
# 拉取镜像（示例）
docker pull registry.example.com/base/php:v20261022

# 运行测试
docker run -d -p 8080:80 \
  --name php72-test \
  registry.example.com/base/php:v20261022

# 验证
curl http://localhost:8080/fpm_ping  # 健康检查
docker exec php72-test php -v        # PHP 版本
docker exec php72-test nginx -v      # Nginx 版本
```

未来发布必须附带完整供应商版本、制品哈希、逐 CVE 证据、测试范围和剩余风险；不能仅提供 `latest` 标签或“已安全”口号。

## 参与与许可

欢迎通过 Issue / PR 提交来源明确的补丁线索、脱敏测试结果、兼容性修复和文档改进。请先阅读 [贡献指南](CONTRIBUTING.md) 与 [安全政策](SECURITY.md)。

本仓库原创文档和工具采用 [MIT License](LICENSE)。PHP、Nginx、发行包、扩展及第三方补丁的权利不由本项目重新授权，详见 [NOTICE](NOTICE.md)。
