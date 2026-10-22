# Agent instructions

先读 README、docs/00-project-status.md、docs/01-security-and-sources.md 和 docs/09-codex-execution-plan.md。

- 文档是计划，不是已验证的制品。默认所有未实测项目为 NOT_TESTED，补丁为 UNVERIFIED。
- 不猜 SSH 目标、镜像 digest、补丁哈希、供应商修复范围或扩展版本。
- 不把“完善仓库”扩大成生产变更；构建、远程检查、推送制品、上线分别确认已有授权范围。
- 不发布生产数据、私有归档、完整环境变量或密钥。不要提交本地 inventory。
- 不绕过签名/TLS，不使用 curl | sh，不执行来源不明 exploit，不自动购买订阅。
- 修改工具先写测试；提交前运行 unittest 和 check_docs，记录实际输出。
- 保持原项目历史；不用 force push。证据不足时继续可独立完成的工作，但不得发布安全声明。
