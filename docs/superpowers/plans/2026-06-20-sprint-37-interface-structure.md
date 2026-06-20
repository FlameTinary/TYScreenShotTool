# Sprint 37 Interface Structure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在当前 `AI` 菜单中新增一级项 `界面结构识别`，让普通截图与长截图都能输出一段可供设计与开发继续复用的结构化界面描述。

**Architecture:** 继续沿用 Sprint 35/36 的 `AIAnalysisMode` 作为菜单项、分析方向与结果窗文案的统一入口，但新增一个一级模式 `interfaceStructure`。`CaptureOverlayView` 与 `ScrollingCapturePanelView` 负责把该方向接入现有一级菜单；`CaptureSessionService` 继续统一编排普通截图 / 长截图分析流程；`AIAnalysisService` 与 `AIAnalysisPreviewWindowService` 轻度泛化为支持单段结构化结果、`复制结构` 文案，以及“无有效内容”错误语义。

**Tech Stack:** Swift 6, AppKit, Foundation, ScreenCaptureKit, Vision, OpenAI Responses API

---

## File Structure

- Modify: `TASK.md`
  - 将当前执行范围切换为 Sprint 37 planned
- Modify: `docs/ROADMAP.md`
  - 增加 Sprint 37 planned 段落
- Create: `docs/SPRINTS/Sprint-37.md`
  - 补齐 Sprint 37 的 planned 文档
- Modify: `TYScreenShotTool/Shared/AIAnalysisMode.swift`
  - 新增 `interfaceStructure` 模式与对应文案映射
- Modify: `TYScreenShotTool/Features/CaptureOverlay/CaptureOverlayView.swift`
  - 为普通截图 `AI` 菜单增加一级项 `界面结构识别`
- Modify: `TYScreenShotTool/Services/ScrollingCapturePanelService.swift`
  - 为长截图 `AI` 菜单增加一级项 `界面结构识别`
- Modify: `TYScreenShotTool/Services/AIAnalysisService.swift`
  - 支持界面结构识别 prompt、单段结构化结果解析与 `复制结构` 数据源
- Modify: `TYScreenShotTool/Services/AIAnalysisPreviewWindowService.swift`
  - 继续复用当前结果窗，但支持单段结构化文本与新按钮文案
- Modify: `TYScreenShotTool/Services/CaptureSessionService.swift`
  - 普通截图与长截图 AI 流程继续传递新 mode
  - 将 `无有效文字` 文案按界面结构识别方向调整为 `AI 未识别到有效内容`
- Modify: `docs/SPRINTS/Sprint-37.md`
  - 实现完成后补充结果与验证
- Modify: `docs/DEVLOG.md`
  - 实现完成后记录 Sprint 37 的实现与验证结果
- Modify: `docs/ROADMAP.md`
  - 实现完成后将 Sprint 37 切为 done
- Modify: `TASK.md`
  - 实现完成后同步 Sprint 37 当前状态

说明：

- 当前项目没有独立 test target，本轮验证仍以 `./scripts/build.sh` 与人工验证为主。
- 本轮不新增新的 Settings 配置项。
- 本轮不新增新的结果窗口类型。
- 本轮不生成 `HTML/CSS`、`SwiftUI/AppKit` 代码，也不输出 Figma 组件映射。

---

### Task 1: 对齐 Sprint 37 planned 文档

**Files:**
- Modify: `docs/ROADMAP.md`
- Create: `docs/SPRINTS/Sprint-37.md`
- Modify: `TASK.md`

- [ ] **Step 1: 在 ROADMAP 中增加 Sprint 37 planned 段落**

Update `docs/ROADMAP.md` after Sprint 36:

```md
### Sprint 37

界面结构识别

状态：
🚧 Planned

目标：

- 在当前 `AI` 菜单中新增一级项 `界面结构识别`
- 普通截图与长截图都支持相同入口
- 继续复用 Sprint 34 的双输入链路
- 继续复用当前 `AI` 结果窗容器
- 输出单段结构化文本，覆盖设计信息与实现提示
- 本轮支持 `复制全部` 与 `复制结构`
```

- [ ] **Step 2: 新建 Sprint-37 planned 文档**

Create `docs/SPRINTS/Sprint-37.md` with sections:

