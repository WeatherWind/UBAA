# 2026-11-27 iOS 实时活动设计与实施准备

## 本次工作内容

- 盘点主目录和两个 iOS 对比工作树，确认 `ios-notification-center-widget` → `ios-live-activity-course-center` → `ios-live-activity-stretched-small` 是线性演进，不是可独立合并的并行实现。
- 审查现有 ActivityKit、锁屏、灵动岛、课表快照和同步代码，发现并记录私密下一项标记未进入 `ScheduleLiveFace`、活动去重键缺少隐私和深链字段两个缺口。
- 与维护者确认视觉方向：锁屏课名优先、地点次行、右侧只有一处倒计时；灵动岛展开、紧凑、最小形态分别设计。
- 生成合成数据视觉预览，维护者确认课名优先版本。预览只保存在 `.ubaa_local/ios_live_activity/`，未提交。
- 从 `fca72f61` 建立最终 PR 分支 `feature/ios-live-activity` 和独立工作树 `.worktrees/ios-live-activity`，写入设计稿和实施计划。

## 完成边界

- 做了：代码现状审查、视觉方案确认、设计稿、四个任务的实施计划、最终分支和干净工作树准备。
- 没做及原因：产品代码、测试和文档中的界面说明尚未修改。原生基线测试没有跑通，原因是本机 Xcode 构建环境先后遇到 Homebrew 同版本 `rustc` 缺少 iOS simulator target、磁盘空间不足（`No space left on device`）；期间没有修改产品代码，也没有把失败或旧提交记录写成通过。
- 未做真机锁屏／灵动岛验收、远端 CI；未请求学校真实账号。设计与 HTML 预览不能代替系统或设备证据。

## 必要信息

- 变更清单：`docs/superpowers/specs/2026-11-27-ios-live-activity-design.md`、`docs/superpowers/plans/2026-11-27-ios-live-activity.md`、本日志。
- 分支：`feature/ios-live-activity`，起点 `fca72f610af403cda11fd24805faefd370e6791e`。
- 计划任务：1. 私密副行与身份键 TDD；2. 课名优先锁屏与完整时段；3. 灵动岛三形态；4. 文档和整体验收。
- 待办／阻塞：在可用磁盘上重新运行 `flutter-build` 与 `RunnerTests/ScheduleLiveCardTests`；Xcode 子进程需使用 Rustup 1.100.0 的 `rustc` 而非缺少 iOS target 的 Homebrew 同版本，并保留本地 DerivedData／SwiftPM 缓存。
- 关键决策：不新增学校协议、Bridge 字段、后台推送或持久化；旧 ContentState 必须保持可解码；未确认前不 push、不创建 PR。此次维护者明确授权提交并推送当前分支。
