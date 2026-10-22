# 6. 扩展兼容与验证矩阵

两份通用需求档案源于遗留 web/worker 场景：[web](../requirements/extensions-web.txt)、[worker](../requirements/extensions-worker.txt)、[并集](../requirements/extensions-union.txt)。仅代表需求，不是已构建支持清单。普通扩展与 Zend OPcache 要分别核验。

## 6.1 扩展策略

优先同一补丁核心的 full-compat 构建；若 MongoDB/Swoole 等约束冲突，分为 web/worker 派生制品并解释原因，不静默删除模块。

固定每个扩展的版本、来源、hash、PHP API、NTS/ZTS、架构、依赖和编译特性；通过 PECL/供应商元数据核查 PHP 7.2 支持范围。不是所有最新版扩展都支持 7.2。[S19]

逐个核验：Redis/igbinary 的 serializer 与历史缓存；MongoDB driver/Composer library/服务器协议和 TLS；Swoole 版本/API/常驻任务；memcached 序列化；imagick/GD 格式字体与 policy；PDO 事务/字符集；IMAP/intl/sodium/zip/SQLite 功能。WDDX 等旧功能需列残余风险，未经业务审计不擅自删。

MongoDB `already loaded` 等问题检查 php.ini、扫描目录、包生成 INI 和手工链接，保留唯一来源；隐藏 Warning 不算解决。

## 6.2 必测类别

| 类别 | 通过依据 |
|---|---|
| 来源与补丁 | 每个 CVE 的公告/源包/补丁/制品映射和隔离回归 |
| 版本与配置 | CLI/FPM/Nginx 与锁一致，无未知指令、加载错误或依赖缺失 |
| 真正 FPM 请求 | 白名单 PHP_VERSION、SAPI、扩展及 INI；不可用 CLI 代替 |
| 路由与安全 | 首页、路径/query、404、上传、禁止任意 PHP、隐藏文件与管理端点 |
| 核心业务 | 登录、Session、数据库事务、队列、导入导出、测试支付幂等 |
| 生命周期 | master 意外退出、worker 恢复、TERM 优雅停止、启动失败与超时 |
| 部署限制 | 只读 rootfs/挂载权限、资源 limits、临时磁盘、secret 更新方式 |
| 性能 | 同资源基线、负载曲线、延迟/吞吐/内存、后端预算 |
| 本机专项 | 绝对路径、systemd/面板、CLI/cron/Swoole、全部旧进程排空 |

对每项记录 PASS / FAIL / NOT_TESTED / NOT_APPLICABLE，最后一种要给理由；没有原始输出就不能填 PASS。环境不完整时列阻塞，不测试生产来凑结果。

## 6.3 回归边界

只运行已审阅的无害上游/供应商回归测试，使用隔离网络、资源和时间限制。不要下载未知 exploit 执行，不在公网或生产验证 RCE/OOM。

某个用例未触发并不证明不存在其他路径；编译成功、扫描器无告警、版本数字改变都不能替代补丁证据。生成报告使用 [模板](../templates/validation-report.md)。
