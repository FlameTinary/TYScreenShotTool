# Sprint 36 AI Translation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在当前 `AI` 菜单中增加 `翻译语言` 子菜单，并让普通截图与长截图都支持 `翻译成中文` 与 `翻译成英文` 两个最小翻译方向。

**Architecture:** 继续沿用 Sprint 35 的 `AIAnalysisMode` 作为菜单项、分析方向与结果窗文案的统一入口，但扩展出带目标语言的翻译模式。`CaptureOverlayView` 与 `ScrollingCapturePanelView` 负责在现有菜单中增加 `翻译语言` 子菜单；`CaptureSessionService` 继续负责保存当前 mode 并编排普通截图 / 长截图流程；`AIAnalysisService` 与 `AIAnalysisPreviewWindowService` 轻度泛化为支持翻译方向的单段译文展示与复制语义。

**Tech Stack:** Swift 6, AppKit, Foundation, ScreenCaptureKit, Vision, OpenAI Responses API

---

## File Structure

- Modify: `TASK.md`
  - 将当前执行范围切换为 Sprint 36 planned
- Modify: `docs/ROADMAP.md`
  - 增加 Sprint 36 planned 段落
- Create: `docs/SPRINTS/Sprint-36.md`
  - 补齐 Sprint 36 的 planned 文档
- Modify: `TYScreenShotTool/Shared/AIAnalysisMode.swift`
  - 将 mode 从双方向扩展为支持翻译语言子类型
- Create: `TYScreenShotTool/Shared/AITranslationLanguage.swift`
  - 定义翻译目标语言与关联文案
- Modify: `TYScreenShotTool/Features/CaptureOverlay/CaptureOverlayView.swift`
  - 为普通截图 `AI` 菜单增加 `翻译语言` 子菜单
- Modify: `TYScreenShotTool/Services/ScrollingCapturePanelService.swift`
  - 为长截图 `AI` 菜单增加 `翻译语言` 子菜单
- Modify: `TYScreenShotTool/Services/AIAnalysisService.swift`
  - 支持翻译 prompt、翻译结果解析与单段译文结构
- Modify: `TYScreenShotTool/Services/AIAnalysisPreviewWindowService.swift`
  - 结果窗继续复用，但支持单段翻译结构与 `复制译文` 文案
- Modify: `TYScreenShotTool/Services/CaptureSessionService.swift`
  - 普通截图与长截图在 AI 流程中传递翻译 mode
  - 保持重试沿用当前目标语言
  - 保持普通截图 / 长截图复制后仅关闭结果窗
- Modify: `docs/SPRINTS/Sprint-36.md`
  - 实现完成后补充结果与验证
- Modify: `docs/DEVLOG.md`
  - 实现完成后记录 Sprint 36 的实现与验证结果
- Modify: `docs/ROADMAP.md`
  - 实现完成后将 Sprint 36 切为 done
- Modify: `TASK.md`
  - 实现完成后同步 Sprint 36 当前状态

说明：

- 当前项目没有独立 test target，本轮验证仍以 `./scripts/build.sh` 与人工验证为主。
- 本轮不新增新的 Settings 配置项。
- 本轮不新增新的结果窗口类型。
- 本轮不实现 `翻译成日文`、`翻译成韩文`、原文译文双栏展示或翻译说明。

---

### Task 1: 对齐 Sprint 36 planned 文档

**Files:**
- Modify: `docs/ROADMAP.md`
- Create: `docs/SPRINTS/Sprint-36.md`
- Modify: `TASK.md`

- [ ] **Step 1: 在 ROADMAP 中增加 Sprint 36 planned 段落**

Update `docs/ROADMAP.md` after Sprint 35:

```md
### Sprint 36

AI 翻译语言

状态：
🚧 Planned

目标：

- 在当前 `AI` 菜单中新增 `翻译语言` 子菜单
- 子菜单先支持 `翻译成中文` 与 `翻译成英文`
- 普通截图与长截图中的翻译能力都继续复用 Sprint 34 的双输入链路
- 翻译结果继续复用当前 `AI` 结果窗容器，不新增第二种结果窗
- 本轮结果窗只展示译文，并支持 `复制译文`
```

- [ ] **Step 2: 新建 Sprint-36 planned 文档**

Create `docs/SPRINTS/Sprint-36.md` with sections:

```md
# Sprint 36 - AI 翻译语言

## Status

Planned

## Goal

在 Sprint 35 已完成 `AI` 菜单与 `摘要总结` 的基础上，
继续为当前 `AI` 菜单扩展新的实用方向：

- `翻译语言`
```