```md
# Sprint 37 - 界面结构识别

## Status

Planned

## Goal

在 Sprint 35 已完成 `AI` 菜单与 `摘要总结`、
Sprint 36 已完成 `翻译语言` 的基础上，
继续为当前 `AI` 菜单扩展新的实用方向：

- `界面结构识别`
```

Include aligned `Scope / Out of Scope / Implementation / Validation / Result` sections from the approved spec.

- [ ] **Step 3: 将 TASK.md 切换到 Sprint 37 planned**

Update `TASK.md` to:

```md
Current Sprint: Sprint 37 Planned

## 当前状态

Sprint 36 已完成实现、构建验证与人工验证。
Sprint 37 已完成设计对齐，准备进入 implementation plan 阶段。
```

And replace the current goal/range/acceptance text with Sprint 37 interface-structure scope.

- [ ] **Step 4: 检查文档对齐**

Run:

```bash
sed -n '1,220p' TASK.md
sed -n '600,735p' docs/ROADMAP.md
sed -n '1,260p' docs/SPRINTS/Sprint-37.md
```

Expected: `ROADMAP -> Sprint-37 -> TASK.md` 三者都表达同一件事，不再停留在 Sprint 36。

- [ ] **Step 5: 提交 planned 文档对齐**

Run:

```bash
git add TASK.md docs/ROADMAP.md docs/SPRINTS/Sprint-37.md
git commit -m "docs(sprint-37): 对齐界面结构识别范围"
```

Expected: Sprint 37 planned 文档单独成一个文档提交。

---

### Task 2: 扩展共享分析模式，支持界面结构识别方向

**Files:**
- Modify: `TYScreenShotTool/Shared/AIAnalysisMode.swift`

- [ ] **Step 1: 在 AIAnalysisMode 中新增界面结构识别模式**

Update `TYScreenShotTool/Shared/AIAnalysisMode.swift` to:

```swift
enum AIAnalysisMode {
    case developerError
    case summary
    case translation(AITranslationLanguage)
    case interfaceStructure

    static let topLevelModes: [AIAnalysisMode] = [
        .developerError,
        .summary,
        .interfaceStructure,
    ]
}
```

- [ ] **Step 2: 为新模式补全文案映射**

Update the existing computed properties with interface-structure behavior:

```swift
case .interfaceStructure:
    return "界面结构识别"
```

for:

```swift
var menuTitle: String
var resultStatusTitle: String
```

and:

```swift
case .interfaceStructure:
    return "AI 正在识别界面结构..."
```

for:

```swift
var loadingMessage: String
```

and:

```swift
case .interfaceStructure:
    return "复制结构"
```

for:

```swift
var secondaryCopyButtonTitle: String
```

and:

```swift
case .interfaceStructure:
    return "界面结构已复制"
```

for:

```swift
var secondaryCopySuccessMessage: String
```

- [ ] **Step 3: 构建验证并提交**

Run:

```bash
./scripts/build.sh
git add TYScreenShotTool/Shared/AIAnalysisMode.swift
git commit -m "feat(sprint-37): 增加界面结构识别模式"
```

Expected: 工程继续可编译，新的一级分析方向可被菜单与 service 共用。

---

### Task 3: 为普通截图与长截图 AI 菜单增加一级项界面结构识别

**Files:**
- Modify: `TYScreenShotTool/Features/CaptureOverlay/CaptureOverlayView.swift`
- Modify: `TYScreenShotTool/Services/ScrollingCapturePanelService.swift`

- [ ] **Step 1: 普通截图 AI 菜单增加一级项界面结构识别**

Update `CaptureOverlayView.presentAIMenu(relativeTo:)` by keeping:

```swift
for mode in AIAnalysisMode.topLevelModes {
    let item = NSMenuItem(title: mode.menuTitle, action: #selector(handleAIMenuSelection(_:)), keyEquivalent: "")
    item.target = self
    item.representedObject = mode
    menu.addItem(item)
}
```

and verify `AIAnalysisMode.topLevelModes` now produces:

```swift
.developerError
.summary
.interfaceStructure
```

before the `翻译语言` submenu block.

- [ ] **Step 2: 长截图 AI 菜单同步增加一级项界面结构识别**

Apply the same menu structure in `ScrollingCapturePanelView.presentAIMenu(relativeTo:)`:

```swift
for mode in AIAnalysisMode.topLevelModes {
    let item = NSMenuItem(title: mode.menuTitle, action: #selector(handleAIMenuSelection(_:)), keyEquivalent: "")
    item.target = self
    item.representedObject = mode
    menu.addItem(item)
}
```

- [ ] **Step 3: 保持现有选择回调不变**

Do not change these handlers beyond accepting the new mode value:

```swift
@objc
private func handleAIMenuSelection(_ sender: NSMenuItem) {
    guard let mode = sender.representedObject as? AIAnalysisMode else {
        return
    }

    onAIRequested?(mode)
}
```

and in `CaptureOverlayView`:

```swift
annotationCanvasView.commitActiveTextIfNeeded()
onAIRequested?(mode, previewStyle, annotationCanvasView.annotations)
```

- [ ] **Step 4: 构建验证并提交**

Run:

```bash
./scripts/build.sh
git add TYScreenShotTool/Features/CaptureOverlay/CaptureOverlayView.swift TYScreenShotTool/Services/ScrollingCapturePanelService.swift
git commit -m "feat(sprint-37): 增加界面结构识别菜单入口"
```

Expected: 普通截图与长截图菜单都已包含一级项 `界面结构识别`，且不影响已有项。

---

### Task 4: 扩展 AIAnalysisService，支持界面结构识别 prompt 与单段结构化结果

**Files:**
- Modify: `TYScreenShotTool/Services/AIAnalysisService.swift`

- [ ] **Step 1: 为界面结构识别增加 definition**

Append to `definition(for:)`:

```swift
case .interfaceStructure:
    return AnalysisModeDefinition(
        instructions: "你负责识别截图中的界面结构，并输出一段可供设计与开发继续复用的结构化说明。",
        promptIntro: "你是一个帮助设计师和开发者理解截图界面结构的助手。",
        inputLabel: "界面内容",
        requirements: [
            "必须按固定小标题输出",
            "保持简洁、具体、可复用",
            "优先描述组件类型、层级、视觉特征、交互语义与实现提示",
            "实现提示先给通用方向，再补一句前端或原生可参考的落地建议",
            "不要输出代码块、JSON、前言、结语或与截图无关的猜测",
        ],
        sections: [
            SectionDefinition(
                title: "界面结构",
                promptTitle: "界面结构",
                acceptedHeaders: [.exact("界面结构")]
            ),
        ]
    )
```

- [ ] **Step 2: 为界面结构识别增加独立 prompt 兜底**

Inside `buildPrompt(from:text:mode:)`, extend the output-language switch:

```swift
case .interfaceStructure:
    outputLanguageInstruction = "请基于下面的\\(definition.inputLabel)，严格按要求输出一段结构化界面说明："
```

This keeps the new mode away from the old “用简洁中文输出，并严格使用以下结构” wording intended for multi-section analysis.

- [ ] **Step 3: 增加界面结构识别的单段结果解析兜底**

Update `parseAnalysisResult(from:mode:)` from:

```swift
if case .translation = mode {
    return try parseTranslationResult(from: text, mode: mode)
}
```

to:

```swift
switch mode {
case .translation:
    return try parseTranslationResult(from: text, mode: mode)
case .interfaceStructure:
    return try parseInterfaceStructureResult(from: text, mode: mode)
default:
    return try parseStructuredSections(from: text, mode: mode)
}
```

- [ ] **Step 4: 实现 parseInterfaceStructureResult**

Append to `AIAnalysisService.swift`:

```swift
private func parseInterfaceStructureResult(from text: String, mode: AIAnalysisMode) throws -> AIAnalysisResult {
    if let structuredResult = try? parseStructuredSections(from: text, mode: mode) {
        return structuredResult
    }

    let normalized = normalizeInterfaceStructureText(text)
    guard normalized.isEmpty == false else {
        throw AIAnalysisError.lowQualityOutput
    }

    print("[AI Analysis] Interface structure output missing explicit section header, fallback to raw structured text")

    let sections = [
        AIAnalysisSection(title: "界面结构", content: normalized),
    ]

    return AIAnalysisResult(
        mode: mode,
        statusTitle: mode.resultStatusTitle,
        sections: sections,
        rawText: text,
        secondaryCopyText: normalized
    )
}
```

