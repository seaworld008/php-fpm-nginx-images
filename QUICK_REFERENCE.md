# 快速参考卡片

## 🎯 核心信息

### 镜像信息
- **镜像标签**: `v20261022`
- **PHP 版本**: `7.2.34-66+0~20261021.122+debian12~1.gbpe0bcd4`
- **Nginx 版本**: `1.26.2`
- **Debian 版本**: `12 (Bookworm)`

### CVE 修复状态
- ✅ CVE-2026-109618 (XML 解析器漏洞)
- ✅ CVE-2026-109619 (Filter 扩展漏洞)

---

## ⚡ 快速迁移（3 步）

### 1️⃣ 修改 `docker_devlop()` 函数

在函数开头添加（约 20 行代码）：

```bash
docker_devlop(){
    # 修复 supervisord 配置
    ssh -p $SSH_PORT $destination_IP "
      case '$project_name' in
        project_a) config_file='/path/to/config/project_a/supervisord.conf' ;;
        project_b) config_file='/path/to/config/project_b/supervisord.conf' ;;
        *) config_file='/path/to/config/\${project_name}/supervisord.conf' ;;
      esac
      
      if [ -f \$config_file ]; then
        cp \$config_file \${config_file}.bak-\$(date +%Y%m%d-%H%M%S)
        sed -i 's/nodaemon=false/nodaemon=true/g' \$config_file
        sed -i '/^\[eventlistener:stdout\]/,/^result_handler.*event_handler/d' \$config_file
      fi
    "
    
    # ... 原有逻辑保持不变
}
```

### 2️⃣ 更新 Dockerfile 基础镜像

```dockerfile
FROM registry.example.com/base/php:v20261022
COPY --chown=nginx:nginx . /usr/share/nginx/html/
COPY ./default.conf /etc/nginx/conf.d/default.conf
```

### 3️⃣ 触发 Jenkins 构建

保存配置后，点击"立即构建"即可。

---

## 🔍 快速验证（4 个命令）

在目标服务器上执行：

```bash
# 1. 检查容器状态
docker ps | grep your_project_name
# 预期: Status 为 "Up"

# 2. 检查进程状态
docker exec your_container_name supervisorctl status
# 预期: 所有进程 RUNNING

# 3. 检查 PHP 版本（验证 CVE）
docker exec your_container_name php -v
# 预期: 包含 "7.2.34-66"

# 4. 测试 Web 服务
curl http://your_domain/
# 预期: 正常响应
```

---

## 🚨 问题速查

### 容器不断重启
```bash
# 查看日志
docker logs your_container_name

# 常见原因: supervisord 配置错误
# 解决: 重新触发 Jenkins 构建（自动修复）
```

### FROM 指令错误
```bash
# 错误示例
registry.example.com/base/php:v20261022  # ❌ 缺少 FROM

# 正确示例
FROM registry.example.com/base/php:v20261022  # ✅
```

### 配置路径不匹配
```bash
# 在 docker_devlop() 的 case 语句中添加项目映射
your_project_name)
  config_file='/path/to/your/supervisord.conf'
  ;;
```

---

## 📊 验证清单（打勾即可）

### 构建阶段
- [ ] Dockerfile FROM 指令正确
- [ ] 镜像构建成功
- [ ] 镜像推送到 Harbor

### 部署阶段
- [ ] 容器状态为 "Up"
- [ ] supervisorctl status 全部 RUNNING
- [ ] 日志无错误
- [ ] PHP 版本包含 "-66"

### 业务验证
- [ ] Web 服务响应正常
- [ ] 管理后台可访问
- [ ] 队列 Worker 正常工作
- [ ] 关键业务功能正常

---

## 📚 详细文档

- **完整指南**: [PRODUCTION_EXPERIENCE.md](./PRODUCTION_EXPERIENCE.md)
- **迁移指南**: [HOW_TO_MIGRATE_JENKINS_PROJECTS.md](./HOW_TO_MIGRATE_JENKINS_PROJECTS.md)
- **脚本模板**: [jenkins-deploy-template.sh](./jenkins-deploy-template.sh)
- **架构文档**: [CLAUDE.md](./CLAUDE.md)

---

## 💡 最佳实践

1. **先测试环境**，再生产环境
2. **一个项目一个项目**迁移，不要批量
3. **观察 24 小时**无问题后再迁移下一个
4. **保留旧镜像** 7 天用于回滚
5. **记录每次部署**的结果和问题

---

## 🎉 成功案例

**项目**: 教务管理系统（ThinkPHP 5）  
**用时**: 40 分钟  
**中断**: 0 秒  
**状态**: ✅ 成功运行，CVE 已修复

---

**快速参考版本**: v1.0  
**更新日期**: 2026-10-22
