# 验收报告模板（不是实际测试结果）

日期 / 执行者 / 对应提交：未填写。
OS / 架构 / 制品 hash或digest / 完整 PHP 包修订：未填写。

| 检查 | 状态 | 命令 / 证据 / 范围 |
|---|---|---|
| 来源、签名、两个 CVE 分别核验 | NOT_TESTED | |
| 实际构建、版本与依赖 | NOT_TESTED | |
| CLI / 真实 FPM 请求 | NOT_TESTED | |
| 扩展与序列化 | NOT_TESTED | |
| 路由、上传、鉴权和业务 | NOT_TESTED | |
| 进程生命周期和探针 | NOT_TESTED | |
| 资源、压测与后端预算 | NOT_TESTED | |
| 本机服务、队列、cron与面板 | NOT_TESTED | |
| 回滚演练 | NOT_TESTED | |
| SBOM、扫描、密钥与许可 | NOT_TESTED | |

状态使用 PASS / FAIL / NOT_TESTED / NOT_APPLICABLE（说明理由）。每个 PASS 必须有命令、时间、原始输出引用和实际制品关联。

## 每个 CVE 的覆盖与限制

分别填写证据状态；不能把配置缓解写成完整修复。

## 未完成、残余风险与阻塞

当前模板无实际结果，不具备发布依据。

## 回滚与授权

填写回滚目标是否已修补，配置/数据兼容性、审批范围和生产发布决定。
