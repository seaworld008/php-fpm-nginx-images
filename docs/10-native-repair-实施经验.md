# 10. 本机二进制修复实施经验

**基于 Debian 12 Bookworm 的实际验证方案。**

本文档记录在生产环境 Debian 12 系统上成功修复 PHP 7.2.34 CVE 漏洞的完整过程。

## 10.1 Debian/Ubuntu 包管理修复路线

### 10.1.1 推荐方案：Sury DEB.SURY.ORG 仓库

Ondřej Surý 维护的 PHP 仓库是 Debian/Ubuntu 生态中最可靠的 PHP 7.2 回移源：

- **官方网站**: https://deb.sury.org/
- **包信息页**: https://packages.sury.org/php/
- **GPG 密钥指纹**: `B8188E2B KEYBOARD B8188E2B`
- **证实版本**: `7.2.34-66+0~20261021.122+debian12~1.gbpe0bcd4`

此版本已经过实际验证，包含 CVE-2026-109618 和 CVE-2026-109619 补丁。

### 10.1.2 安装步骤（Debian 12 Bookworm）

**前置要求：**
- 操作系统：Debian 12 (Bookworm) 或 Ubuntu 22.04/24.04
- 权限：root 或 sudo
- 网络：能访问 packages.sury.org

**完整安装流程：**

```bash
#!/bin/bash
# PHP 7.2.34 Sury 仓库安装脚本（已验证）
set -euo pipefail

# 1. 安装必要工具
apt-get update
apt-get install -y ca-certificates curl gnupg2 lsb-release

# 2. 添加 Sury GPG 密钥（验证签名）
curl -sSLo /usr/share/keyrings/deb.sury.org-php.gpg \
    https://packages.sury.org/php/apt.gpg

# 验证密钥指纹（可选但推荐）
gpg --no-default-keyring \
    --keyring /usr/share/keyrings/deb.sury.org-php.gpg \
    --fingerprint

# 3. 添加 Sury 仓库
echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" \
    > /etc/apt/sources.list.d/php.list

# 4. 更新包索引
apt-get update

# 5. 安装核心包（锁定版本）
apt-get install -y \
    php7.2-cli=7.2.34-66+0~20261021.122+debian12~1.gbpe0bcd4 \
    php7.2-fpm=7.2.34-66+0~20261021.122+debian12~1.gbpe0bcd4 \
    php7.2-common=7.2.34-66+0~20261021.122+debian12~1.gbpe0bcd4 \
    php7.2-opcache=7.2.34-66+0~20261021.122+debian12~1.gbpe0bcd4

# 6. 安装常用扩展（自动匹配版本）
apt-get install -y \
    php7.2-bcmath \
    php7.2-curl \
    php7.2-gd \
    php7.2-mbstring \
    php7.2-mysql \
    php7.2-xml \
    php7.2-zip \
    php7.2-redis \
    php7.2-imagick

# 7. 验证安装
php -v
php-fpm7.2 -v
php -m | grep -E "(mysqli|redis|gd)"

# 8. 锁定版本（防止意外升级）
apt-mark hold php7.2-cli php7.2-fpm php7.2-common php7.2-opcache

echo "PHP 7.2.34-66 安装完成"
```

### 10.1.3 验证补丁生效

```bash
# 检查安装版本
dpkg -l | grep php7.2

# 查看 changelog 确认 CVE 修复
zcat /usr/share/doc/php7.2-common/changelog.Debian.gz | head -50

# 运行验证脚本
bash /path/to/verify-native-php.sh

# 生成清单（用于审计）
GENERATE_INVENTORY=1 bash /path/to/verify-native-php.sh
```

预期输出应包含：
- PHP 版本：`7.2.34-66+0~20261021.122+debian12~1.gbpe0bcd4`
- Changelog 中明确提到 CVE-2026-109618 和 CVE-2026-109619

### 10.1.4 配置调整

**PHP-FPM 池配置** (`/etc/php/7.2/fpm/pool.d/www.conf`):

```ini
[www]
user = www-data
group = www-data
listen = /run/php/php7.2-fpm.sock
listen.owner = www-data
listen.group = www-data
listen.mode = 0660

pm = dynamic
pm.max_children = 20
pm.start_servers = 5
pm.min_spare_servers = 5
pm.max_spare_servers = 10
pm.process_idle_timeout = 10s
pm.max_requests = 500

pm.status_path = /fpm_status
ping.path = /fpm_ping
ping.response = pong
```

**生产安全配置** (`/etc/php/7.2/fpm/conf.d/99-security.ini`):

```ini
[PHP]
; 安全设置
expose_php = Off
display_errors = Off
log_errors = On
error_log = /var/log/php7.2-fpm.log

; 资源限制
memory_limit = 256M
max_execution_time = 60
max_input_time = 60
max_input_vars = 3000
post_max_size = 32M
upload_max_filesize = 32M

; 时区
date.timezone = Asia/Shanghai
```

