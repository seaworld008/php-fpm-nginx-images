# 2. Nginx + PHP-FPM 镜像重建方案

**这是待实现、待运行测试的构建规格，不是现成 Dockerfile。** 前置阅读：[安全证据](01-security-and-sources.md)。

## 2.1 推荐路线

干净的 `debian:bookworm-slim` 固定 manifest digest → 同代号可信 PHP 7.2.34 回移包 → Nginx 官方 stable → 锁定扩展 → 受控运行时与验证。

优先沿用已有可信 PHP 供应商，减少兼容变量；没有经核验 7.2 包时，保留候选状态并转 [源码路线](04-native-source-repair.md)。不要从旧业务镜像叠加更新，不用 `docker commit`，不混 Buster/Bookworm/Ubuntu 源。

Nginx 是独立修复对象：执行时查 S6/S7，选择当时稳定分支并锁完整包版本；官方仓库尚未同步则说明阻塞或使用经签名核验的官方源码，不能悄悄降级。

## 2.2 实现目录契约

后续实施者应创建以下文件；本节列出的是目标结构，不代表它们已存在：

```text
container/Dockerfile
container/config/nginx/        # 主配置、站点、管理端口、FastCGI include
container/config/php/          # FPM 主配置、pool、INI
container/scripts/            # entrypoint、监督器、渲染器、探针、drain
locks/versions.lock.json
locks/packages.lock.tsv
locks/extensions.lock.json
container/tests/              # 路由、扩展、生命周期和故障测试
```

发现最新候选和按锁构建应分离。正式构建拒绝缺失 digest、假哈希、未确定来源、版本漂移；不能依靠安装时动态选择最新版保证可重建。

## 2.3 包与供应链

- 下载 keyring 后核对可信指纹/来源；每个仓库独立 `signed-by`。禁止 `trusted=yes`、禁用 GPG/TLS 校验、未审阅 curl 管道执行。
- 记录签名 Release/索引、实际包、匹配源包、补丁、完整修订与 SHA256。目录中的候选版本只是线索。
- 安装明确的 `php7.2-*`；不要用会跟随新主版本的 `php`、`php-fpm`、`php-redis` 元包替代平台约束。
- 核心包同修订；第三方扩展独立锁定，检查 NTS/ZTS、PHP API、架构、动态库。
- runtime 不保留编译器、dev headers、源码缓存、Xdebug 或未审查的 Composer。构建阶段和运行阶段分开。
- 保存完整依赖清单和可合法归档的包，避免未来仓库清理后无法重建；包的再分发许可单独审核。
- 初次只声明实测平台；QEMU 构建成功不能替代原生 ARM64 业务验证。

## 2.4 兼容接口与权限

默认保留公开根目录 `/usr/share/nginx/html/public`、80 端口和 Unix socket `/run/php/php7.2-fpm.sock`；用户名、UID/GID、时区按现场核实。业务代码根拥有、worker 只读，仅 runtime/session/uploads/cache 可写。

Nginx/FPM 同容器是兼容选择，非要求所有应用一律这样部署。队列、Swoole 和 cron 使用同运行时的独立服务；不默认塞入 Web 容器。

支持非 Web 子命令 `exec "$@"`。默认兼容 master 可能仍需 root；没有验证高端口和目录权限前不得宣称整个容器 `runAsNonRoot`。不开放 FastCGI TCP、不挂 Docker socket、不 privileged。

## 2.5 PID 1 与信号契约

可选择 tini + 小型监督器，或成熟监督组件；必须实现并测试，而不是后台启动后 `tail -f /dev/null`：

1. 校验模板参数并准备有限的可写目录；配置检测失败立即退出。
2. FPM 前台启动；等待 socket 有截止时间；再启动前台 Nginx。
3. 任一 master 意外退出（包括 exit 0），清理另一个，容器非零退出。
4. 正常 TERM/QUIT：标记 draining，Nginx QUIT 排空请求，再优雅结束 FPM，最后回收子进程。
5. 每步有期限和升级终止记录；不能无限挂住 Pod。不要同时向整个进程组发信号破坏顺序。

参考 S12/S13。候选总停止预算 120 秒，必须包含 preStop 和 drain；详见 [部署接入](07-jenkins-and-kubernetes.md)。

## 2.6 验收门禁

CLI/FPM/nginx 版本与锁一致；配置和动态库检查通过；真实 FPM 请求值正确；扩展与路由不缺失；关键进程退出会使容器失败；信号能有序排空；无密钥；完成 SBOM 和范围明确的扫描。

构建完成后仍需 [兼容性测试](06-compatibility-and-testing.md)、[性能测试](05-runtime-and-performance.md) 和 [发布验收](08-release-and-rollback.md)。没有这些结果只允许叫候选镜像。
