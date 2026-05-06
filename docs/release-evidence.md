# Fabushi 发布覆盖证据说明

这份文档专门说明：当主控、人工巡检或后续自动化要判断“某个修复是否已经被正式发布覆盖”时，应该读取哪些公开证据、按什么顺序判断，以及哪些入口不能误用。

## 为什么需要这份文档

Fabushi 当前对 issue 的完成标准不是“代码 merged 就算结束”，而是要继续确认：

- `main` 上的修复是否已经进入新的 GitHub Release
- 对 iOS 来说，TestFlight 上传结果是否已经有公开可核对证据
- 公开发布时间是否晚于相关修复 PR 的 `merged_at`

过去几轮主控里，一个容易重复出现的误区是：把 `TESTFLIGHT_UPLOAD_STATUS.txt` 当成仓库文件树里的固定文件去查。这样即使 workflow 正常生成了发布证据，也会因为查错入口而得到 `404` 或“文件不存在”的假结论。

## 正确证据来源

发布覆盖判断默认读取以下四类证据：

1. 相关修复 PR 的 `merged_at` 时间
2. GitHub `latest release` 或目标 release 的 `published_at` 时间
3. release 资产中的 `TESTFLIGHT_UPLOAD_STATUS.txt`
4. 必要时再回看对应 `Publish CD packages to GitHub Release` workflow run

## 关于 TESTFLIGHT_UPLOAD_STATUS.txt 的关键规则

`TESTFLIGHT_UPLOAD_STATUS.txt` 由 `.github/workflows/publish-cd-release.yml` 在发包流程里生成，并作为 release asset 附加到 GitHub Release。

这意味着：

- 它不是 `main` 分支文件树中的固定文件
- 用仓库 contents API 直接读取 `main:TESTFLIGHT_UPLOAD_STATUS.txt`，返回 `404` 是正常现象，不代表 TestFlight 上传没有发生
- 正确入口是：先定位目标 GitHub Release，再读取该 release 附带的 `TESTFLIGHT_UPLOAD_STATUS.txt` 资产

## 推荐判断顺序

1. 记录修复 PR 的 `merged_at`，统一使用 UTC 绝对时间
2. 读取当前公开 latest release 的 `published_at`
3. 读取该 release 资产 `TESTFLIGHT_UPLOAD_STATUS.txt` 中的：
   - `status`
   - `reason`
   - `source_sha`
   - `build_number`
   - `uploaded_at`
4. 比较公开 release / TestFlight 证据时间，是否晚于相关修复 merge 时间
5. 只有公开证据时间明确晚于修复 merge 时间时，才可以把对应 issue 判成“已发布覆盖”

## 状态解释

### `status=uploaded`

表示 IPA 已被 App Store Connect 接收。此时仍应结合：

- `uploaded_at` 的绝对时间
- 该 release 的 `published_at`
- 对应修复 PR 的 `merged_at`

再判断 issue 是否真的已经被用户可验证的公开发布覆盖。

### `status=skipped`

表示没有形成可用的 TestFlight 上传结果，常见原因包括：

- `ios_signing_not_configured`
- `app_store_connect_credentials_not_configured`

这类状态不能作为“iOS 发布覆盖已经完成”的证据。

### `status=failed`

表示上传明确失败。这时应把发布链继续视为未闭环，并优先下钻失败根因。

### 没有这份资产

如果目标 release 没有 `TESTFLIGHT_UPLOAD_STATUS.txt` 资产，默认按“发布证据不完整”处理，而不是默认当作成功。

## 判定纪律

- 不要只因为 PR merged 就关闭真实用户 issue
- 不要只因为某条 workflow success 就跳过 release / TestFlight 证据
- 不要使用“今天”“刚刚”“最新”这类相对时间代替 UTC 绝对时间
- 如果记忆、issue 评论或运行上下文里的旧版本号和当前 latest release 不一致，先重新以公开 release 证据为准，再继续判断

## 与仓库现有流程的关系

当前仓库里与这条规则直接相关的资产包括：

- `.github/workflows/publish-cd-release.yml`
- `.github/scripts/check-publish-cd-release.sh`
- `docs/release-controller.md`
- GitHub Releases 页面及其资产

这份文档是 `docs/release-controller.md` 的补充说明，重点不是重复发布流程本身，而是把“如何读取发布覆盖证据”这件事单独讲清楚，减少后续主控巡检继续误判入口。