Include aligned `Scope / Out of Scope / Implementation / Validation / Result` sections from the approved spec.

- [ ] **Step 3: 将 TASK.md 切换到 Sprint 36 planned**

Update `TASK.md` to:

```md
Current Sprint: Sprint 36 Planned

## 当前状态

Sprint 35 已完成实现、构建验证与人工验证。
Sprint 36 已完成设计对齐，准备进入 implementation plan 阶段。
```

And replace the current goal/range/acceptance text with Sprint 36 translation scope.

- [ ] **Step 4: 检查文档对齐**

Run:

```bash
sed -n '1,220p' TASK.md
sed -n '560,680p' docs/ROADMAP.md
sed -n '1,260p' docs/SPRINTS/Sprint-36.md
```

Expected: `ROADMAP -> Sprint-36 -> TASK.md` 三者都表达同一件事，不再停留在 Sprint 35。

- [ ] **Step 5: 提交 planned 文档对齐**

Run:

```bash
git add TASK.md docs/ROADMAP.md docs/SPRINTS/Sprint-36.md
git commit -m "docs(sprint-36): 对齐 AI 翻译语言范围"
```

Expected: Sprint 36 planned 文档单独成一个文档提交。

---

### Task 2: 扩展共享分析模式，支持翻译目标语言

**Files:**
- Modify: `TYScreenShotTool/Shared/AIAnalysisMode.swift`
- Create: `TYScreenShotTool/Shared/AITranslationLanguage.swift`

- [ ] **Step 1: 新建翻译目标语言类型**

Create `TYScreenShotTool/Shared/AITranslationLanguage.swift`:

```swift
import Foundation

enum AITranslationLanguage: CaseIterable {
    case simplifiedChinese
    case english

    var menuTitle: String {
        switch self {
        case .simplifiedChinese:
            return "翻译成中文"
        case .english:
            return "翻译成英文"
        }
    }

    var resultStatusTitle: String {
        switch self {
        case .simplifiedChinese:
            return "翻译成中文"
        case .english:
            return "翻译成英文"
        }
    }

    var loadingMessage: String {
        switch self {
        case .simplifiedChinese:
            return "AI 正在翻译成中文..."
        case .english:
            return "AI 正在翻译成英文..."
        }
    }
}
```

- [ ] **Step 2: 扩展 AIAnalysisMode 为翻译模式**

Update `TYScreenShotTool/Shared/AIAnalysisMode.swift` to:

```swift
import Foundation

enum AIAnalysisMode {
    case developerError
    case summary
    case translation(AITranslationLanguage)

    static let topLevelModes: [AIAnalysisMode] = [
        .developerError,
        .summary
    ]
}
```

- [ ] **Step 3: 为翻译模式补全文案映射**

Update the existing computed properties:

```swift
var menuTitle: String {
    switch self {
    case .developerError:
        return "开发报错分析"
    case .summary:
        return "摘要总结"
    case let .translation(language):
        return language.menuTitle
    }
}
```

Also update:

```swift
var loadingMessage: String
var resultStatusTitle: String
var secondaryCopyButtonTitle: String
var secondaryCopySuccessMessage: String
```

with translation behavior:

```swift
case .translation:
    return "复制译文"
```

and:

```swift
case .translation:
    return "译文已复制"
```

- [ ] **Step 4: 构建验证并提交**

Run:

```bash
./scripts/build.sh
git add TYScreenShotTool/Shared/AIAnalysisMode.swift TYScreenShotTool/Shared/AITranslationLanguage.swift
git commit -m "feat(sprint-36): 增加 AI 翻译语言模式"
```

Expected: 工程继续可编译，mode 模型可被菜单与 service 共用。

---

### Task 3: 为普通截图与长截图 AI 菜单增加翻译子菜单

**Files:**
- Modify: `TYScreenShotTool/Features/CaptureOverlay/CaptureOverlayView.swift`
- Modify: `TYScreenShotTool/Services/ScrollingCapturePanelService.swift`

- [ ] **Step 1: 普通截图 AI 菜单改为顶层项 + 翻译子菜单**

Update `CaptureOverlayView.presentAIMenu(relativeTo:)` from:

```swift
for mode in AIAnalysisMode.allCases {
    let item = NSMenuItem(title: mode.menuTitle, action: #selector(handleAIMenuSelection(_:)), keyEquivalent: "")
    item.target = self
    item.representedObject = mode
    menu.addItem(item)
}
```

