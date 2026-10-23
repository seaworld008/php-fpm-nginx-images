# 🚀 Jenkins 项目迁移到新镜像 - 完整指南

> **勘误（2026-10-23）**：本文中 CVE-2026-109618/109619 “已修复 / 验证通过 / 补丁生效”等说法证据不足，补丁状态以 `UNVERIFIED` 为准；组件版本以实测为准（nginx 1.30.6、phpredis 6.0.2、mongodb 1.16.2）。见 [README 勘误](README.md#勘误2026-10-23) 和 [docs/12 §12.9](docs/12-生产升级实施经验-20261022.md#129-勘误)。

## 📋 目录

1. [快速开始](#快速开始)（5 分钟）
2. [详细步骤](#详细步骤)
3. [验证方法](#验证方法)
4. [常见问题](#常见问题)
5. [批量迁移](#批量迁移)

---

## 快速开始

### ⚡ 3 步完成迁移

#### 步骤 1：添加修复函数

在您的 Jenkins 脚本开头添加：

```bash
fix_supervisord_config(){
    local config_name="${project_name#jwxt_}"
    local config_path="/data/docker_deploy/jwxt_test-config/${config_name}/supervisord.conf"
    
    if ssh -p 10015 $destination_IP "[ -f $config_path ]"; then
        echo "🔧 修复配置: $config_path"
        ssh -p 10015 $destination_IP "cp $config_path ${config_path}.bak-\$(date +%Y%m%d-%H%M%S)"
        ssh -p 10015 $destination_IP "sed -i 's/nodaemon=false/nodaemon=true/g' $config_path"
        ssh -p 10015 $destination_IP "sed -i '/^\[eventlistener:stdout\]/,/^result_handler.*event_handler/d' $config_path"
        echo "✅ 完成"
    else
        echo "✓ 使用镜像内置配置"
    fi
}
```

#### 步骤 2：更新基础镜像

修改 Dockerfile：

```dockerfile
FROM 114.115.130.46/jlkj-base/wyveo-nginx-php-fpm-7.2.34:v20261022
COPY --chown=nginx:nginx . /usr/share/nginx/html/
COPY ./default.conf /etc/nginx/conf.d/default.conf
```

#### 步骤 3：调用修复函数

在发布逻辑中添加：

```bash
if [ "$deploy_env" == "deploy" ]
then
  create_docker_composefile
  code_compile
  fix_supervisord_config      # ← 添加这一行
  docker_file
  docker_build
  # ... 其他步骤
fi
```

**完成！** 🎉

---

## 验证方法

### 1. 检查容器状态

```bash
docker ps | grep 项目名
```

期望输出：容器状态为 `Up`，而不是 `Restarting`。

### 2. 检查进程状态

```bash
docker exec 容器名 supervisorctl status
```

期望输出：所有进程都是 `RUNNING` 状态。

### 3. 查看日志

```bash
docker logs --tail 50 容器名
```

不应该看到错误：`Error: supervisor_stdout:event_handler cannot be resolved`

---

## 常见问题

### Q1: 容器一直重启？

检查配置是否修复成功：
```bash
ssh -p 10015 目标IP
cat /data/docker_deploy/jwxt_test-config/项目名/supervisord.conf | grep nodaemon
# 应该输出: nodaemon=true
```

### Q2: Worker 进程没有启动？

检查 PHP 路径和权限：
```bash
docker exec -it 容器名 bash
which php
su - nginx
/usr/bin/php /usr/share/nginx/html/think queue:listen --queue 队列名
```

### Q3: 修复函数没有执行？

确认函数定义和调用：
```bash
grep -n "fix_supervisord_config" Jenkins脚本路径
grep "fix_supervisord_config" Jenkins脚本路径 | grep -v "^#"
```

---

## 批量迁移

### 推荐顺序

1. **第一批**：测试环境（1-2 个项目）
2. **第二批**：低流量生产项目（2-3 个项目）
3. **第三批**：核心生产项目

### 批量修复配置文件

```bash
ssh -p 10015 172.18.151.165 << 'ENDSSH'
for conf in /data/docker_deploy/jwxt_test-config/*/supervisord.conf; do
    if [ -f "$conf" ]; then
        echo "修复: $conf"
        cp "$conf" "${conf}.backup-$(date +%Y%m%d-%H%M%S)"
        sed -i 's/nodaemon=false/nodaemon=true/g' "$conf"
        sed -i '/^\[eventlistener:stdout\]/,/^result_handler.*event_handler/d' "$conf"
    fi
done
ENDSSH
```

---

## 回滚方案

### 1. 快速回滚

```bash
ssh -p 10015 目标IP
cd /data/docker_deploy/项目名
cat .oldenv > .env
docker-compose -f docker-compose-项目名.yml restart
```

### 2. 恢复配置文件

```bash
cp /data/docker_deploy/jwxt_test-config/项目名/supervisord.conf.bak-最新时间 \
   /data/docker_deploy/jwxt_test-config/项目名/supervisord.conf
```

---

## 相关资源

- `jenkins-deploy-template.sh` - 完整脚本模板
- `COPY_PASTE_VERSION.sh` - 简洁版本
- `QUICK_MIGRATION_GUIDE.md` - 快速指南
- `fix-supervisord.sh` - 独立修复脚本

---

**镜像信息**:
- 地址: `114.115.130.46/jlkj-base/wyveo-nginx-php-fpm-7.2.34:v20261022`
- PHP: 7.2.34-66 (含 CVE 补丁)
- Nginx: 1.26.2
- 扩展: 43 个 (含 Swoole 4.8.13)
