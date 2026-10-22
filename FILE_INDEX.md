# 📚 Jenkins 项目迁移工具包 - 文件索引

## 🎯 我应该看哪个文件？

### 场景 1：我要快速迁移一个 Jenkins 项目
👉 **看这个**: [COPY_PASTE_VERSION.sh](./COPY_PASTE_VERSION.sh)
- 超简洁版本，只需复制粘贴 3 段代码
- 适合：快速上手，时间紧急

### 场景 2：我要了解完整的迁移流程
👉 **看这个**: [HOW_TO_MIGRATE_JENKINS_PROJECTS.md](./HOW_TO_MIGRATE_JENKINS_PROJECTS.md)
- 详细的步骤说明
- 常见问题解答
- 验证方法
- 适合：第一次迁移，需要理解原理

### 场景 3：我要一个完整的 Jenkins 脚本模板
👉 **看这个**: [jenkins-deploy-template.sh](./jenkins-deploy-template.sh)
- 完整的、可直接使用的 Jenkins 发布脚本
- 包含所有注释和说明
- 适合：创建新项目或重构现有脚本

### 场景 4：我要手动修复配置文件
👉 **看这个**: [fix-supervisord.sh](./fix-supervisord.sh)
- 独立的配置修复脚本
- 可单独运行
- 适合：批量修复、故障排查

### 场景 5：我要看图文并茂的快速指南
👉 **看这个**: [QUICK_MIGRATION_GUIDE.md](./QUICK_MIGRATION_GUIDE.md)
- 3 步快速迁移
- 图表和示例
- 批量迁移方案
- 适合：需要打印或分享给团队

---

## 📂 文件清单

### 核心工具（必看）

| 文件名 | 大小 | 用途 | 推荐阅读时间 |
|--------|------|------|-------------|
| **COPY_PASTE_VERSION.sh** | 4.2KB | 超简洁复制粘贴版本 | 2 分钟 |
| **HOW_TO_MIGRATE_JENKINS_PROJECTS.md** | 4.0KB | 完整迁移指南 | 10 分钟 |
| **jenkins-deploy-template.sh** | 12KB | 完整脚本模板 | 5 分钟 |
| **fix-supervisord.sh** | 6.3KB | 配置修复脚本 | 3 分钟 |
| **QUICK_MIGRATION_GUIDE.md** | 6.1KB | 快速指南 | 5 分钟 |

### 项目文档

| 文件名 | 用途 |
|--------|------|
| **START_HERE.md** | 项目总览和入口 |
| **README.md** | 镜像信息和使用说明 |
| **DEPLOYMENT_GUIDE.md** | 部署指南 |
| **IMPLEMENTATION_SUMMARY.md** | 实施总结 |
| **FINAL_SUMMARY.md** | 最终总结报告 |

### 辅助工具

| 文件名 | 用途 |
|--------|------|
| **verify-image.sh** | 镜像验证脚本 |
| **quick-push.sh** | 快速推送脚本 |
| **PUSH_AND_PR.sh** | Git 推送和 PR 脚本 |

---

## 🚀 快速开始流程

### 新手（第一次迁移）

```
1. 阅读 HOW_TO_MIGRATE_JENKINS_PROJECTS.md（10 分钟）
   ↓
2. 选择测试项目
   ↓
3. 复制 COPY_PASTE_VERSION.sh 中的代码（2 分钟）
   ↓
4. 修改 3 个地方：函数定义、Dockerfile、发布逻辑
   ↓
5. 测试构建
   ↓
6. 验证（HOW_TO_MIGRATE_JENKINS_PROJECTS.md 中的验证清单）
```

### 熟手（已经迁移过几个项目）

```
1. 打开 COPY_PASTE_VERSION.sh
   ↓
2. 复制 fix_supervisord_config 函数
   ↓
3. 修改 Dockerfile 基础镜像
   ↓
4. 在发布逻辑中调用 fix_supervisord_config
   ↓
5. 构建 + 验证
```

### 批量迁移

```
1. 阅读 QUICK_MIGRATION_GUIDE.md 的"批量迁移"部分
   ↓
2. 使用 fix-supervisord.sh 批量修复配置文件
   ↓
3. 逐个项目修改 Jenkins 脚本
   ↓
4. 分批部署（测试 → 生产）
```

---

## 💡 常见问题快速索引

| 问题 | 查看文件 | 章节 |
|------|---------|------|
| 容器一直重启？ | HOW_TO_MIGRATE_JENKINS_PROJECTS.md | Q1 |
| Worker 进程没有启动？ | HOW_TO_MIGRATE_JENKINS_PROJECTS.md | Q2 |
| 修复函数没有执行？ | HOW_TO_MIGRATE_JENKINS_PROJECTS.md | Q3 |
| 配置路径不匹配？ | QUICK_MIGRATION_GUIDE.md | 高级：自定义配置路径 |
| 批量修复所有项目？ | QUICK_MIGRATION_GUIDE.md | 批量迁移多个项目 |
| 需要回滚？ | HOW_TO_MIGRATE_JENKINS_PROJECTS.md | 回滚方案 |