to:

```swift
for mode in AIAnalysisMode.topLevelModes {
    let item = NSMenuItem(title: mode.menuTitle, action: #selector(handleAIMenuSelection(_:)), keyEquivalent: "")
    item.target = self
    item.representedObject = mode
    menu.addItem(item)
}

let translationItem = NSMenuItem(title: "翻译语言", action: nil, keyEquivalent: "")
let translationMenu = NSMenu()

for language in AITranslationLanguage.allCases {
    let mode = AIAnalysisMode.translation(language)
    let item = NSMenuItem(title: mode.menuTitle, action: #selector(handleAIMenuSelection(_:)), keyEquivalent: "")
    item.target = self
    item.representedObject = mode
    translationMenu.addItem(item)
}

menu.setSubmenu(translationMenu, for: translationItem)
menu.addItem(translationItem)
```

- [ ] **Step 2: 长截图 AI 菜单同步增加翻译子菜单**

Apply the same menu structure in `ScrollingCapturePanelView.presentAIMenu(relativeTo:)`.

- [ ] **Step 3: 保持现有选择回调不变**

Do not change these handlers beyond accepting the new translation mode values:

```swift
@objc
private func handleAIMenuSelection(_ sender: NSMenuItem) {
    guard let mode = sender.representedObject as? AIAnalysisMode else {
        return
    }

    onAIRequested?(mode)
}
```

And in `CaptureOverlayView`:

```swift
annotationCanvasView.commitActiveTextIfNeeded()
onAIRequested?(mode, previewStyle, annotationCanvasView.annotations)
```

- [ ] **Step 4: 构建验证并提交**

Run:

```bash
./scripts/build.sh
git add TYScreenShotTool/Features/CaptureOverlay/CaptureOverlayView.swift TYScreenShotTool/Services/ScrollingCapturePanelService.swift
git commit -m "feat(sprint-36): 增加 AI 翻译子菜单"
```

Expected: 普通截图与长截图菜单都已包含 `翻译语言 >`，且不影响已有两项。

---

### Task 4: 扩展 AIAnalysisService，支持翻译 prompt 与译文结果

**Files:**
- Modify: `TYScreenShotTool/Services/AIAnalysisService.swift`

- [ ] **Step 1: 为翻译模式增加 definition**

Append to `definition(for:)`:

```swift
case let .translation(language):
    return AnalysisModeDefinition(
        instructions: "你负责将截图中的文字翻译成指定目标语言，并仅输出译文结果。",
        promptIntro: "你是一个帮助用户翻译截图文字内容的助手。",
        inputLabel: "待翻译文本",
        requirements: [
            "只输出译文，不要输出原文",
            "不要输出解释、说明、前言、结语或 Markdown 代码块",
            "保持语义准确与表达自然",
            "若原文中存在明显的菜单、按钮或短句，仍然按自然语言翻译",
        ],
        sections: [
            SectionDefinition(
                title: "译文",
                promptTitle: "译文",
                acceptedHeaders: [.exact("译文")]
            ),
        ]
    )
```

- [ ] **Step 2: 将目标语言要求写入 prompt**

Update `buildPrompt(from:text:)` signature to accept mode:

```swift
private func buildPrompt(
    from definition: AnalysisModeDefinition,
    text: String,
    mode: AIAnalysisMode
) -> String
```

Inside it, derive an output language instruction and prepend translation target only for translation mode:

```swift
let outputLanguageInstruction: String
switch mode {
case .developerError, .summary:
    outputLanguageInstruction = "请基于下面的\\(definition.inputLabel)，用简洁中文输出，并严格使用以下结构："
case .translation:
    outputLanguageInstruction = "请基于下面的\\(definition.inputLabel)，严格按要求输出译文："
}
```

Then keep translation target only for translation mode:

```swift
let targetLanguageInstruction: String
switch mode {
case let .translation(language):
    switch language {
    case .simplifiedChinese:
        targetLanguageInstruction = "目标语言：简体中文"
    case .english:
        targetLanguageInstruction = "目标语言：英文"
    }
default:
    targetLanguageInstruction = ""
}
```

And build the final prompt with:

```swift
\(outputLanguageInstruction)

\(targetLanguageInstruction.isEmpty ? "" : targetLanguageInstruction + "\n\n")
```

before the structure description block, so `翻译成英文` does not inherit the old fixed wording `用简洁中文输出`.

- [ ] **Step 3: 调整 analyze 调用链**

Update:

```swift
let prompt = buildPrompt(for: mode, text: normalized)
```

and:

```swift
private func buildPrompt(for mode: AIAnalysisMode, text: String) -> String {
    buildPrompt(from: definition(for: mode), text: text, mode: mode)
}
```

- [ ] **Step 4: 让 formattedText 兼容单段翻译结果**

Keep `AIAnalysisResult.formattedText` as-is if it already works with one section:

```swift
sections
    .flatMap { [$0.title + "：", $0.content, ""] }
    .dropLast()
    .joined(separator: "\n")
```

Expected: translation mode will produce:

```text
译文：
<translated text>
```

- [ ] **Step 5: 构建验证并提交**

Run:

```bash
./scripts/build.sh
git add TYScreenShotTool/Services/AIAnalysisService.swift
git commit -m "feat(sprint-36): 支持 AI 翻译分析结果"
```

Expected: AI service 已能为翻译方向生成 prompt 并解析单段译文结构。

---

### Task 5: 泛化 AI 结果窗，支持翻译方向单段展示与复制译文

**Files:**
- Modify: `TYScreenShotTool/Services/AIAnalysisPreviewWindowService.swift`

- [ ] **Step 1: 保持最多 3 段渲染，但允许只显示 1 段**

No new UI container is needed. Confirm `configureForResult(_:)` already supports 1 section:

```swift
let sectionViews = [summarySectionView, causesSectionView, nextStepsSectionView]
```

It should render the first section and hide the rest. For every unused section view, always reset it before hiding:

```swift
sectionView.setTitle("")
sectionView.setContent("")
sectionView.isHidden = true
sectionView.frame = .zero
```

Expected: when the previous result had 3 sections and the next result has only 1 `译文`, the old `可能原因` / `建议下一步` content never remains visible or copyable.

- [ ] **Step 2: 让翻译方向按钮文案正确映射**

Keep existing result window hookup:

```swift
copyNextStepsButton.title = result.mode.secondaryCopyButtonTitle
```

Expected: translation mode automatically shows `复制译文`.

- [ ] **Step 3: 保持 loading / error 状态与普通布局一致**

Do not create new panel types. Reuse:

```swift
presentLoading(...)
presentResult(...)
presentError(...)
```

Expected: translation mode shares the same placement, loading, retry, and close mechanics.

- [ ] **Step 4: 构建验证并提交**

Run:

```bash
./scripts/build.sh
git add TYScreenShotTool/Services/AIAnalysisPreviewWindowService.swift
git commit -m "feat(sprint-36): 泛化 AI 结果窗支持译文展示"
```

Expected: 结果窗能稳定显示单段 `译文`，不新增第二种窗口。

---

### Task 6: 接入普通截图翻译分析流程

**Files:**
- Modify: `TYScreenShotTool/Services/CaptureSessionService.swift`

- [ ] **Step 1: 普通截图入口继续记录当前 mode**

Keep:

```swift
pendingAIAnalysisMode = mode
```

inside `analyzePendingCapture(...)`.

Expected: translation mode is recorded just like summary/developerError.

- [ ] **Step 2: 普通截图 loading 文案自动随 mode 切换**

Keep:

```swift
aiAnalysisPreviewWindowService.presentLoading(
    selectionRect: selectionRect,
    message: mode.loadingMessage,
    onClose: { [weak self] in
        self?.aiAnalysisPreviewWindowService.dismiss()
    }
)
```

Expected: translation mode shows `AI 正在翻译成中文...` or `AI 正在翻译成英文...`.

- [ ] **Step 3: 普通截图 AI 主流程直接消费翻译 mode**

Keep the existing generalized call:

```swift
let result = try await aiAnalysisService.analyze(text: text, mode: mode)
```

Expected: no extra branching in `performAIAnalysis`.

- [ ] **Step 4: 普通截图复制译文只关闭结果窗**

Keep existing copy success behavior:

```swift
aiAnalysisPreviewWindowService.dismiss()
```

Do not dismiss overlay or clear the whole session on translation result copy.

- [ ] **Step 5: 普通截图重试继续沿用目标语言**

Keep:

```swift
await self.performAIAnalysis(for: pendingCaptureSource, mode: pendingAIAnalysisMode)
```

Expected: retry for translation does not reopen the menu.

- [ ] **Step 6: 构建验证并提交**

Run:

```bash
./scripts/build.sh
git add TYScreenShotTool/Services/CaptureSessionService.swift
git commit -m "feat(sprint-36): 支持普通截图 AI 翻译"
```

