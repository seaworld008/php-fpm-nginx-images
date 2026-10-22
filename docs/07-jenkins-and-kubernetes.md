# 7. Jenkins、Docker 与 Kubernetes 接入

本章为后续实现规范。尚未提供已经运行验证的 Jenkinsfile、Compose 或 K8s Deployment，不应把本章参数直接当作生产 YAML。

## 7.1 基础镜像与业务镜像分层

基础层统一维护 PHP、Nginx、扩展、FPM/OPcache、init、日志和探针。业务层只安装锁定依赖、复制代码和无密钥配置，FROM 使用已验收 digest。不要每次业务发布再查询最新 PHP、重装扩展或 sed 修改 FPM。

保留现有 code_compile/docker_file 对接方式即可，不需要重建整个 Jenkins。依赖安装在与最终 PHP/扩展平台一致的 builder 中运行，而不是 `source /etc/profile` 后使用 Jenkins 宿主机 PHP。

有 composer.lock 按锁 install；没有 lock 不自动 update 全站依赖，先审查已有 vendor 和锁定策略。核查 scripts/plugins/自动部署副作用，不无条件 `--no-scripts` 破坏旧 ThinkPHP 安装；禁止 `--ignore-platform-reqs` 掩盖失败。Composer 版本执行时核验并锁定，不能武断认为 PHP 7.2 仅能用 2.2。[S17/S18]

使用依赖锁/平台隔离的 BuildKit cache，私有凭据用 secret/SSH mount。生产 database.php/config.php/.env 不 COPY 入任何层；后续 rm 无法清除历史层。既有文件读取路径可通过运行时只读挂载保持兼容。[S14]

流水线：检出 → 依赖/密钥检查 → 构建 → 配置/扩展/路由验证 → SBOM/扫描 → 报告 → 人工授权推送。失败不能用 `|| true` 隐藏，推送与部署分开。

## 7.2 管理端点与探针

候选设计：管理端口只监听 127.0.0.1:8081，业务 80 拒绝 `/live`、`/ready`、`/fpm_ping`、`/fpm_status` 等保留路径。

- startup：有界等待 Nginx/FPM 可用。
- readiness：检查 draining 和主 FPM 路径；不访问 DB/Redis。
- liveness：关键进程及 Nginx 存活；不要因 FPM 忙时一次排队就重启。

K8s 使用 exec 访问本地端点，不能同时将管理口绑定 loopback 却用 Pod IP httpGet。PHP 7.2 主池 ping/status 也会排队，压测检查集体摘流和重启风暴。不得照搬新版 `pm.status_listen`。[S9/S16]

## 7.3 Kubernetes 实施要求

apps/v1；明确 requests/limits 和 ephemeral-storage；候选 maxUnavailable=0、maxSurge=1，但先确认配额/节点容量。service 仅业务口，禁自动挂 serviceaccount token（业务不需要时）。

preStop 标记 draining 并短暂等待路由传播；主进程依次排空 Nginx/FPM。初始 terminationGracePeriodSeconds=120，总预算包含 preStop，不额外叠加同一段 drain。[S15]

Secret/ConfigMap 使用明确更新重启策略；运行时、临时文件、uploads、session 权限按应用设计；多副本不能把本地文件 Session 当共享。tmpfs 会消耗内存，不默认用于大上传。HPA 上限受后端连接预算限制，报名瞬时高峰需要预扩容。

只读根目录需要将模板渲染到可写目录并实测；不能声称全镜像非 root 却依赖 root 创建 socket/降权。K8s 没有通用 Pod ulimits 字段，不生成不存在的配置。

## 7.4 Docker / Compose

隔离测试绑定 `127.0.0.1:<空闲端口>:80`，不占用生产 80/443。配置实际生效的 CPU/内存、日志轮转和候选 120 秒 stop_grace_period；先 compose config，再核对运行中的限制。

Docker HEALTHCHECK 不替代 Kubernetes probes。没有授权不改 Docker daemon、全局 sysctl、服务或运行容器，也不执行 prune。
