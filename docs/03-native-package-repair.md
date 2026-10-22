# 3. 本机 PHP 7.2.x：APT / RPM 修复路线

适用于 **Linux 本机由包管理器安装的 PHP**。不是直接把一个 `php` ELF 文件覆盖到 `/usr/bin/php`。先确认真实服务二进制；CLI 版本不能代表 FPM、mod_php、Swoole、队列或 cron。

## 3.1 只读辨识

```bash
command -v php
readlink -f "$(command -v php)"
php -v
php --ini
php -m
cat /etc/os-release
uname -m
# Debian/Ubuntu，查询文件归属与包修订，不修改系统：
dpkg-query -S "$(readlink -f "$(command -v php)")"
dpkg-query -W -f='${binary:Package}\t${Version}\t${Architecture}\n' 'php7.2*'
# RPM 系：
rpm -qf "$(readlink -f "$(command -v php)")"
rpm -qa | grep -E '^(php|php72|alt-php72)'
```

分别执行适合当前系统的命令，不把缺少 dpkg/rpm 视为异常修复。可用 [清单工具](../tools/inventory.py) 降低采集范围；它不判断已修复。

只读检查真实服务的 `ExecStart`、FPM master PID 和 `/proc/<PID>/exe`，但不要公开完整 unit/进程命令行（可能含凭据）。分别确认 FPM pool、INI、socket、用户、扩展、日志、定时任务。没有包归属时转 [源码/面板路线](04-native-source-repair.md)。

## 3.2 修复前必须准备

- 已审批维护窗口/流量排空；备份应用、实际配置、unit、扩展清单、包版本和必要数据；验证恢复方式。
- 保存旧版本完整依赖包或可回滚快照；`apt-mark hold`、dnf history 和记录版本号本身都不是备份。
- 确认供应商确实支持该系统、架构和 PHP 7.2，并核对 [证据链](01-security-and-sources.md)。没有匹配包就停止安装，不能跨发行版硬装。
- 在相同 OS/架构/依赖的克隆环境先演练。老 OS、OpenSSL、扩展本身的 EOL 风险另列，PHP 补丁不修复整个主机。
- 升级可能由 maintainer scripts 自动重启服务、重写 INI 或改变 alternatives；事先安排排流，不承诺 apt 操作天然无中断。

## 3.3 APT 路线

在隔离测试机检查配置的仓库与候选：

```bash
apt-cache policy php7.2-cli php7.2-fpm php7.2-common php7.2-opcache
apt-cache madison php7.2-cli
```

更新索引、添加源属于变更，须在授权测试环境完成；从 Sury 或发行版文档取得正确 keyring 与发行代号，不把 Bookworm 源添加到 Ubuntu/RHEL。Ubuntu 的商业扩展支持是否覆盖目标包要以当期公告及合法订阅为准，本项目不预设可用性。

建立人工审核的 `packages.approved.txt`，每行一个真实 `package=full-version`，包含已安装的全部核心子包及需联动的扩展；不要只更新 CLI。该文件在本地生成，不提交机器专用清单。

下面是 **Bash 审核/安装流程**，不是仓库提供的已确定版本列表：

```bash
# 在明确选定的目标机运行；清单必须已逐项核验。
mapfile -t APPROVED < packages.approved.txt
((${#APPROVED[@]} > 0)) || { echo 'empty package plan' >&2; exit 1; }
# 先模拟；任何删除、跨 PHP 主版本或跨源变化都须重新审查。
sudo apt-get -s --no-remove install "${APPROVED[@]}"
# 只有模拟结果、备份和维护审批均通过后，才单独执行：
# sudo apt-get --no-remove install "${APPROVED[@]}"
```

安装命令故意保留为注释，无 `-y`、无 `--allow-unauthenticated`、无全系统 `upgrade`。模拟成功不是安装成功。包暂时不可取得时不要使用来源未知的直链替代。

## 3.4 RPM 路线

确认发行版、仓库、模块 stream 和包族：系统 PHP、SCL、alt-php 是不同布局，不可混用。获取供应商对应 CVE 的完整修订说明和合法包，使用其可信密钥验证 `rpm -K`，保存 NEVRA、源 RPM 和 hash。

先在克隆环境用 `dnf --assumeno upgrade <经审核的包集合>` 审查事务（旧系统用其受支持包管理器），评估依赖和模块 stream 变化，再批准实际安装。不要用 `--nogpgcheck`、`--allowerasing`、`rpm --force --nodeps` 绕过错误。

没有供应商确认的 7.2 补丁，不能根据“CloudLinux/TuxCare 支持旧 PHP”推断本机已能安装；付费获取及再分发均需授权。

## 3.5 安装后验收

1. 核对实际包修订、来源、CLI/FPM 文件与哈希；配置测试通过。
2. 维护窗口内启动新 FPM/重启相关服务；检查实际运行 `/proc/<PID>/exe`，包括仍显示 `(deleted)` 的旧进程。不能仅用新文件覆盖旧路径就结束。
3. 实测 Nginx/Apache → FPM：版本、SAPI、扩展、有效 INI；内部一次性白名单检查页用后移除，不公开 phpinfo。
4. 分别重启/切换旧 CLI 队列、Swoole、计划任务入口；绝对路径调用不能只靠 PATH 或 alternatives 更新。
5. 按 [兼容性矩阵](06-compatibility-and-testing.md) 验证 Session、上传、支付沙箱、缓存序列化和数据库行为；观察错误与内存。

mod_php 是不同 SAPI：需独立验证 Apache MPM、模块包和重启；本仓库的 FPM 验收不能替代它。

## 3.6 回滚

还原的是一整套经过确认的包/配置/扩展/服务组合，不只回退 `php` 一个文件。缓存或 Session 格式若已变化，先确认兼容。

优先回到另一份已修补构建。只能回到有漏洞旧包时，需重新隔离、缓解和风险审批；“恢复服务”不能标记“修复完成”。详见 [发布回滚](08-release-and-rollback.md)。
