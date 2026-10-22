# ============================================================================
# PHP 7.2.34-66 镜像升级 - 快速迁移指南
# ============================================================================

## 📋 3 步快速迁移

### 步骤 1️⃣：复制修复函数到您的 Jenkins 脚本

在脚本开头（变量定义后面）添加以下函数：

```bash
# ============================================================================
# supervisord 配置自动修复函数
# ============================================================================
fix_supervisord_config(){
    echo "========================================"
    echo "🔧 修复 supervisord 配置..."
    echo "========================================"

    # 根据项目名提取配置路径
    local config_name="${project_name#jwxt_}"
    local config_path="/data/docker_deploy/jwxt_test-config/${config_name}/supervisord.conf"

    if ssh -p 10015 $destination_IP "[ -f $config_path ]"; then
        echo "✓ 发现配置: $config_path"
        ssh -p 10015 $destination_IP "cp $config_path ${config_path}.bak-\$(date +%Y%m%d-%H%M%S)"
        ssh -p 10015 $destination_IP "sed -i 's/nodaemon=false/nodaemon=true/g' $config_path"
        ssh -p 10015 $destination_IP "sed -i '/^\[eventlistener:stdout\]/,/^result_handler.*event_handler/d' $config_path"
        echo "✅ 配置修复完成"
    else
        echo "✓ 使用镜像内置配置"
    fi
    echo "========================================"
}
```

### 步骤 2️⃣：修改 Dockerfile

将基础镜像从旧版本改为新版本：

```dockerfile
# 旧版本（删除或注释）
# FROM 172.18.151.153:9080/jlkj-base/xhy-nginx-php-fpm-7.2.24:v2

# 新版本（使用这个）
FROM 114.115.130.46/jlkj-base/wyveo-nginx-php-fpm-7.2.34:v20261022

COPY --chown=nginx:nginx . /usr/share/nginx/html/
COPY ./default.conf /etc/nginx/conf.d/default.conf
```

### 步骤 3️⃣：在发布逻辑中调用

在 `docker_file` 之前添加 `fix_supervisord_config` 调用：

```bash
if [ "$deploy_env" == "deploy" ]
then
  create_docker_composefile
  code_compile
  fix_supervisord_config      # ← 添加这一行
  docker_file
  docker_build
  docker_push
  docker_rm_buildimage
  docker_pull
  docker_create_compose
  docker_devlop
  code_auth
  docker_rm_devlopimage
  check_port
else
  docker_rollback
  check_port
  docker_rm_rollbackimage
fi
```

**完成！** 🎉 现在可以正常发布了。

---

## 🔧 高级：自定义配置路径

如果您的配置路径不同，修改 `config_path` 变量：

```bash
fix_supervisord_config(){
    # 方式 1：基于项目名自动推导
    local config_name="${project_name#jwxt_}"
    local config_path="/data/docker_deploy/jwxt_test-config/${config_name}/supervisord.conf"

    # 方式 2：直接指定（如果路径规则不同）
    # local config_path="/data/docker_deploy/${project_name}/supervisord.conf"

    # 方式 3：使用环境变量
    # local config_path="${SUPERVISORD_CONFIG_PATH:-/etc/supervisord.conf}"

    # 其余代码相同...
}
```

---

## 📊 批量迁移多个项目

### 方案 A：逐个项目迁移（推荐）

1. 选择一个测试项目（如 `jwxt_test_project`）
2. 按上述 3 步修改
3. 构建并测试
4. 验证通过后，依次迁移其他项目

### 方案 B：批量修复配置文件

如果要一次性修复所有项目的配置文件：

```bash
ssh -p 10015 172.18.151.165 << 'ENDSSH'
for conf in /data/docker_deploy/jwxt_test-config/*/supervisord.conf; do
    if [ -f "$conf" ]; then
        echo "修复: $conf"
        cp "$conf" "${conf}.backup-$(date +%Y%m%d-%H%M%S)"
        sed -i 's/nodaemon=false/nodaemon=true/g' "$conf"
        sed -i '/^\[eventlistener:stdout\]/,/^result_handler.*event_handler/d' "$conf"
        echo "✓ 完成"
    fi
done
echo "所有配置修复完成"
ENDSSH
```

---

## ✅ 验证清单

部署后检查：

```bash
# 1. 检查容器状态
docker ps | grep 项目名

# 2. 检查所有进程
docker exec 容器名 supervisorctl status

# 3. 查看日志
docker logs -f 容器名

# 4. 测试服务
curl http://目标IP:端口
```

**正常输出示例**：
```
nginx                            RUNNING   pid 8, uptime 0:00:10
php-fpm7                         RUNNING   pid 7, uptime 0:00:10
jxgl-copy-recruit-classes:00     RUNNING   pid 9, uptime 0:00:09
jxgl-sync-lndx:00                RUNNING   pid 10, uptime 0:00:09
jxgl_create_diploma:00           RUNNING   pid 11, uptime 0:00:09
```

---

## 🎯 常见问题

### Q1: 为什么需要修复配置？
**A:** 旧配置文件使用了不存在的 `supervisor_stdout` 模块，且 `nodaemon=false` 会导致容器立即退出。

### Q2: 修复函数做了什么？
**A:** 
1. 将 `nodaemon=false` 改为 `nodaemon=true`（容器必须）
2. 删除不兼容的 `[eventlistener:stdout]` 配置
3. 自动备份原配置（带时间戳）

### Q3: 我的 Worker 进程会丢失吗？
**A:** 不会。修复函数只删除有问题的部分，保留所有业务 Worker 配置。

### Q4: 可以不挂载配置文件吗？
**A:** 可以。如果删除 docker-compose 中的配置文件挂载，将使用镜像内置配置（仅 PHP-FPM + Nginx）。但如果您有队列 Worker，必须保留配置文件。

### Q5: 修复失败怎么办？
**A:** 配置文件已自动备份，可以手动恢复：
```bash
ssh -p 10015 目标IP
cp /data/docker_deploy/jwxt_test-config/项目名/supervisord.conf.bak-* \
   /data/docker_deploy/jwxt_test-config/项目名/supervisord.conf
```

---

## 📚 相关文档

- 完整模板脚本: `jenkins-deploy-template.sh`
- 独立修复脚本: `fix-supervisord.sh`
- 容器构建指南: `docs/11-container-build-实施经验.md`
- 镜像信息: `README.md`

---

## 💡 提示

✅ **推荐做法**：
- 先在测试环境验证
- 逐个项目迁移
- 保留配置备份

❌ **不推荐做法**：
- 一次性修改所有项目
- 不测试直接上生产
- 跳过配置修复步骤

---

**镜像信息**:
- 镜像: `114.115.130.46/jlkj-base/wyveo-nginx-php-fpm-7.2.34:v20261022`
- PHP: 7.2.34-66 (含 CVE 补丁)
- Nginx: 1.26.2
- 扩展: 43 个 (含 Swoole 4.8.13)
