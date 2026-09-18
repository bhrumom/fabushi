# Runbook：拆分平台 GitHub 仓库

## 使用条件

- `FAB-P0013` 已合入 canonical `main`，并完成目标矩阵审阅。
- 源仓库 SHA、目标仓库名、visibility、source roots 和排除清单已冻结。
- 已确认不会导出 secrets、cookie、签名材料、`.env`、测试账户状态或构建缓存。

## 执行步骤

1. 在 GitHub-hosted runner 创建 fresh mirror，固定源 URL 和 canonical SHA。
2. 校验 `git-filter-repo` 版本、目标路径清单和许可证/provenance 清单。
3. 对每个目标生成独立历史或明确标记为 snapshot；保存 source/target refs 映射。
4. 运行 forbidden-path、secret、license、tree/object checksum 和 manifest diff 检查。
5. 将验证通过的目标推送到对应 GitHub 仓库，设置默认分支、保护规则、CODEOWNERS 和仓库级 CI。
6. 先发布 Core，再发布 CLI/平台 candidate；验证构建、安装包、模拟用户旅程和 Release。
7. 生产入口切换后保存 updater、部署、商店和 CLI 下载入口的 readback。

## 回滚

如果路径、依赖、构建、签名、E2E、Release 或入口切换失败，停止该平台切换，恢复旧入口和源
仓库 refs；不要删除源目录、Release 或不可变 tag。修正清单后从相同源 SHA 重新执行。

## 证据

将 workflow run、job、日志摘要、manifest、checksums、artifacts、Release URL、时间戳和失败/回滚
结果写入 `evidence/PRS-005/`、`evidence/PRS-006/` 或 `evidence/PRS-007/`，并在对应 task record
中回填链接。
