# Container Build Directory

PHP 7.2.34 + Nginx 生产镜像构建文件

## 快速开始

```bash
# 构建镜像
cd container
bash build.sh

# 运行测试
export IMAGE_NAME="php72-fpm-nginx:production"
bash tests/test-container.sh

# 启动容器
docker run -d -p 8080:80 php72-fpm-nginx:production
```

## 目录结构

```
container/
├── Dockerfile          # 生产 Dockerfile（多阶段构建）
├── build.sh            # 构建脚本
├── .dockerignore       # 排除文件列表
│
├── config/            # 配置文件模板
│   ├── nginx/         # Nginx 配置
│   └── php/           # PHP-FPM 配置
│
├── scripts/           # 辅助脚本
│   └── (future)       # 入口脚本等
│
└── tests/             # 测试套件
    └── test-container.sh  # 自动化验证
```

## 核心配置

### PHP 版本
- **版本**: 7.2.34-66+0~20261021.122+debian12~1.gbpe0bcd4
- **来源**: Sury DEB.SURY.ORG 官方仓库
- **补丁**: 包含 CVE-2026-109618、CVE-2026-109619

### Nginx 版本
- **版本**: 1.26.2 stable
- **来源**: Nginx 官方仓库

### 扩展列表 (43个)
- **核心**: bcmath, curl, gd, mbstring, mysql, xml, zip
- **PECL**: redis, imagick, swoole (4.8.13)
- **完整列表**: 见 `locks/extensions.lock.json`

## 自定义配置

### 挂载自定义配置

```bash
docker run -d \
    -v ./my-nginx.conf:/etc/nginx/conf.d/site.conf:ro \
    -v ./my-php.ini:/etc/php/7.2/fpm/conf.d/99-custom.ini:ro \
    -p 8080:80 \
    php72-fpm-nginx:production
```

### 环境变量

当前镜像未实现环境变量配置。如需动态配置，建议：
1. 使用配置文件挂载
2. 构建派生镜像
3. 使用 ConfigMap (Kubernetes)

## 资源要求

| 环境 | CPU | 内存 | 说明 |
|------|-----|------|------|
| 最小 | 0.5核 | 512MB | 低流量测试 |
| 推荐 | 1核 | 1GB | 正常生产负载 |
| 高负载 | 2核+ | 2GB+ | 需调整 FPM worker 数量 |

## 健康检查

### Docker
```bash
docker run -d \
    --health-cmd="curl -f http://localhost/fpm_ping || exit 1" \
    --health-interval=30s \
    --health-timeout=5s \
    --health-retries=3 \
    php72-fpm-nginx:production
```

### Kubernetes
```yaml
livenessProbe:
  httpGet:
    path: /fpm_ping
    port: 80
  initialDelaySeconds: 10
  periodSeconds: 30

readinessProbe:
  httpGet:
    path: /fpm_ping
    port: 80
  initialDelaySeconds: 5
  periodSeconds: 10
```

## 故障排查

### 容器无法启动

```bash
# 查看日志
docker logs <container-id>

# 进入容器调试
docker run -it --rm php72-fpm-nginx:production bash

# 测试配置
docker run --rm php72-fpm-nginx:production php-fpm7.2 -t
docker run --rm php72-fpm-nginx:production nginx -t
```

### FPM 502 错误

检查：
1. Socket 权限：`ls -l /run/php/php7.2-fpm.sock`
2. FPM 进程：`ps aux | grep php-fpm`
3. FPM 日志：`docker logs <container-id> | grep php-fpm`

### OPcache 未生效

```bash
# 验证 OPcache
docker exec <container-id> php -i | grep opcache.enable
# 应输出：opcache.enable => On => On

# 查看 OPcache 统计
curl http://localhost/opcache-status.php
```

## 安全注意事项

⚠️ **默认配置不适合直接暴露公网**：
1. 使用反向代理（Nginx/Traefik）处理 TLS
2. 配置 WAF 规则
3. 限制上传大小和执行时间
4. 定期更新基础镜像和依赖
5. 扫描已知漏洞

🔒 **生产环境必备**：
1. 非 root 用户运行（当前: nginx:nginx）
2. 只读根文件系统 + 可写卷
3. 移除调试工具（vim, telnet 等）
4. 限制系统调用（seccomp profile）
5. 网络策略隔离

## 性能优化

### OPcache 调优

编辑 `/etc/php/7.2/mods-available/opcache.ini`：

```ini
opcache.memory_consumption=256        ; 增加内存（默认128）
opcache.max_accelerated_files=20000   ; 大型项目（默认10000）
opcache.validate_timestamps=0         ; 生产环境禁用检查
```

### FPM 调优

编辑 `/etc/php/7.2/fpm/pool.d/www.conf`：

```ini
pm.max_children = 40                  ; 根据容器内存调整
pm.start_servers = 10
pm.min_spare_servers = 5
pm.max_spare_servers = 15
pm.max_requests = 1000                ; 防止内存泄漏
```

## 许可证

本镜像构建文件采用 MIT License。

包含的软件遵循各自许可证：
- PHP: PHP License 3.01
- Nginx: 2-clause BSD
- Debian: GPL 及其他

详见项目根目录 `NOTICE.md`。

## 相关文档

- [容器构建实施经验](../docs/11-container-build-实施经验.md)
- [性能调优指南](../docs/05-runtime-and-performance.md)
- [Kubernetes 部署](../docs/07-jenkins-and-kubernetes.md)
- [回滚方案](../docs/08-release-and-rollback.md)