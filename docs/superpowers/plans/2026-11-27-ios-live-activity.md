# iOS 锁屏实时活动与灵动岛 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 `fca72f61` 上完成课名优先的锁屏实时活动、独立灵动岛三形态，并修复私密副行与活动去重遗漏。

**Architecture:** 继续使用既有 v2 `upNext` 快照与 `ScheduleLiveFace`，不增加跨层合同。`ScheduleLiveCard.swift` 负责展示状态与完整身份键，`ScheduleLiveActivity.swift` 分开承载锁屏和灵动岛视图；`ScheduleLiveActivitySync` 通过更新后的 `desktopKey` 自动识别隐私／深链变化。

**Tech Stack:** SwiftUI、ActivityKit、WidgetKit、XCTest；Xcode 27.2；现有 Flutter 3.50.0 工具链；不新增依赖。

**Spec:** `docs/superpowers/specs/2026-11-27-ios-live-activity-design.md`

## Global Constraints

- 最终 PR 分支固定为 `feature/ios-live-activity`，工作树固定为 `.worktrees/ios-live-activity`，阶段基线为 `fca72f610af403cda11fd24805faefd370e6791e`。
- 主目录与两个对比工作树不承载产品改动；每个任务按明确 pathspec 提交，最终 `feature/ios-live-activity` 工作树必须干净。
- 未经维护者另行确认，不 `git push`、不创建 PR、不合并其他分支。
- 不修改 Dart 输入、Core、FRB、学校协议、现有分段窗口或提示音；不请求学校，不读取真实账号，不触碰发布签名。
- 私密主项与下一项使用系统 `privacySensitive`；compact/minimal 不显示课名。
- 新 ContentState 字段为可选 `secondaryPrivate: Bool?`，旧活动缺少该字段仍能解码。
- Swift 缩进遵循 `.editorconfig` 的 2 空格；截图和日志仅放主仓库 `.ubaa_local/ios_live_activity/`，不提交。
- 提交使用明确 pathspec 和中文说明；每次提交前运行 `just check-sensitive`，最终检查不能由旧提交记录替代。

## Review Focus

- 旧 ContentState 没有 `secondaryPrivate`：必须解码为 `nil`，不能因新增字段崩掉；Task 1 的 legacy 反例覆盖。
- 私人下一项含事项名：投影、身份键、锁屏和展开岛都要保留／使用隐私状态；Task 1 测投影与键，Task 2/3 用私密预览检查遮盖。
- 只改变 `isPrivate` 或 `link`：身份键必须变化，避免同步器提前返回；Task 1 用单独反例覆盖。
- 无地点、无倒计时或倒计时已过期：compact 不得选择私人课名，也不得构造无效时间区间；Task 3 用边界 contentStates 和渲染检查覆盖。
- 长课名、长地点、无下一项：主内容不能挤压状态区，也不能留下空白 footer；Task 2/3 用长文与空副行预览检查。

---

### Task 1: 私密副行与活动身份键

**Files:**
- Modify: `apps/ubaa_flutter/ios/Shared/ScheduleLiveCard.swift`
- Test: `apps/ubaa_flutter/ios/RunnerTests/ScheduleLiveCardTests.swift`

**Interfaces:**
- Consumes: `WidgetUpNextSegment.Secondary.private: Bool`、`ScheduleLiveFace.link`、`ScheduleLiveFace.isPrivate`。
- Produces: `ScheduleLiveFace.secondaryPrivate: Bool? = nil`；`desktopKey` 包含 `link`、`isPrivate` 和归一化后的副行隐私状态，供现有 `ScheduleLiveActivitySync.signature` 使用。

- [ ] **Step 1: 准备依赖并确认当前基线**

在主工作树只读取非机密工具配置，再在候选工作树执行：

```bash
eval "$(python3 "<repo-root>/scripts/lib/toolchain.py" shell)"
just flutter-dependencies
just flutter-build platform=ios-simulator mode=debug
xcodebuild test \
  -workspace apps/ubaa_flutter/ios/Runner.xcworkspace \
  -scheme Runner \
  -destination 'platform=iOS Simulator,id=2DC9A063-CA34-40E6-8327-F0CF847DD53D' \
  -derivedDataPath "$PWD/target/test_tmp/ios_live_activity/DerivedData" \
  -only-testing:RunnerTests/ScheduleLiveCardTests
```

