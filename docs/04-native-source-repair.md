# 4. 本机 PHP 7.2.x：源码安装、自定义二进制与面板

适用于 `/usr/local/php`、`/opt/php`、自编译 PHP 或无法获得匹配供应商包的场景。**不存在可以普遍套用到任意 PHP 7.2.x ELF 的安全十六进制热补丁。**

工程目标是“源码与补丁可追溯 → 同目标平台重新构建 → 独立前缀验证 → 分批切换”，不是在旧二进制上猜偏移，也不是从 Debian 容器复制可执行文件到其他系统。

## 4.1 分流

| 情况 | 路线 |
|---|---|
| 有匹配、可信供应商包 | 优先 [包管理路线](03-native-package-repair.md) |
| 有可追溯 PHP 7.2.34 源包与维护者回移补丁 | 在克隆构建环境执行本章 |
| 仅有 PHP 8.x 补丁 | 需要专门回移审查，不能直接 cherry-pick 后上线 |
| 宝塔、Plesk、DirectAdmin 等管理 PHP | 先核对面板供应商补丁与构建机制；禁止绕过面板覆盖安装 |
| Windows/macOS、未知架构或无法重建的扩展 | 本方案未验证，不能使用 Linux 制品顶替 |

原版 PHP 7.2.34 的签名只证明该原版来源，不证明它含此次修复。升级 7.2.22 → 7.2.34 是基线变化，仍必须叠加已验证的回移修复。

## 4.2 采集与冻结

记录 OS/架构/libc、编译器、OpenSSL、libxml、ICU 等依赖；真实 PHP/FPM/CLI 路径；NTS/ZTS、API、扩展版本与构建特性；CLI/FPM 各自 INI；服务/队列/cron 和调用 PHP 的绝对路径。

可只读获取原构建线索：

```bash
/path/to/trusted/php-config --configure-options
/path/to/trusted/php-config --extension-dir
/path/to/trusted/php --ini
/path/to/trusted/php -m
```

`--configure-options` 仅用于人工比较，**不得 eval 执行**。删去旧 prefix、过时库路径和无效选项后生成受审查参数。不同 OS、glibc/musl、OpenSSL 或架构的 `.so` 不可直接复用；相同 PHP API 也不等于所有动态依赖兼容。

## 4.3 建立补丁包

锁定以下内容并归档：源码完整版本/来源/签名/哈希；每份补丁的维护者、提交、许可证、SHA256 和应用顺序；对应 CVE、覆盖范围、供应商说明；构建依赖与工具链版本；修复前后回归结果。

优先使用维护者已集成的**匹配源包**，保留其完整补丁顺序与构建规则；不要从某源包只摘一两个 CVE 名称相似的 diff 就假定等价。

自行应用 patch 时先 dry-run，检查路径、不接受 `.rej`、未经解释的 fuzz/offset 或部分应用；如果涉及 re2c/bison 等生成源码，保留所需生成器及生成步骤，不能编译旧生成文件冒充新修复。没有明确覆盖说明就停留 `UNVERIFIED`/最小回移状态。

本仓库当前没有提供一份已验证的 7.2.34 通用补丁；这一步受阻时可以继续文档、配置与隔离测试设计，但不能跳过后发布二进制。

## 4.4 独立前缀构建

设计目录（实际 BUILD_ID 由完整版本、补丁集和时间生成）：

```text
/opt/php72/releases/<BUILD_ID>/    # 不可变程序、扩展、库与配置
/opt/php72/current                # 可选 CLI 管理链接；不是 Web 切换的唯一依据
/run/php72-<BUILD_ID>/            # 独立 socket、pid
/var/log/php72-<BUILD_ID>/        # 独立日志
```

配置隔离很重要：为新构建指定独立 `--with-config-file-path`、`--with-config-file-scan-dir`、FPM 主配置及 includes，防止候选误加载旧 `.so` 或旧 pool/socket。

在与目标 OS/架构兼容的隔离环境完成：

1. 使用已审查的完整 configure 参数，明确 `--enable-fpm`、NTS/ZTS、依赖目录与不可变 prefix，不使用 `-march=native` 制造不可移植制品。
2. 有界并行编译（初始 `make -j2`），按供应商构建规则执行回归；测试不得连接生产或共享生产数据。
3. 用该源码支持的暂存安装机制打包；PHP 的 `INSTALL_ROOT` 应以目标 Makefile 确认，不假定 `DESTDIR` 通用。暂存目录必须可写但不覆盖系统 `/usr`。
4. 用新构建的 phpize/php-config 重建必要扩展；不能让 PATH 误选宿主机另一版本工具。
5. 生成制品清单、SHA256、SBOM、构建日志、补丁说明和安装前缀。只对可信自产/已验签制品运行动态依赖检查。
6. 在克隆目标机上检查 loader/依赖、证书、时区、INI 和业务功能。构建机可运行不代表目标机可运行。

不要在繁忙生产机安装编译器、全量升级系统库或运行 `make install` 覆盖原目录。不要使用固定下载的陌生二进制替代此过程。

## 4.5 并行 FPM 与 systemd

新旧 FPM 使用不同 service 名、不可变 ExecStart 路径、pool 配置、socket、pid、日志和临时目录。对配置逐项检查，避免新服务 include 旧 pool。保留现有生产服务不动，先让候选只接受本机测试请求。

新服务约束：前台 `php-fpm --nodaemonize`；显式 FPM 主配置和 php.ini；合理的运行用户/socket 权限；有界停止时间；正确的 FPM 优雅信号。应按主机 systemd 与安全策略生成并验证 unit，不照搬容器配置中的 `/proc/self/fd/2`、UID 或目录权限。

服务启动后用真实 FastCGI 请求验证，不只用 `php-fpm -t`。`nginx -t` 成功也不检查应用数据库功能或所有上游请求。

## 4.6 切流与回滚

在授权窗口中修改 Nginx 的明确 upstream/socket 指向新 FPM，先 `nginx -t`，再进行经过审批的 reload。既有 worker 可能继续处理在途请求，观察实际流量和 PID，排空后停止旧 FPM；不能把改了软链接等同全部进程已换新。[参考 S12，见来源页]

CLI、cron、Supervisor/systemd worker、Swoole 必须分别切换到新绝对路径并重启。验证新 `current` 链接不改变其他业务的 PHP；多个 PHP 版本并存时禁止全局覆盖 `/usr/bin/php`。

回滚时还原 upstream 与完整运行组合，核对 Session/缓存兼容；优先回滚到已修复构建。新构建造成问题时保留日志和制品，不立即删除现场。

## 4.7 面板管理例外

先读取面板 PHP 路径、构建选项、扩展清单、站点绑定和重建机制，再核对其供应商安全公告。面板有现成可信修复时优先走支持流程；没有时只能在其允许的自定义机制下安装独立候选。

不要直接覆盖面板 `/www/server/php/72` 等受管理目录，不让面板后续自动升级又覆盖回旧二进制。确需面板外并行 FPM，应明确谁管理启动、升级、日志、扩展和回滚，并取得运维批准。

本仓库不承诺任何特定面板已支持此补丁，也不分发未经授权的商业构建包。