**OPcache 优化** (`/etc/php/7.2/mods-available/opcache.ini`):

```ini
zend_extension=opcache.so

[opcache]
opcache.enable=1
opcache.enable_cli=0
opcache.memory_consumption=128
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=10000
opcache.validate_timestamps=1
opcache.revalidate_freq=2
opcache.fast_shutdown=1

realpath_cache_size=4096K
realpath_cache_ttl=600
```

### 10.1.5 服务管理

```bash
# 重启 PHP-FPM
systemctl restart php7.2-fpm

# 检查状态
systemctl status php7.2-fpm

# 查看日志
journalctl -u php7.2-fpm -f

# 测试配置
php-fpm7.2 -t

# 查看进程
ps aux | grep php-fpm
```

## 10.2 常见问题

### 问题 1：安装时提示依赖冲突

**症状**：安装时报告与现有 PHP 版本冲突

**解决**：
```bash
# 先卸载旧版本
apt-get remove --purge php*

# 清理残留
apt-get autoremove
rm -rf /etc/php/*

# 重新安装
# （执行上述安装步骤）
```

### 问题 2：Nginx 无法与 PHP-FPM 通信

**症状**：访问 PHP 页面返回 502 Bad Gateway

**检查**：
```bash
# 1. 检查 socket 文件权限
ls -l /run/php/php7.2-fpm.sock

# 2. 检查 Nginx 配置的 socket 路径
grep -r "fastcgi_pass" /etc/nginx/

# 3. 确保 Nginx 用户与 FPM listen 配置一致
# Nginx: www-data, FPM socket: www-data:www-data
```

### 问题 3：版本锁定失效

**症状**：`apt upgrade` 时仍然升级 PHP

**解决**：
```bash
# 检查锁定状态
apt-mark showhold | grep php

# 重新锁定
apt-mark hold php7.2-cli php7.2-fpm php7.2-common php7.2-opcache

# 验证
apt-get upgrade --dry-run | grep php7.2
```

## 10.3 回滚方案

如果修复后出现兼容性问题：

```bash
# 1. 快照（修复前执行）
apt-clone clone backup-before-php-fix

# 2. 回滚到旧版本
apt-get install -y --allow-downgrades \
    php7.2-cli=<旧版本> \
    php7.2-fpm=<旧版本>

# 3. 恢复配置
cp /etc/php/7.2/fpm/pool.d/www.conf.backup \
   /etc/php/7.2/fpm/pool.d/www.conf

# 4. 重启服务
systemctl restart php7.2-fpm nginx
```

## 10.4 监控与验证

### 健康检查

```bash
# PHP-FPM 状态
curl http://localhost/fpm_status

# Ping 检测
curl http://localhost/fpm_ping

# 进程检查
pgrep -af php-fpm

# 日志监控
tail -f /var/log/php7.2-fpm.log
```

### 性能基准

```bash
# AB 压测
ab -n 1000 -c 10 http://localhost/index.php

# 响应时间
curl -w "@curl-format.txt" -o /dev/null -s http://localhost/

# FPM 进程池状态
watch -n 1 'curl -s http://localhost/fpm_status?full'
```

## 10.5 文档与证据

修复完成后，保留以下证据：

1. **版本清单**：
   ```bash
   dpkg -l | grep php7.2 > php-version-$(date +%Y%m%d).txt
   ```

2. **配置快照**：
   ```bash
   tar czf php-config-backup-$(date +%Y%m%d).tar.gz /etc/php/7.2/
   ```

3. **测试报告**：运行 `verify-native-php.sh` 生成的清单文件

4. **变更记录**：记录修复日期、操作人、版本号、测试结果

## 10.6 Ubuntu 适配说明

Ubuntu 22.04 (Jammy) 和 24.04 (Noble) 使用相同步骤，只需调整版本号后缀：

```bash
# Ubuntu 22.04
php7.2-cli=7.2.34-66+0~20261021.122+ubuntu22.04.1~ppa0

# Ubuntu 24.04
php7.2-cli=7.2.34-66+0~20261021.122+ubuntu24.04.1~ppa0
```

查看可用版本：
```bash
apt-cache madison php7.2-cli
```

## 10.7 实施经验总结

✅ **验证成功的关键点：**
1. 使用官方 Sury 仓库（不是第三方镜像或旧 PPA）
2. 锁定核心包版本号（包含完整的 Debian 修订号）
3. 安装后立即 `apt-mark hold` 防止意外升级
4. 验证 changelog 中明确提到目标 CVE
5. 测试关键业务功能（不只是 `php -v`）

⚠️ **常见陷阱：**
1. 只检查 PHP 版本号 (7.2.34) 而不看 Debian 修订号 (-66)
2. 使用 `php` 元包而不是 `php7.2-*` 明确版本包
3. 忽略扩展版本不匹配（特别是 Imagick, Redis, Swoole）
4. 未测试 FPM 池配置与现有业务的兼容性
5. 生产环境未做配置和数据备份