- [ ] **Step 5: 实现 normalizeInterfaceStructureText**

Append below `normalizeTranslationText(_:)`:

```swift
private func normalizeInterfaceStructureText(_ text: String) -> String {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.isEmpty == false else {
        return ""
    }

    let candidates = [
        "界面结构：",
        "界面结构:",
    ]

    for prefix in candidates {
        if trimmed.hasPrefix(prefix) {
            return trimmed
                .dropFirst(prefix.count)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    return trimmed
}
```

- [ ] **Step 6: 让 secondaryCopyText 支持复制结构**

Update:

```swift
private func secondaryCopyText(
    for mode: AIAnalysisMode,
    sections: [AIAnalysisSection],
    fallback: String
) -> String
```

with:

```swift
case .interfaceStructure:
    return sections.first?.content ?? fallback
```

- [ ] **Step 7: 保持 formattedText 兼容单段结构化结果**

Keep `AIAnalysisResult.formattedText` as-is if it already works with one section:

```swift
sections
    .flatMap { [$0.title + "：", $0.content, ""] }
    .dropLast()
    .joined(separator: "\n")
```

Expected: interface-structure mode will produce:

```text
界面结构：
<structured text>
```

- [ ] **Step 8: 构建验证并提交**

Run:

```bash
./scripts/build.sh
git add TYScreenShotTool/Services/AIAnalysisService.swift
git commit -m "feat(sprint-37): 支持界面结构识别结果"
```

Expected: AI service 已能为新方向生成 prompt 并解析单段结构化结果。

---

### Task 5: 泛化 AI 结果窗，支持复制结构与单段界面结构文本

**Files:**
- Modify: `TYScreenShotTool/Services/AIAnalysisPreviewWindowService.swift`

- [ ] **Step 1: 继续复用单段结果展示**

Keep the current `configureForResult(_:)` strategy:

```swift
let sectionViews = [summarySectionView, causesSectionView, nextStepsSectionView]
```

and rely on the first section to render:

```swift
AIAnalysisSection(title: "界面结构", content: normalized)
```

while unused section views keep:

```swift
sectionView.setTitle("")
sectionView.setContent("")
sectionView.isHidden = true
sectionView.frame = .zero
```

- [ ] **Step 2: 让界面结构识别按钮文案正确映射**

Keep existing result-window hookup:

```swift
copyNextStepsButton.title = result.mode.secondaryCopyButtonTitle
```

Expected: interface-structure mode automatically shows `复制结构`.

- [ ] **Step 3: 保持 loading / error / placement 机制不变**

Do not create new panel types. Reuse:

```swift
presentLoading(...)
presentResult(...)
presentError(...)
```

Expected: interface-structure mode shares the same placement, loading, retry, and close mechanics.

- [ ] **Step 4: 构建验证并提交**

Run:

```bash
./scripts/build.sh
git add TYScreenShotTool/Services/AIAnalysisPreviewWindowService.swift
git commit -m "feat(sprint-37): 复用结果窗展示界面结构"
```

Expected: 结果窗能稳定显示单段 `界面结构` 内容，并正确展示 `复制结构`。

---

### Task 6: 接入普通截图与长截图界面结构识别流程

**Files:**
- Modify: `TYScreenShotTool/Services/CaptureSessionService.swift`

- [ ] **Step 1: 普通截图入口继续记录当前 mode**

Keep:

```swift
pendingAIAnalysisMode = mode
```

inside `analyzePendingCapture(...)`.

Expected: interface-structure mode is recorded just like summary/translation/developerError.

- [ ] **Step 2: 普通截图 loading 文案自动随 mode 切换**

Keep:

```swift
message: mode.loadingMessage
```

Expected: interface-structure mode shows `AI 正在识别界面结构...`.

- [ ] **Step 3: 普通截图 AI 主流程直接消费新 mode**

Keep the existing generalized call:

```swift
let result = try await aiAnalysisService.analyze(text: text, mode: mode)
```

Expected: no extra branching in `performAIAnalysis`.

- [ ] **Step 4: 将无有效内容提示按新 mode 调整**

Inside the `.noTextRecognized, .emptyText` branch in `performAIAnalysis(...)`, replace:

```swift
toastService.showToast(message: "AI 未识别到有效文字")
```

with:

```swift
toastService.showToast(message: emptyContentMessage(for: mode))
```

Append helper:

```swift
private func emptyContentMessage(for mode: AIAnalysisMode) -> String {
    switch mode {
    case .interfaceStructure:
        return "AI 未识别到有效内容"
    default:
        return "AI 未识别到有效文字"
    }
}
```

- [ ] **Step 5: 长截图无有效内容提示同步按新 mode 调整**

In `performScrollingAIAnalysis(...)` and `handleVisionAIExtractionError(...)`, replace the hardcoded:

```swift
"AI 未识别到有效文字"
```

with:

```swift
emptyContentMessage(for: mode)
```

and for the shared vision handler, change signature to:

```swift
private func handleVisionAIExtractionError(
    _ error: AIImageTextExtractionError,
    selectionRect: CGRect,
    mode: AIAnalysisMode,
    onRetry: @escaping () -> Void
)
```

then pass `mode` from call sites.

- [ ] **Step 6: 普通截图与长截图复制结构只关闭结果窗**

Keep the current copy success behavior:

```swift
aiAnalysisPreviewWindowService.dismiss()
```

Expected: `复制结构` and `复制全部` still only close the AI result window.

- [ ] **Step 7: 长截图继续复用当前 preferredSide 与 request guard**

Do not change:

```swift
let preferredSide = preferredResultSideForScrollingPreview()
```

and:

```swift
shouldAcceptScrollingAIResult(
    requestID: requestID,
    resultRevision: resultRevision
)
```

Expected: interface-structure mode continues to follow current long-capture placement and stale-result protection.

- [ ] **Step 8: 构建验证并提交**

Run:

```bash
./scripts/build.sh
git add TYScreenShotTool/Services/CaptureSessionService.swift
git commit -m "feat(sprint-37): 接入界面结构识别流程"
```

Expected: 普通截图与长截图都可进入界面结构识别，且无有效内容提示与复制语义正确。

---

### Task 7: 最终验证并同步 Sprint 37 文档

**Files:**
- Modify: `docs/ROADMAP.md`
- Modify: `docs/SPRINTS/Sprint-37.md`
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

1. 普通截图点击 `AI`，看到一级菜单项 `界面结构识别`
2. 长截图点击 `AI`，看到一级菜单项 `界面结构识别`
3. 选择该项后结果窗继续复用当前 `AI` 结果窗
4. 结果窗内容只展示一段结构化文本
5. 文本中包含 `组件识别 / 结构层级 / 视觉特征 / 交互语义 / 实现提示`
6. `复制结构` 可复制完整结构化文本，且只关闭结果窗
7. `复制全部` 可复制完整结果，且只关闭结果窗
8. 关闭 `AI 使用视觉取字` 时该能力走本地 OCR
9. 打开 `AI 使用视觉取字` 时该能力走视觉取字
10. 无有效内容时只提示 `AI 未识别到有效内容`
11. 失败时提示 `AI 分析失败` 并支持重试
12. 重试保持 `界面结构识别` 方向，不重新弹菜单
13. 长截图结果窗摆放继续符合当前规则
14. 长截图继续滚动后旧分析请求不会覆盖新状态

- [ ] **Step 3: 将 Sprint-37.md 更新为 done**

Update:

```md
## Status

Done
```

and replace `Result` with implementation, bug-fix if any, and verification outcomes.

- [ ] **Step 4: 更新 ROADMAP 中 Sprint 37 状态**

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

and replace `目标` with `成果`.

- [ ] **Step 5: 更新 TASK.md 当前状态**

Update `TASK.md` from Sprint 37 planned to Sprint 37 done or the next active Sprint state according to the actual outcome.

- [ ] **Step 6: 更新 DEVLOG**

Append a new `## Sprint 37 完成` section summarizing:

- 主题：界面结构识别
- 实现：一级菜单项、单段结构化文本、复制结构、双输入链路复用
- 验证：build + human validation

- [ ] **Step 7: 提交收尾文档**

Run:

```bash
git add TASK.md docs/ROADMAP.md docs/SPRINTS/Sprint-37.md docs/DEVLOG.md
git commit -m "docs(sprint-37): 同步界面结构识别完成状态"
```

Expected: Sprint 37 完成状态与验证结果被文档正式记录。