Expected: 普通截图已可进入中文/英文翻译方向，且复制与重试语义正确。

---

### Task 7: 接入长截图翻译分析流程并保留摆放与过期保护

**Files:**
- Modify: `TYScreenShotTool/Services/CaptureSessionService.swift`

- [ ] **Step 1: 长截图入口继续显式接收翻译 mode**

Keep:

```swift
func analyzeScrollingCaptureResult(mode: AIAnalysisMode)
```

with:

```swift
pendingAIAnalysisMode = mode
```

- [ ] **Step 2: 长截图 loading 文案继续随 mode 切换**

Keep:

```swift
message: mode.loadingMessage
```

in the long-capture loading window.

- [ ] **Step 3: 长截图 AI 主流程直接消费翻译 mode**

Keep:

```swift
let result = try await aiAnalysisService.analyze(text: text, mode: mode)
```

inside `performScrollingAIAnalysis(...)`.

- [ ] **Step 4: 长截图结果窗继续使用当前 preferredSide**

Do not change:

```swift
let preferredSide = preferredResultSideForScrollingPreview()
```

and:

```swift
preferredSide: preferredSide
```

Expected: translation mode continues to follow the current long-capture placement rule.

- [ ] **Step 5: 长截图重试继续沿用目标语言**

Keep:

```swift
analyzeScrollingCaptureResult(mode: pendingAIAnalysisMode)
```

inside `retryScrollingAIAnalysis()`.

- [ ] **Step 6: 保持 requestID + revision 守卫不变**

Do not weaken:

```swift
shouldAcceptScrollingAIResult(
    requestID: requestID,
    resultRevision: resultRevision
)
```

Expected: old translation results cannot override the new long-capture state after scrolling.

- [ ] **Step 7: 构建验证并提交**

Run:

```bash
./scripts/build.sh
git add TYScreenShotTool/Services/CaptureSessionService.swift
git commit -m "feat(sprint-36): 支持长截图 AI 翻译"
```

Expected: 长截图已可进入中文/英文翻译方向，且摆放与过期保护保持正确。

---

### Task 8: 最终验证并同步 Sprint 36 文档

**Files:**
- Modify: `docs/ROADMAP.md`
- Modify: `docs/SPRINTS/Sprint-36.md`
- Modify: `TASK.md`
- Modify: `docs/DEVLOG.md`

- [ ] **Step 1: 运行最终构建验证**

Run:

```bash
./scripts/build.sh
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 2: 执行人工验证**

Manual verification checklist:

1. 普通截图点击 `AI`，看到 `翻译语言 >`
2. 长截图点击 `AI`，看到 `翻译语言 >`
3. 子菜单显示 `翻译成中文` 与 `翻译成英文`
4. 选择任一语言后结果窗只显示 `译文`
5. `复制译文` 可复制内容，且只关闭结果窗
6. 关闭 `AI 使用视觉取字` 时翻译走本地 OCR
7. 打开 `AI 使用视觉取字` 时翻译走视觉取字
8. 无有效文字时只提示 `AI 未识别到有效文字`
9. 翻译失败时提示 `AI 分析失败` 并支持重试
10. 重试保持原目标语言
11. 长截图翻译结果窗摆放继续符合当前规则
12. 长截图继续滚动后旧翻译请求不会覆盖新状态

- [ ] **Step 3: 将 Sprint-36.md 更新为 done**

Update:

```md
## Status

Done
```

And replace `Result` with implementation, bug-fix if any, and verification outcomes.

- [ ] **Step 4: 更新 ROADMAP 中 Sprint 36 状态**

Change:

```md
状态：
🚧 Planned
```

to:

```md
状态：
✅ Done
```

And replace `目标` with `成果`.

- [ ] **Step 5: 更新 TASK.md 当前状态**

Update `TASK.md` from Sprint 36 planned to Sprint 36 done or the next active Sprint state according to the actual outcome.

- [ ] **Step 6: 更新 DEVLOG**

Append a new `## Sprint 36 完成` section summarizing:

- 主题：AI 翻译语言
- 实现：菜单子菜单、中文英文翻译、双输入链路复用、译文结果窗
- 验证：build + human validation

- [ ] **Step 7: 提交收尾文档**

Run:

```bash
git add TASK.md docs/ROADMAP.md docs/SPRINTS/Sprint-36.md docs/DEVLOG.md
git commit -m "docs(sprint-36): 同步 AI 翻译语言完成状态"
```

Expected: Sprint 36 完成状态与验证结果被文档正式记录。