Expected: 当前 12 项测试通过。若失败，记录失败并先区分基线问题与本次改动，不继续叠加实现。

- [ ] **Step 2: 写主项隐私与深链身份反例**

新增 `testFaceIdentityIncludesPrimaryPrivacyAndLink()`：从 `liveSnapshot` 生成一个 `face`，复制后分别设置 `isPrivate = true` 和 `link = "ubaa://widget/open?target=agenda"`，断言：

```swift
XCTAssertNotEqual(face.desktopKey, privateFace.desktopKey)
XCTAssertNotEqual(face.desktopKey, linkedFace.desktopKey)
```

- [ ] **Step 3: 运行反例并确认 RED**

Run: 同一 `xcodebuild test`，将 `-only-testing:` 改为 `-only-testing:RunnerTests/ScheduleLiveCardTests/testFaceIdentityIncludesPrimaryPrivacyAndLink`。
Expected: 两个 `XCTAssertNotEqual` 都失败，因为当前 `desktopKey` 不含这两个字段；若是编译或环境错误，先修测试入口，不算 RED 证据。

- [ ] **Step 4: 最小更新身份键**

在 `desktopKey` 的现有组成中追加 `link ?? ""`、`isPrivate ? "1" : "0"`，不改其他映射。重跑 Step 3，Expected: PASS。

- [ ] **Step 5: 写私密下一项与旧状态反例**

新增 `testPrivateSecondarySurvivesProjectionAndChangesIdentity()`：构造 `secondary = ["kind": "next", "text": "下一节 10:10 合成私事 研讨室 305", "private": true]`，断言投影后：

```swift
XCTAssertEqual(face.secondaryPrivate, true)
var changed = face
changed.secondaryPrivate = false
XCTAssertNotEqual(face.desktopKey, changed.desktopKey)
```

并在现有 `testLegacyFaceWithoutReferenceFieldsDecodes()` 中增加：

```swift
XCTAssertNil(face.secondaryPrivate)
```

- [ ] **Step 6: 运行反例并确认 RED**

Run: `-only-testing:RunnerTests/ScheduleLiveCardTests/testPrivateSecondarySurvivesProjectionAndChangesIdentity`。
Expected: 因 `ScheduleLiveFace` 尚无 `secondaryPrivate` 而编译失败，这是缺少目标状态的 RED；修好后还必须实际运行通过。

- [ ] **Step 7: 实现可选副行隐私状态**

在 `ScheduleLiveFace` 的 `secondaryExam` 后添加 `var secondaryPrivate: Bool? = nil`，使现有预览构造也可省略该参数；在 `makeFace` 中设置 `secondaryPrivate: segment.secondary?.private`；在 `desktopKey` 追加 `secondaryPrivate == true ? "1" : "0"`。不要改 Dart 或输入模型。

- [ ] **Step 8: 运行完整聚焦回归**

Run: `-only-testing:RunnerTests/ScheduleLiveCardTests`。
Expected: 14 项全部通过，包括旧 ContentState 解码与既有计划／时钟测试。

- [ ] **Step 9: 提交本任务**

```bash
git add apps/ubaa_flutter/ios/Shared/ScheduleLiveCard.swift apps/ubaa_flutter/ios/RunnerTests/ScheduleLiveCardTests.swift
just check-sensitive
git commit -m "修复实时活动私密副行与身份键遗漏"
```

### Task 2: 课名优先的锁屏实时活动

**Files:**
- Modify: `apps/ubaa_flutter/ios/Shared/ScheduleLiveCard.swift`
- Modify: `apps/ubaa_flutter/ios/ScheduleWidget/ScheduleLiveActivity.swift`
- Test: `apps/ubaa_flutter/ios/RunnerTests/ScheduleLiveCardTests.swift`

