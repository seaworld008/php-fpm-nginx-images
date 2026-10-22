# 5. 运行时、安全边界与高并发

本章是**待压测的工程设计**，不代表本仓库已有配置实现或性能保证。补丁证据先按 [安全章节](01-security-and-sources.md) 审核。

## 5.1 FPM 资源预算

不固定所有 Pod 都为 32/128 个 worker。最终 max_children 取内存、CPU/延迟和后端连接预算三者允许值的最小值。

```text
worker 私有内存预算 = cgroup 内存上限 - Nginx/master/init - 共享 OPcache - 缓冲/页缓存 - 安全余量
内存允许 worker 数 = floor(私有内存预算 / 代表性负载下单 worker 私有内存 P95)
```

测量 USS/私有页或解释正确的 PSS，并对比整个 cgroup 的内存增长。不要相加 RSS 重复计算共享页；PHP memory_limit 不等于进程 RSS。

以下仅为压测起点，不能自动用于生产：

| limits | max_children | start | min_spare | max_spare | OPcache |
|---|---:|---:|---:|---:|---:|
| 1 CPU / 1 GiB | 6 | 2 | 2 | 4 | 128 MiB |
| 2 CPU / 2 GiB | 12 | 4 | 4 | 8 | 256 MiB |
| 4 CPU / 4 GiB | 24 | 8 | 8 | 16 | 256 MiB |

 dynamic 必须满足 `min_spare <= start <= max_spare <= max_children`；`pm.process_idle_timeout` 不是 dynamic 优化。max_requests 可从 800 评估，不是漏洞修复，不默认设成 1。[S9]

CPU 同时考虑 cpuset 和 quota（cgroup v1/v2），不用宿主机 nproc 代替 Pod 配额。无 limits 或识别失败时使用保守候选并提示，不能按整台主机扩张。所有副本和队列的数据库/Redis 连接预算必须一起算，包含 HPA 最大副本数。

## 5.2 PHP/FPM 配置原则

- 仅 Unix socket；`security.limit_extensions=.php`；评估 `cgi.fix_pathinfo=0` 后对 PATH_INFO 回归。
- pool 管理级关闭上传进度、浏览器错误显示；错误日志可用。有限 memory_limit 只在补丁证据审查后评估，不伪称未修复环境的缓解。
- `clear_env=yes` 时显式白名单应用需要的变量；不能造成应用配置丢失，也不传整个 CI 环境。
- 超时、slowlog、上传大小必须符合实际导入/支付/长请求。容器 ptrace 受限不能自动用 privileged/SYS_PTRACE 绕过。
- PHP 7.2 不照搬 `pm.status_listen`、新日志指令、JIT/preload 等新版本配置；以实际二进制配置测试为准。
- backlog 受内核限制，是队列长度而非处理能力；不未经授权修改宿主机 sysctl。

## 5.3 OPcache

不可变业务镜像可从 enable=1、enable_cli=0、memory=256 MiB、interned_strings=16 MiB、max_accelerated_files=20000、validate_timestamps=0、save_comments=1 开始测试。按文件数、命中率和耗尽/重启记录调整。

删除已在 PHP 7.2 移除的 `opcache.fast_shutdown`。[S10] 挂载代码、rsync 或本机原地更新应选 validate_timestamps=1 或经验证的重启流程，不能复用不可变镜像策略后让新代码不生效。不要以 CLI opcache_reset 推断 FPM 缓存已刷新。

## 5.4 Nginx 入口

只允许明确的入口 PHP，默认 `public/index.php`；禁止任意上传 PHP、phtml/phar、隐藏文件、备份和非公开应用目录。不让 `^~` 上传目录或静态扩展正则绕过拒绝规则。SCRIPT_FILENAME 指向固定入口，关键 FastCGI 参数不重复定义，不修改发行包 include 的首行。

ThinkPHP 5 的 `s` 参数路由应先以旧行为建立测试，再用 try_files/named location 重构；保留 query、中文编码、重复 s、显式 index.php 和确实使用的 PATH_INFO。不能拿通用配置盲替所有站点。

Nginx 不把不可信 HTTP 请求转为 PHP_VALUE/PHP_ADMIN_VALUE；HTTP_PROXY 清空。真实 IP、HTTPS 判断及 Forwarded 头只信任已定义的代理，不无条件接受公网伪造值。

保留 request buffering；普通 API 和上传接口按需求区分大小；upload_max_filesize < post_max_size，含 multipart 开销和多文件总量。头 buffer 不等于 multipart 内部限制。[S11]

默认不开动态 FastCGI cache，不缓存认证/支付/报名；不盲开 FastCGI keepalive 或全站限流。gzip、worker 数、connections 和 nofile 要测量，不能用“参数大”代替容量结论。

## 5.5 观测和压力验证

容器日志到 stdout/stderr，本机使用受控日志与轮转；不记录 Authorization、Cookie、请求体或完整敏感 query。指标包括 5xx、P95/P99、FPM 队列、max children reached、CPU throttling、cgroup 内存、OOM、后端连接、OPcache 命中与重启。

旧/新候选同资源、同代码、同测试数据；分别测冷启动、预热、阶梯负载、持续稳态、慢依赖和扩容。只压测隔离环境，无生产写账户。静态 echo QPS 不代表业务容量。

无已有 SLO 时先产容量曲线；可评审 P95 不恶化超过 10%、吞吐不降低超过 5% 的候选门槛，但不是承诺。安全补丁引入的错误请求终止行为必须记录，不能通过恢复危险逻辑换性能。