---

## 🎓 学习路径

### 路径 1：快速实战（30 分钟）
```
START_HERE.md → COPY_PASTE_VERSION.sh → 实际操作 → 验证
```

### 路径 2：深入理解（1 小时）
```
START_HERE.md → README.md → HOW_TO_MIGRATE_JENKINS_PROJECTS.md 
→ jenkins-deploy-template.sh → 实际操作 → DEPLOYMENT_GUIDE.md
```

### 路径 3：团队推广（2 小时）
```
FINAL_SUMMARY.md → QUICK_MIGRATION_GUIDE.md → 准备演示环境 
→ HOW_TO_MIGRATE_JENKINS_PROJECTS.md → 编写内部文档 → 培训团队
```

---

## 🔧 故障排查流程

```
遇到问题
    ↓
查看容器日志
docker logs -f 容器名
    ↓
检查进程状态
docker exec 容器名 supervisorctl status
    ↓
查看 HOW_TO_MIGRATE_JENKINS_PROJECTS.md 的"常见问题"部分
    ↓
检查配置是否修复成功
cat supervisord.conf | grep nodaemon
    ↓
仍未解决？查看详细日志
docker logs --tail 200 容器名
    ↓
手动进入容器排查
docker exec -it 容器名 bash
```

---

## 📞 获取帮助

### 自助资源
1. **快速问题**: 查看 [HOW_TO_MIGRATE_JENKINS_PROJECTS.md](./HOW_TO_MIGRATE_JENKINS_PROJECTS.md) 的常见问题部分
2. **配置问题**: 查看 [fix-supervisord.sh](./fix-supervisord.sh) 的详细注释
3. **完整文档**: 查看 `docs/11-container-build-实施经验.md`

### 验证清单
使用 [HOW_TO_MIGRATE_JENKINS_PROJECTS.md](./HOW_TO_MIGRATE_JENKINS_PROJECTS.md) 中的"验证清单"部分

---

## 📊 文件依赖关系

```
START_HERE.md (入口)
    │
    ├─→ QUICK_MIGRATION_GUIDE.md (快速指南)
    │       │
    │       ├─→ COPY_PASTE_VERSION.sh (最简版)
    │       └─→ fix-supervisord.sh (修复工具)
    │
    ├─→ HOW_TO_MIGRATE_JENKINS_PROJECTS.md (完整指南)
    │       │
    │       └─→ jenkins-deploy-template.sh (完整模板)
    │
    ├─→ README.md (镜像信息)
    │
    └─→ DEPLOYMENT_GUIDE.md (部署指南)
            │
            └─→ verify-image.sh (验证工具)
```

---

## 🎯 推荐使用方式

### 场景 A：快速上手（5 分钟）
```bash
# 1. 打开复制粘贴版
cat COPY_PASTE_VERSION.sh

# 2. 复制 3 段代码到 Jenkins 脚本

# 3. 构建测试
```

### 场景 B：首次迁移（30 分钟）
```bash
# 1. 阅读完整指南
less HOW_TO_MIGRATE_JENKINS_PROJECTS.md

# 2. 查看模板脚本
less jenkins-deploy-template.sh

# 3. 修改并测试

# 4. 验证
按照文档的验证清单逐项检查
```

### 场景 C：批量迁移（1-2 小时）
```bash
# 1. 阅读批量迁移方案
less QUICK_MIGRATION_GUIDE.md

# 2. 运行批量修复脚本
bash fix-supervisord.sh

# 3. 制定迁移计划

# 4. 分批执行
```

---

## ✅ 成功标准

迁移成功的标志：

1. ✅ 容器状态为 `Up`（不是 `Restarting`）
2. ✅ 所有进程状态为 `RUNNING`
3. ✅ 日志中没有 `supervisor_stdout` 错误
4. ✅ Web 服务正常响应
5. ✅ 队列 Worker 正常工作

验证命令：
```bash
docker ps | grep 容器名
docker exec 容器名 supervisorctl status
docker logs --tail 50 容器名
curl http://目标IP:端口
```

---

## 📝 总结

| 如果您想... | 就看... | 需要时间 |
|------------|--------|---------|
| 快速迁移 | COPY_PASTE_VERSION.sh | 5 分钟 |
| 深入理解 | HOW_TO_MIGRATE_JENKINS_PROJECTS.md | 30 分钟 |
| 获取完整模板 | jenkins-deploy-template.sh | 10 分钟 |
| 批量修复配置 | fix-supervisord.sh | 15 分钟 |
| 制定迁移计划 | QUICK_MIGRATION_GUIDE.md | 20 分钟 |

**推荐路径**: COPY_PASTE_VERSION.sh → 实际操作 → HOW_TO_MIGRATE_JENKINS_PROJECTS.md（遇到问题时）

---

**最后更新**: 2026-10-22  
**适用镜像**: wyveo-nginx-php-fpm-7.2.34:v20261022  
**相关文档**: 查看 `docs/` 目录获取更多详细信息