**Interfaces:**
- Consumes: Task 1 的 `secondaryPrivate` 与完整 `desktopKey`。
- Produces: 未上课 `face.scheduleText` 由既有开始／结束字段组成完整时段；锁屏 footer 使用 `privacySensitive(face.secondaryPrivate == true)`。

- [ ] **Step 1: 写未上课完整时段反例**

新增 `testUpcomingFaceCombinesExistingStartAndEndText()`，使用 `item(time: "明天 8:00", end: "9:35", ongoing: false)`：

```swift
XCTAssertEqual(face.scheduleText, "明天 08:00–09:35")
XCTAssertEqual(face.timeText, "明天 08:00")
```

另以已经含 `8:00–9:35` 的输入核对不会追加第二个结束时刻。

- [ ] **Step 2: 运行反例并确认 RED**

Run: `-only-testing:RunnerTests/ScheduleLiveCardTests/testUpcomingFaceCombinesExistingStartAndEndText`。
Expected: 当前 `scheduleText` 只有 `"明天 08:00"`，断言失败。

- [ ] **Step 3: 用既有字段补齐展示时段**

在 `makeFace` 中先用补零后的 `primary.timeText` 计算原有时刻 `time`；仅对非 ongoing、非空开始文案、存在非空 `endText` 且开始文案尚未包含该结束时刻的情况，把补零后的 `endText` 以 `–` 接到单独的 `displaySchedule`，只赋给 `face.scheduleText`。ongoing 与已有完整时段保持原样，`face.timeText` 不变成完整时段。

- [ ] **Step 4: 调整锁屏视图与私密预览**

在 `ScheduleLiveActivity.swift`：

- 锁屏主行在 ongoing 时使用 `timeText`（如「至 09:35」），未上课时使用 `scheduleText ?? timeText`（完整时段）；ongoing 副行保留 `本节至 sectionClock`，未上课不再显示第二份倒计时。
- 色条内先显示 15pt semibold、Ink 的课名，再显示 13pt medium、Secondary 的地点；右侧保留状态、`还有／还剩` 和唯一 `RemainingText`。
- footer 添加 `.privacySensitive(face.secondaryPrivate == true)`。
- DEBUG 数据增加长课名、无地点、无下一项、私密主项与私密下一项状态；主时刻使用真实映射可产生的值。

- [ ] **Step 5: 运行回归并检查锁屏预览**

Run: 完整 `ScheduleLiveCardTests` 与一次 `just flutter-build platform=ios-simulator mode=debug`。
Expected: 15 项通过、App／扩展编译成功；Xcode 锁屏 content 预览中课名优先、仅右侧一处倒计时、私密副行由系统遮盖。无法取得实际预览时明确记为未验证，不能用 HTML mockup 替代。

- [ ] **Step 6: 提交本任务**

```bash
git add apps/ubaa_flutter/ios/Shared/ScheduleLiveCard.swift apps/ubaa_flutter/ios/ScheduleWidget/ScheduleLiveActivity.swift apps/ubaa_flutter/ios/RunnerTests/ScheduleLiveCardTests.swift
just check-sensitive
git commit -m "调整锁屏实时活动为课名优先并补齐时段"
```

### Task 3: 灵动岛展开、紧凑与最小形态

**Files:**
- Modify: `apps/ubaa_flutter/ios/ScheduleWidget/ScheduleLiveActivity.swift`

**Interfaces:**
- Consumes: `ScheduleLiveFace`、`scheduleText`、`secondaryPrivate`、既有 `classStart / sectionEnd / countdownEnd`。
- Produces: 独立 expanded 视图；compactLeading/minimal 共用状态符号；compactTrailing 只使用系统计时、短时刻或状态，不选择 `title`。

- [ ] **Step 1: 拆分 expanded 的区域视图**

用 `DynamicIslandExpandedRegion(.leading)` 显示课名／地点，`.trailing` 显示状态与系统计时，`.bottom` 显示 `scheduleText ?? timeText`、可选 `本节至` 和下一项。计时目标沿用锁屏优先级 `classStart` → ongoing 时的 `sectionEnd` → `countdownEnd`，只有目标晚于当前时刻才构造区间。课名与下一项分别使用 `face.isPrivate`、`face.secondaryPrivate == true` 的 `privacySensitive`。长文单行缩放／截断，trailing 保持可读。

