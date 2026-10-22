# 示例与模板的边界

[security-evidence.example.json](security-evidence.example.json) 是字段示例，不是已解析锁文件、供应商证明或发布许可。null/空数组表示尚未取得证据，不应复制后只改状态就发布。

当前没有提供带假 digest 的可运行 Compose/K8s 样例，也没有把未知包版本硬编码成 Dockerfile。对应实现任务见 [Codex 任务书](../docs/09-codex-execution-plan.md)。