- [ ] **Step 2: 实现 compact 与 minimal**

- leading/minimal：ongoing 为 `timer`，否则为 `calendar`，颜色沿用 Accent。
- trailing：有效目标使用 `Text(timerInterval: Date.now...target, countsDown: true)`；目标已过期或缺失时依次使用 `classClock`、`sectionClock`、`periodClock`，再退回短状态文案。
- compactTrailing 不引用 `title`，从代码路径移除旧隐私条件错误；三种形态保留现有 `widgetURL`。

- [ ] **Step 3: 增加灵动岛边界预览**

添加 expanded 的 ongoing/upcoming、compact、minimal 预览，并复用长文、无地点、无倒计时、已过期倒计时和私密状态。所有日期使用相对于 `.now` 的合成值，避免预览加载时状态意外变化。

- [ ] **Step 4: 编译并做视觉检查**

Run: 完整 `ScheduleLiveCardTests`、`WidgetV2Tests` 与 `just flutter-build platform=ios-simulator mode=debug`。
Expected: 15 项 LiveCard 测试及 WidgetV2Tests 通过、编译成功。逐一检查 expanded/compact/minimal；实际截图放 `.ubaa_local/ios_live_activity/`。若只能确认编译，报告“灵动岛视觉与系统遮盖未验证”。

- [ ] **Step 5: 提交本任务**

```bash
git add apps/ubaa_flutter/ios/ScheduleWidget/ScheduleLiveActivity.swift
just check-sensitive
git commit -m "按系统区域完善灵动岛课程实时活动"
```

### Task 4: 文档、完工日志与整体验收

**Files:**
- Modify: `docs/protocol/parity/academic.md`
- Create: `docs/worklog/2026-11-27-ios-live-activity.md`
- Commit documents: `docs/superpowers/specs/2026-11-27-ios-live-activity-design.md`、`docs/superpowers/plans/2026-11-27-ios-live-activity.md`

**Interfaces:**
- Consumes: Task 1–3 的实际实现与验证输出。
- Produces: 与当前 UI 一致的协议边界说明及可追溯完工日志。

- [ ] **Step 1: 更新当前行为说明**

在 `academic.md` 的通知中心实时活动行写明：课名优先锁屏、完整时段、唯一中文倒计时、灵动岛分区、主项／下一项隐私遮盖；把换段描述收窄为“每次同步最多保留当前与下一次”，不得暗示第三段会持续自动接续。只写实际实现，不登记未取得的设备证据。

- [ ] **Step 2: 审阅并执行按改动检查**

```bash
eval "$(python3 "<repo-root>/scripts/lib/toolchain.py" shell)"
just check-plan base=fca72f610af403cda11fd24805faefd370e6791e
just check-changed base=fca72f610af403cda11fd24805faefd370e6791e
```

Expected: 所有被选择检查通过。若选择 L1+ 或 full，不降级；失败按具体原因修复并重跑。另运行 `git diff --check` 和最终 `just check-sensitive`。

- [ ] **Step 3: 写完工日志**

按全局模板记录变更清单、聚焦测试、构建、预览／截图、按改动检查及关键决策。分开列明代码检查、模拟器、真机、远端 CI、学校账号边界；未做真机与远端 CI 就明确写未做，不写“功能已验收”。

- [ ] **Step 4: 复核并提交文档**

检查 diff 不包含 `.ubaa_local`、`.superpowers`、构建产物、主工作树的 `UBAA/` 或 `examples/`。然后：

```bash
git diff --check
git add docs/protocol/parity/academic.md docs/superpowers/specs/2026-11-27-ios-live-activity-design.md docs/superpowers/plans/2026-11-27-ios-live-activity.md docs/worklog/2026-11-27-ios-live-activity.md
just check-sensitive
git diff --cached --check
git commit -m "记录 iOS 实时活动设计与验证边界"
git status --short --branch
```

Expected: 最终提交包含设计与计划；`git status --short` 无文件条目。另核对两个对比工作树仍无未提交文件。
