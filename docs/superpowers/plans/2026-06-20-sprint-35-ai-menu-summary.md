# Sprint 35 AI Menu Summary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为普通截图与长截图中的 `AI` 按钮增加最小菜单入口，并新增 `摘要总结` 方向，同时继续复用 Sprint 34 的双输入链路与现有 AI 结果窗容器。

**Architecture:** 新建共享枚举 `AIAnalysisMode` 作为菜单项、分析方向和结果展示结构的统一入口。`CaptureOverlayView` 与 `ScrollingCapturePanelView` 各自负责弹出最小 `NSMenu`，`CaptureSessionService` 负责记住当前选择方向并编排普通截图 / 长截图流程，`AIAnalysisService` 与 `AIAnalysisPreviewWindowService` 轻度泛化为支持 `开发报错分析` 和 `摘要总结` 两种模式。

**Tech Stack:** Swift 6, AppKit, Foundation, ScreenCaptureKit, Vision, OpenAI Responses API

---

## File Structure

- Create: `TYScreenShotTool/Shared/AIAnalysisMode.swift`
  - 定义 Sprint 35 的两个分析方向
  - 统一菜单标题、loading 文案、结果结构标题
- Modify: `TYScreenShotTool/Features/CaptureOverlay/CaptureOverlayView.swift`
  - 点击 `AI` 按钮时弹出最小菜单
  - 将回调从“无参数 AI 请求”改为“带 `AIAnalysisMode` 的 AI 请求”
- Modify: `TYScreenShotTool/Services/CaptureOverlayService.swift`
  - 透传普通截图里的 `AIAnalysisMode`
- Modify: `TYScreenShotTool/Services/ScrollingCapturePanelService.swift`
  - 点击长截图 `AI` 按钮时弹出同样菜单
  - 透传长截图里的 `AIAnalysisMode`
- Modify: `TYScreenShotTool/App/TYScreenShotToolApp.swift`
  - 在 `CaptureSessionService` 新签名落地后，再调整 `AI` 回调签名并传入模式
- Modify: `TYScreenShotTool/Services/AIAnalysisService.swift`
  - 支持按 `AIAnalysisMode` 生成 prompt、解析结果
  - 新增摘要总结 3 段结构
- Modify: `TYScreenShotTool/Services/AIAnalysisPreviewWindowService.swift`
  - 结果窗支持按模式切换 section 标题与第二复制按钮标题
  - 继续复用现有单窗口布局和 loading / error 流程
- Modify: `TYScreenShotTool/Services/CaptureSessionService.swift`
  - 记录当前已选 `AIAnalysisMode`
  - 普通截图与长截图在 AI 流程中传递模式
  - 重试继续沿用当前模式，不重新弹菜单
- Modify: `TASK.md`
  - 实现完成后同步 Sprint 35 当前状态
- Modify: `docs/ROADMAP.md`
  - 实现完成后同步 Sprint 35 状态
- Modify: `docs/SPRINTS/Sprint-35.md`
  - 实现完成后补充结果与验证
- Modify: `docs/DEVLOG.md`
  - 实现完成后记录 Sprint 35 的实现和验证结果

说明：

- 当前项目没有独立 test target，本轮验证仍以 `./scripts/build.sh` 和人工验证为主。
- 本轮不新增新的 Settings 配置项，也不变更 Sprint 34 的取字开关逻辑。
- 本轮不实现第三个 AI 菜单项，不提前做注册式菜单系统。

---

### Task 1: 确认 Sprint 35 planned 文档已对齐

**Files:**
- Read: `TASK.md`
- Read: `docs/ROADMAP.md`
- Read: `docs/SPRINTS/Sprint-35.md`

- [ ] **Step 1: 确认 TASK.md 已切换到 Sprint 35 planned**

Read `TASK.md` and confirm it already contains:

```md
Current Sprint: Sprint 35 Planned

## 当前状态

Sprint 34 已完成实现、构建验证与人工验证。
Sprint 35 已完成设计对齐，准备进入 implementation plan 阶段。

## 当前目标

为 `AI` 按钮增加最小菜单入口，
并新增 `摘要总结` 这一项通用 AI 能力。
```

Expected: `TASK.md` 已表达 Sprint 35 planned，不需要再次修改。

- [ ] **Step 2: 确认 ROADMAP 已存在 Sprint 35 planned 段落**

Read `docs/ROADMAP.md` and confirm it already contains:

```md
### Sprint 35

AI 菜单与摘要总结

状态：
🚧 Planned

目标：

- 点击 `AI` 按钮后先弹出最小菜单
- 菜单先支持 `开发报错分析` 与 `摘要总结` 两项
- `摘要总结` 作为本轮唯一新增 AI 能力，输出固定 3 条重点
- 普通截图与长截图中的 `AI` 入口都使用同一套菜单交互
- 继续复用 Sprint 34 的本地 OCR / 视觉取字双输入链路
- 继续复用当前 `AI` 结果窗容器，不新增第二种 AI 结果窗
```

Expected: `ROADMAP` 已表达 Sprint 35 planned，不需要再次修改。

- [ ] **Step 3: 确认 Sprint-35.md 已创建且内容对齐 spec**

Read `docs/SPRINTS/Sprint-35.md` and confirm it already contains:

```md
# Sprint 35 - AI 菜单与摘要总结

## Status

Planned

## Goal

在现有截图编辑体验中，
让 `AI` 按钮先弹出一个最小菜单，
由用户选择本次分析方向。

Sprint 35 先支持两个方向：

- `开发报错分析`
- `摘要总结`
```

Expected: `Sprint-35.md` 已创建且与 spec 对齐，不需要再次修改。

- [ ] **Step 4: 不为 planned 文档重复创建提交**

Do not run a commit here.

Expected: 计划执行从代码实现开始，避免重复编辑和重复提交 planned 文档。

---

### Task 2: 增加共享分析方向模型并接入普通截图 AI 菜单

**Files:**
- Create: `TYScreenShotTool/Shared/AIAnalysisMode.swift`
- Modify: `TYScreenShotTool/Features/CaptureOverlay/CaptureOverlayView.swift`
- Modify: `TYScreenShotTool/Services/CaptureOverlayService.swift`
- Modify: `TYScreenShotTool/App/TYScreenShotToolApp.swift`

- [ ] **Step 1: 新建共享 `AIAnalysisMode` 枚举**

Create `TYScreenShotTool/Shared/AIAnalysisMode.swift`:

```swift
import Foundation

enum AIAnalysisMode: CaseIterable {
    case developerError
    case summary

    var menuTitle: String {
        switch self {
        case .developerError:
            return "开发报错分析"
        case .summary:
            return "摘要总结"
        }
    }

    var loadingMessage: String {
        switch self {
        case .developerError:
            return "AI 正在分析..."
        case .summary:
            return "AI 正在总结..."
        }
    }

    var resultStatusTitle: String {
        switch self {
        case .developerError:
            return "AI 分析结果"
        case .summary:
            return "摘要总结"
        }
    }

    var secondaryCopyButtonTitle: String {
        switch self {
        case .developerError:
            return "复制建议"
        case .summary:
            return "复制重点"
        }
    }

    var secondaryCopySuccessMessage: String {
        switch self {
        case .developerError:
            return "建议下一步已复制"
        case .summary:
            return "摘要重点已复制"
        }
    }
}
```

Expected: 菜单文案、loading 文案和结果窗文案有统一来源。

- [ ] **Step 2: 将普通截图 AI 回调改为携带模式**

Update `TYScreenShotTool/Features/CaptureOverlay/CaptureOverlayView.swift` property:

```swift
var onAIRequested: ((AIAnalysisMode, CapturePreviewStyle, [CaptureAnnotation]) -> Void)?
```

Update `TYScreenShotTool/Services/CaptureOverlayService.swift` property:

```swift
var onAIRequested: ((AIAnalysisMode, CapturePreviewStyle, [CaptureAnnotation]) -> Void)?
```

And keep passthrough wiring:

```swift
overlayView.onAIRequested = { [weak self] mode, style, annotations in
    self?.onAIRequested?(mode, style, annotations)
}
```

Expected: 普通截图 `AI` 入口可以把“用户选了哪一项”传到 overlay / service / app 接线层，为 Task 6 的 session 模式消费做好准备。

- [ ] **Step 3: 在普通截图 `AI` 按钮点击时弹出最小菜单**

Append to `CaptureOverlayView.swift`:

```swift
private func presentAIMenu(relativeTo button: NSButton) {
    let menu = NSMenu()

    for mode in AIAnalysisMode.allCases {
        let item = NSMenuItem(title: mode.menuTitle, action: #selector(handleAIMenuSelection(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = mode
        menu.addItem(item)
    }

    let menuOrigin = CGPoint(x: button.frame.minX, y: button.frame.maxY + 4)
    menu.popUp(positioning: nil, at: menuOrigin, in: toolbarContainerView)
}

@objc
private func handleAIMenuSelection(_ sender: NSMenuItem) {
    guard let mode = sender.representedObject as? AIAnalysisMode else {
        return
    }

    annotationCanvasView.commitActiveTextIfNeeded()
    onAIRequested?(mode, previewStyle, annotationCanvasView.annotations)
}
```

And replace `requestAI()` with:

```swift
@objc
private func requestAI() {
    annotationCanvasView.commitActiveTextIfNeeded()
    presentAIMenu(relativeTo: aiButton)
}
```

Expected: 普通截图点击 `AI` 时先弹菜单，而不是直接开始分析。

- [ ] **Step 4: 在 app 入口兼容新的普通截图 AI 回调签名**

Update `TYScreenShotTool/App/TYScreenShotToolApp.swift`:

```swift
overlayService.onAIRequested = { _, style, annotations in
    sessionService.analyzePendingCapture(style: style, annotations: annotations)
}
```

Expected: 普通截图菜单选择可以先安全接到 app 层并恢复全项目可编译；当前阶段允许先不在 session 层消费 `mode`，实际模式消费在 Task 6 完成。

- [ ] **Step 5: 运行构建，确认共享模型与普通截图菜单可独立编译**

Run: `./scripts/build.sh`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: 提交这一任务**

```bash
git add TYScreenShotTool/Shared/AIAnalysisMode.swift TYScreenShotTool/Features/CaptureOverlay/CaptureOverlayView.swift TYScreenShotTool/Services/CaptureOverlayService.swift TYScreenShotTool/App/TYScreenShotToolApp.swift
git commit -m "feat(sprint-35): 增加普通截图 AI 菜单入口"
```

Expected: 普通截图菜单骨架、共享模式定义和最小 app 接线兼容独立成一个小提交；模式值的业务消费放在 Task 6。

---

### Task 3: 接入长截图 AI 菜单骨架

**Files:**
- Modify: `TYScreenShotTool/Services/ScrollingCapturePanelService.swift`
- Modify: `TYScreenShotTool/App/TYScreenShotToolApp.swift`

- [ ] **Step 1: 将长截图 AI 回调改为携带模式**

Update `ScrollingCapturePanelService.swift`:

```swift
var onAIRequested: ((AIAnalysisMode) -> Void)? {
    didSet {
        panelView?.onAIRequested = makePanelActionHandler(for: onAIRequested)
    }
}
```

Update nested view property:

```swift
var onAIRequested: ((AIAnalysisMode) -> Void)? {
    didSet {
        aiButton.isEnabled = onAIRequested != nil
    }
}
```

Expected: 长截图 `AI` 入口也能传出用户所选模式。

- [ ] **Step 2: 在长截图 `AI` 按钮点击时弹出同样菜单**

Append to `ScrollingCapturePanelView`:

```swift
private func presentAIMenu(relativeTo button: NSButton) {
    let menu = NSMenu()

    for mode in AIAnalysisMode.allCases {
        let item = NSMenuItem(title: mode.menuTitle, action: #selector(handleAIMenuSelection(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = mode
        menu.addItem(item)
    }

    let menuOrigin = CGPoint(x: button.frame.minX, y: button.frame.maxY + 4)
    menu.popUp(positioning: nil, at: menuOrigin, in: self)
}

@objc
private func handleAIMenuSelection(_ sender: NSMenuItem) {
    guard let mode = sender.representedObject as? AIAnalysisMode else {
        return
    }

    onAIRequested?(mode)
}
```

And replace `aiAction()` with:

```swift
@objc
private func aiAction() {
    presentAIMenu(relativeTo: aiButton)
}
```

Expected: 长截图点击 `AI` 后也先弹相同菜单。

- [ ] **Step 3: 在 app 入口兼容新的长截图 AI 回调签名**

Update `TYScreenShotTool/App/TYScreenShotToolApp.swift`:

```swift
scrollingCapturePanelService.onAIRequested = { _ in
    sessionService.analyzeScrollingCaptureResult()
}
```

Expected: 长截图菜单选择可以先安全接到 app 层并恢复全项目可编译；当前阶段允许先不在 session 层消费 `mode`，实际模式消费在 Task 7 完成。

- [ ] **Step 4: 运行构建，确认长截图菜单骨架可独立编译**

Run: `./scripts/build.sh`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: 提交这一任务**

```bash
git add TYScreenShotTool/Services/ScrollingCapturePanelService.swift TYScreenShotTool/App/TYScreenShotToolApp.swift
git commit -m "feat(sprint-35): 接入长截图 AI 菜单"
```

Expected: 长截图菜单骨架和最小 app 接线兼容独立成一个小提交；模式值的业务消费放在 Task 7。

---

### Task 4: 将 AIAnalysisService 扩展为双分析方向

**Files:**
- Modify: `TYScreenShotTool/Services/AIAnalysisService.swift`

- [ ] **Step 1: 将结果结构泛化为通用 3 段结构**

Replace current result model with:

```swift
struct AIAnalysisSection {
    let title: String
    let content: String
}

struct AIAnalysisResult {
    let mode: AIAnalysisMode
    let statusTitle: String
    let sections: [AIAnalysisSection]
    let rawText: String
    let secondaryCopyText: String

    var formattedText: String {
        sections
            .flatMap { [$0.title + "：", $0.content, ""] }
            .dropLast()
            .joined(separator: "\n")
    }

    var summary: String {
        sections[safe: 0]?.content ?? ""
    }

    var possibleCauses: String {
        sections[safe: 1]?.content ?? ""
    }

    var nextSteps: String {
        sections[safe: 2]?.content ?? ""
    }
}
```

Expected: 结果模型不再被“报错三段结构”的字段名绑死。
Expected: 在 Task 5 / Task 6 / Task 7 还未全部切换到 `sections` 前，旧调用方仍可通过兼容只读属性持续编译。

- [ ] **Step 2: 增加按模式分析的统一公开入口**

Replace public API with:

```swift
func analyze(text: String, mode: AIAnalysisMode) async throws -> AIAnalysisResult {
    let normalized = normalizeOCRText(text)
    guard normalized.isEmpty == false else {
        throw AIAnalysisError.emptyInput
    }

    let apiKey = try resolvedAPIKey()
    let prompt = buildPrompt(for: mode, text: normalized)
    let request = try makeRequest(apiKey: apiKey, prompt: prompt)

    do {
        let (data, response) = try await session.data(for: request)
        try validateHTTPResponse(response, data: data)
        return try parseAnalysisResult(from: data, mode: mode)
    } catch let error as AIAnalysisError {
        throw error
    } catch let error as DecodingError {
        throw AIAnalysisError.requestFailed("响应解析失败：\(error.localizedDescription)")
    } catch {
        throw AIAnalysisError.requestFailed(error.localizedDescription)
    }
}
```

Expected: `AIAnalysisService` 可以从同一个入口支持 `开发报错分析` 和 `摘要总结`。

Keep a compatibility wrapper during this task:

```swift
func analyzeDeveloperError(text: String) async throws -> AIAnalysisResult {
    try await analyze(text: text, mode: .developerError)
}
```

Expected: `CaptureSessionService` 在 Task 6 / Task 7 切换到新接口前，当前工程仍可持续编译。

- [ ] **Step 3: 为两个模式分别定义 prompt**

Append:

```swift
private func buildPrompt(for mode: AIAnalysisMode, text: String) -> String {
    switch mode {
    case .developerError:
        return buildDeveloperErrorPrompt(from: text)
    case .summary:
        return buildSummaryPrompt(from: text)
    }
}

private func buildSummaryPrompt(from text: String) -> String {
    """
    你是一个帮助用户总结截图文字重点的助手。
    请基于下面的文字内容，用简洁中文输出，并严格使用以下结构：

    重点 1：
    <这里填写内容>

    重点 2：
    <这里填写内容>

    重点 3：
    <这里填写内容>

    要求：
    - 三个部分都必须输出，不能缺省
    - 每条尽量短句
    - 如果信息不足，明确说明信息不足
    - 不要输出额外标题、前言、总结或 Markdown 代码块

    文字内容：
    \(text)
    """
}
```

Expected: 摘要总结有独立 prompt，且输出固定 3 条结构。

- [ ] **Step 4: 按模式解析不同 section 标题**

Replace section parsing helpers with:

```swift
private func expectedSectionTitles(for mode: AIAnalysisMode) -> [String] {
    switch mode {
    case .developerError:
        return ["报错大意", "可能原因", "建议下一步"]
    case .summary:
        return ["重点 1", "重点 2", "重点 3"]
    }
}

private func parseAnalysisResult(from data: Data, mode: AIAnalysisMode) throws -> AIAnalysisResult {
    let envelope = try JSONDecoder().decode(ResponseEnvelope.self, from: data)

    let text = envelope.output
        .filter { $0.type == "message" }
        .flatMap { $0.content ?? [] }
        .filter { $0.type == "output_text" }
        .compactMap(\.text)
        .joined(separator: "\n")
        .trimmingCharacters(in: .whitespacesAndNewlines)

    guard text.isEmpty == false else {
        throw AIAnalysisError.emptyOutput
    }

    return try parseStructuredSections(from: text, mode: mode)
}
```

And update `parseStructuredSections(from:mode:)` to use explicit title matching:

```swift
private func parseStructuredSections(from text: String, mode: AIAnalysisMode) throws -> AIAnalysisResult {
    let titles = expectedSectionTitles(for: mode)
    var currentTitle: String?
    var collectedSections: [String: [String]] = [:]

    for rawLine in text.components(separatedBy: .newlines) {
        if let header = parseSectionHeader(from: rawLine, expectedTitles: titles) {
            currentTitle = header.title
            if header.inlineContent.isEmpty == false {
                collectedSections[header.title, default: []].append(header.inlineContent)
            }
            continue
        }

        guard let currentTitle else {
            continue
        }

        collectedSections[currentTitle, default: []].append(rawLine)
    }

    func resolvedContent(for title: String) -> String? {
        let lines = collectedSections[title, default: []]
        let joined = lines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .drop(while: \.isEmpty)
            .reversed()
            .drop(while: \.isEmpty)
            .reversed()
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return joined.isEmpty ? nil : joined
    }

    let sections = try titles.map { title -> AIAnalysisSection in
        guard let content = resolvedContent(for: title) else {
            throw AIAnalysisError.lowQualityOutput
        }

        return AIAnalysisSection(title: title, content: content)
    }

    return AIAnalysisResult(
        mode: mode,
        statusTitle: mode.resultStatusTitle,
        sections: sections,
        rawText: text,
        secondaryCopyText: mode == .summary
            ? sections
                .map { "\($0.title)：\n\($0.content)" }
                .joined(separator: "\n\n")
            : (sections.last?.content ?? text)
    )
}

private func parseSectionHeader(
    from line: String,
    expectedTitles: [String]
) -> (title: String, inlineContent: String)? {
    let sanitizedLine = line
        .replacingOccurrences(of: "**", with: "")
        .replacingOccurrences(
            of: #"^\s*[\-\*\•]?\s*\d*\s*[\.、]?\s*"#,
            with: "",
            options: .regularExpression
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)

    for title in expectedTitles {
        guard sanitizedLine.hasPrefix(title) else {
            continue
        }

        let remainder = sanitizedLine.dropFirst(title.count)
        let normalizedRemainder = remainder.trimmingCharacters(in: .whitespacesAndNewlines)

        if normalizedRemainder.isEmpty {
            return (title, "")
        }

        if normalizedRemainder.hasPrefix("：") || normalizedRemainder.hasPrefix(":") {
            let inlineContent = normalizedRemainder
                .dropFirst()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (title, inlineContent)
        }
    }

    return nil
}
```

Expected: `AIAnalysisService` 能根据模式解析 `报错大意 / 可能原因 / 建议下一步` 或 `重点 1 / 重点 2 / 重点 3`，且 `摘要总结` 的“复制重点”会复制全部 3 条重点。

- [ ] **Step 5: 运行构建，确认双方向分析服务可独立编译**

Run: `./scripts/build.sh`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: 提交这一任务**

```bash
git add TYScreenShotTool/Services/AIAnalysisService.swift TYScreenShotTool/Shared/AIAnalysisMode.swift
git commit -m "feat(sprint-35): 扩展 AI 双分析方向"
```

Expected: 模式定义与 AI 文本分析服务扩展独立成一个小提交。

---

### Task 5: 将 AI 结果窗泛化为双结构展示

**Files:**
- Modify: `TYScreenShotTool/Services/AIAnalysisPreviewWindowService.swift`

- [ ] **Step 1: 让 section 标题可以动态切换**

Update `SectionView` to add:

```swift
func setTitle(_ title: String) {
    titleLabel.stringValue = title
    needsLayout = true
}
```

Expected: 同一组 `SectionView` 能复用到报错分析和摘要总结两种结构。

- [ ] **Step 2: 按通用 sections 渲染结果**

Replace current `configureForResult(_:)` with:

```swift
private func configureForResult(_ result: AIAnalysisResult) {
    let sectionViews = [summarySectionView, causesSectionView, nextStepsSectionView]

    for (index, sectionView) in sectionViews.enumerated() {
        if index < result.sections.count {
            let section = result.sections[index]
            sectionView.setTitle(section.title)
            sectionView.setContent(section.content)
            sectionView.isHidden = false
        } else {
            sectionView.isHidden = true
            sectionView.frame = .zero
        }
    }

    messageLabel.isHidden = true
}
```

Expected: 结果窗可以展示两种不同的 3 段结构，而不需要新窗口。

- [ ] **Step 3: 第二复制按钮标题按模式切换**

Update `presentResult(...)`:

```swift
func presentResult(
    result: AIAnalysisResult,
    selectionRect: CGRect,
    preferredSide: PreviewPlacementSide? = nil,
    onCopyAll: @escaping () -> Void,
    onCopySecondary: @escaping () -> Void,
    onRetry: @escaping () -> Void,
    onClose: @escaping () -> Void
) {
    statusLabel.stringValue = result.statusTitle
    copyNextStepsButton.title = result.mode.secondaryCopyButtonTitle
    configureForResult(result)
    copyAllButton.isEnabled = true
    copyNextStepsButton.isEnabled = true
    retryButton.isEnabled = true
    self.onCopyAll = onCopyAll
    self.onCopyNextSteps = onCopySecondary
    self.onRetry = onRetry
    self.onClose = onClose
    presentPanel(selectionRect: selectionRect, preferredSide: preferredSide)
}
```

Expected: 报错分析时仍显示 `复制建议`，摘要总结时显示 `复制重点`。

- [ ] **Step 4: 运行构建，确认结果窗双结构展示可独立编译**

Run: `./scripts/build.sh`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: 提交这一任务**

```bash
git add TYScreenShotTool/Services/AIAnalysisPreviewWindowService.swift
git commit -m "feat(sprint-35): 泛化 AI 结果窗结构"
```

Expected: 结果窗泛化独立成一个小提交。

---

### Task 6: 改造普通截图 AI 流程，支持菜单模式与重试保持方向

**Files:**
- Modify: `TYScreenShotTool/Services/CaptureSessionService.swift`
- Modify: `TYScreenShotTool/App/TYScreenShotToolApp.swift`

- [ ] **Step 1: 在 session 中记录当前已选 AI 模式**

Append near properties:

```swift
private var pendingAIAnalysisMode: AIAnalysisMode?
```

And update `clearPendingCapture()` to include:

```swift
pendingAIAnalysisMode = nil
```

And replace entry signature:

```swift
func analyzePendingCapture(
    mode: AIAnalysisMode,
    style _: CapturePreviewStyle,
    annotations _: [CaptureAnnotation]
) {
    guard state == .selectionCompleted, let pendingCaptureSource else {
        return
    }

    guard isAIAnalysisInProgress == false else {
        toastService.showToast(message: "AI 正在分析中")
        return
    }

    pendingAIAnalysisMode = mode
    let selectionRect = pendingCaptureSource.selectionRect
    isAIAnalysisInProgress = true
    overlayService.setAIButtonEnabled(false)
    ocrPreviewWindowService.dismiss()
    aiAnalysisPreviewWindowService.presentLoading(
        selectionRect: selectionRect,
        message: mode.loadingMessage,
        onClose: { [weak self] in
            self?.aiAnalysisPreviewWindowService.dismiss()
        }
    )

    Task { [weak self] in
        guard let self else {
            return
        }

        await self.performAIAnalysis(for: pendingCaptureSource, mode: mode)
    }
}
```

Expected: 普通截图会在菜单项被选中后进入对应 AI 流程，并记住当前模式。

- [ ] **Step 2: 普通截图分析函数改为显式接收模式**

Replace signature and body start:

```swift
@MainActor
private func performAIAnalysis(
    for source: PendingCaptureSource,
    mode: AIAnalysisMode
) async {
    let selectionRect = source.selectionRect
    let strategy = currentAITextInputStrategy()

    print("[AI Analysis] mode: \(mode.menuTitle)")
    print("[AI Analysis] strategy: \(strategy.logName)")

    defer {
        isAIAnalysisInProgress = false
        overlayService.setAIButtonEnabled(true)
    }

    do {
        let image = try await captureImageForPendingSource(source)
        let text = try await resolveAIText(from: image, strategy: strategy)
        let result = try await aiAnalysisService.analyze(text: text, mode: mode)
```

Expected: 普通截图 AI 主流程可以按所选方向切换 prompt 和结果结构。

- [ ] **Step 3: 普通截图结果窗与复制逻辑使用通用结果**

Update result branch:

```swift
aiAnalysisPreviewWindowService.presentResult(
    result: result,
    selectionRect: selectionRect,
    onCopyAll: { [weak self] in
        self?.copyAIAnalysisResult(result.formattedText)
    },
    onCopySecondary: { [weak self] in
        self?.copyAIAnalysisSecondaryText(
            result.secondaryCopyText,
            successMessage: result.mode.secondaryCopySuccessMessage
        )
    },
    onRetry: { [weak self] in
        self?.retryAIAnalysis()
    },
    onClose: { [weak self] in
        self?.aiAnalysisPreviewWindowService.dismiss()
    }
)
```

And replace helper:

```swift
@MainActor
private func copyAIAnalysisSecondaryText(
    _ text: String,
    successMessage: String
) {
    do {
        try clipboardService.copyText(text)
        toastService.showToast(message: successMessage)
    } catch {
        print("AI secondary clipboard copy failed: \(error.localizedDescription)")
        toastService.showToast(message: "AI 结果复制失败")
    }
}
```

Expected: 报错分析仍能复制“建议下一步”，摘要总结则复制全部 3 条重点。

- [ ] **Step 4: 普通截图无文字时统一只 toast 并关闭结果窗**

Update the `performAIAnalysis(for:mode:)` error handling:

```swift
        } catch let error as OCRError {
            switch error {
            case .noTextRecognized, .emptyText:
                print("[AI Analysis] Local OCR produced no useful text: \(error.localizedDescription)")
                toastService.showToast(message: "AI 未识别到有效文字")
                aiAnalysisPreviewWindowService.dismiss()
            case .requestFailed:
                toastService.showToast(message: "OCR 识别失败")
                aiAnalysisPreviewWindowService.presentError(
                    title: "OCR 识别失败",
                    message: error.localizedDescription,
                    selectionRect: selectionRect,
                    onRetry: { [weak self] in
                        self?.retryAIAnalysis()
                    },
                    onClose: { [weak self] in
                        self?.aiAnalysisPreviewWindowService.dismiss()
                    }
                )
            }
```

Keep `AIImageTextExtractionError.noUsefulText` branch aligned with the same UX.

Expected: 本地 OCR 的“无文字”场景只 toast `AI 未识别到有效文字` 并关闭结果窗；真正的 OCR 请求失败仍保留错误窗与重试入口。视觉取字链路继续保持同样的“无文字”和“请求失败”区分。

- [ ] **Step 5: 在 app 入口透传普通截图与长截图的新模式参数**

Update `TYScreenShotTool/App/TYScreenShotToolApp.swift`:

```swift
overlayService.onAIRequested = { mode, style, annotations in
    sessionService.analyzePendingCapture(
        mode: mode,
        style: style,
        annotations: annotations
    )
}
```

Expected: 先只接入普通截图的新模式参数，避免在长截图 session 新签名落地前提前引入编译错误。

- [ ] **Step 6: 普通截图重试保持当前模式**

Replace retry logic with:

```swift
@MainActor
private func retryAIAnalysis() {
    guard let pendingCaptureSource,
          let pendingAIAnalysisMode else {
        return
    }

    let pendingSelectionRect = pendingCaptureSource.selectionRect
    guard isAIAnalysisInProgress == false else {
        return
    }

    isAIAnalysisInProgress = true
    overlayService.setAIButtonEnabled(false)
    aiAnalysisPreviewWindowService.presentLoading(
        selectionRect: pendingSelectionRect,
        message: pendingAIAnalysisMode.loadingMessage,
        onClose: { [weak self] in
            self?.aiAnalysisPreviewWindowService.dismiss()
        }
    )

    Task { [weak self] in
        guard let self else {
            return
        }

        await self.performAIAnalysis(for: pendingCaptureSource, mode: pendingAIAnalysisMode)
    }
}
```

Expected: 点击重试时不再重新弹菜单，且继续沿用当前分析方向。

- [ ] **Step 7: 运行构建，确认普通截图菜单分析链路可独立编译**

Run: `./scripts/build.sh`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 8: 人工验证普通截图菜单两项**

Manual:

1. 普通截图后点击 `AI`
2. 确认先弹出两项菜单
3. 选择 `开发报错分析`，确认行为与当前版本一致
4. 再次普通截图，选择 `摘要总结`
5. 确认得到 3 条重点摘要
6. 点击 `重试`，确认不重新弹菜单
7. 截取无文字区域，确认只提示 `AI 未识别到有效文字`
8. 点击 `复制重点`，确认复制内容包含 `重点 1 / 重点 2 / 重点 3`
9. 模拟 OCR 请求失败，确认展示 `OCR 识别失败` 错误窗并可重试

Expected:

- 普通截图 `AI` 菜单出现
- 两项模式都可用
- 重试保持当前模式
- 无文字场景不保留结果窗
- `复制重点` 会复制全部 3 条重点
- OCR 请求失败时仍保留错误窗与重试入口

- [ ] **Step 9: 提交这一任务**

```bash
git add TYScreenShotTool/Services/CaptureSessionService.swift TYScreenShotTool/App/TYScreenShotToolApp.swift
git commit -m "feat(sprint-35): 支持普通截图 AI 菜单分析"
```

Expected: 普通截图菜单分析链路独立成一个小提交。

---

### Task 7: 改造长截图 AI 流程，支持菜单模式与过期保护

**Files:**
- Modify: `TYScreenShotTool/Services/CaptureSessionService.swift`

- [ ] **Step 1: 长截图入口改为显式接收模式**

Replace signature:

```swift
func analyzeScrollingCaptureResult(mode: AIAnalysisMode) {
    guard isInScrollingCaptureMode,
          let image = scrollingCaptureResultImage,
          let selectionRect = pendingCaptureSource?.selectionRect else {
        return
    }

    pendingAIAnalysisMode = mode
    let resultRevision = scrollingCaptureResultRevision
    invalidateScrollingOCRRequest()
    ocrPreviewWindowService.dismiss()
    let requestID = UUID()
    scrollingAIRequestID = requestID
    let preferredSide = preferredResultSideForScrollingPreview()

    aiAnalysisPreviewWindowService.presentLoading(
        selectionRect: selectionRect,
        preferredSide: preferredSide,
        message: mode.loadingMessage,
        onClose: { [weak self] in
            self?.scrollingAIRequestID = UUID()
            self?.aiAnalysisPreviewWindowService.dismiss()
        }
    )

    Task { [weak self] in
        await self?.performScrollingAIAnalysis(
            image: image,
            selectionRect: selectionRect,
            preferredSide: preferredSide,
            resultRevision: resultRevision,
            requestID: requestID,
            mode: mode
        )
    }
}
```

Expected: 长截图只会在菜单项被明确选中后开始分析。

- [ ] **Step 2: 在 app 入口补上长截图的新模式参数透传**

Update `TYScreenShotTool/App/TYScreenShotToolApp.swift`:

```swift
scrollingCapturePanelService.onAIRequested = { mode in
    sessionService.analyzeScrollingCaptureResult(mode: mode)
}
```

Expected: 长截图菜单选择会在 session 新签名落地后，再接入 app 编排层。

- [ ] **Step 3: 长截图分析函数改为显式接收模式**

Replace signature and service call:

```swift
private func performScrollingAIAnalysis(
    image: CGImage,
    selectionRect: CGRect,
    preferredSide: PreviewPlacementSide?,
    resultRevision: Int,
    requestID: UUID,
    mode: AIAnalysisMode
) async {
    let strategy = currentAITextInputStrategy()

    print("[AI Analysis] mode: \(mode.menuTitle)")
    print("[AI Analysis] strategy: \(strategy.logName)")

    do {
        let text = try await resolveAIText(from: image, strategy: strategy)
        let result = try await aiAnalysisService.analyze(text: text, mode: mode)
```

Expected: 长截图 AI 主流程也能按菜单模式切换文本分析方向。

- [ ] **Step 4: 长截图结果窗与复制逻辑切换到通用结果**

Update result branch:

```swift
aiAnalysisPreviewWindowService.presentResult(
    result: result,
    selectionRect: selectionRect,
    preferredSide: preferredSide,
    onCopyAll: { [weak self] in
        self?.copyAIAnalysisResult(result.formattedText)
    },
    onCopySecondary: { [weak self] in
        self?.copyAIAnalysisSecondaryText(
            result.secondaryCopyText,
            successMessage: result.mode.secondaryCopySuccessMessage
        )
    },
    onRetry: { [weak self] in
        self?.retryScrollingAIAnalysis()
    },
    onClose: { [weak self] in
        self?.aiAnalysisPreviewWindowService.dismiss()
    }
)
```

Expected: 长截图结果窗也能展示 `摘要总结` 结构，不需要第二种窗口。

- [ ] **Step 5: 长截图无文字时统一只 toast 并关闭结果窗**

Keep both branches aligned in `performScrollingAIAnalysis(...)`:

```swift
        } catch let error as OCRError {
            await MainActor.run {
                guard shouldAcceptScrollingAIResult(
                    requestID: requestID,
                    resultRevision: resultRevision
                ) else {
                    return
                }

                switch error {
                case .noTextRecognized, .emptyText:
                    print("[AI Analysis] Scrolling local OCR produced no useful text: \(error.localizedDescription)")
                    toastService.showToast(message: "AI 未识别到有效文字")
                    aiAnalysisPreviewWindowService.dismiss()
                case .requestFailed:
                    toastService.showToast(message: "OCR 识别失败")
                    aiAnalysisPreviewWindowService.presentError(
                        title: "OCR 识别失败",
                        message: error.localizedDescription,
                        selectionRect: selectionRect,
                        preferredSide: preferredSide,
                        onRetry: { [weak self] in
                            self?.retryScrollingAIAnalysis()
                        },
                        onClose: { [weak self] in
                            self?.aiAnalysisPreviewWindowService.dismiss()
                        }
                    )
                }
            }
```

Keep `AIImageTextExtractionError.noUsefulText` branch aligned with the same UX.

Expected: 长截图本地 OCR 的“无文字”场景只 toast 并关闭结果窗；真正的 OCR 请求失败仍保留错误窗与重试入口。视觉取字链路继续保持同样的“无文字”和“请求失败”区分。

- [ ] **Step 6: 长截图重试保持当前模式**

Replace retry helper:

```swift
@MainActor
private func retryScrollingAIAnalysis() {
    guard isInScrollingCaptureMode,
          let pendingAIAnalysisMode else {
        return
    }

    analyzeScrollingCaptureResult(mode: pendingAIAnalysisMode)
}
```

Expected: 长截图点 `重试` 时继续沿用原模式，不重新弹菜单。

- [ ] **Step 7: 保持长截图现有过期结果保护**

Do not change:

```swift
guard shouldAcceptScrollingAIResult(
    requestID: requestID,
    resultRevision: resultRevision
) else {
    return
}
```

Expected: 长截图继续滚动后，旧 AI 结果仍然不会晚到覆盖新状态。

- [ ] **Step 8: 运行构建，确认长截图菜单分析链路可独立编译**

Run: `./scripts/build.sh`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 9: 人工验证长截图菜单两项与过期保护**

Manual:

1. 进入长截图模式后点击 `AI`
2. 确认先弹出两项菜单
3. 选择 `开发报错分析`，确认行为与当前版本一致
4. 再次点击 `AI`，选择 `摘要总结`
5. 确认得到 3 条重点摘要
6. 点击 `重试`，确认不重新弹菜单
7. 继续滚动后再次点击 `AI`，确认旧结果不会覆盖新状态
8. 点击 `复制重点`，确认复制内容包含 `重点 1 / 重点 2 / 重点 3`
9. 截取无文字场景，确认只提示 `AI 未识别到有效文字`
10. 模拟 OCR 请求失败，确认展示 `OCR 识别失败` 错误窗并可重试

Expected:

- 长截图 `AI` 菜单出现
- 两项模式都可用
- 重试保持当前模式
- 旧请求仍不会晚到覆盖新状态
- `复制重点` 会复制全部 3 条重点
- 无文字场景不保留结果窗
- OCR 请求失败时仍保留错误窗与重试入口

- [ ] **Step 10: 提交这一任务**

```bash
git add TYScreenShotTool/Services/CaptureSessionService.swift TYScreenShotTool/App/TYScreenShotToolApp.swift
git commit -m "feat(sprint-35): 支持长截图 AI 菜单分析"
```

Expected: 长截图菜单分析链路独立成一个小提交。

---

### Task 8: 收尾验证与文档同步

**Files:**
- Modify: `TASK.md`
- Modify: `docs/ROADMAP.md`
- Modify: `docs/SPRINTS/Sprint-35.md`
- Modify: `docs/DEVLOG.md`

- [ ] **Step 1: 运行最终构建验证**

Run: `./scripts/build.sh`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 2: 完整人工验证 Sprint 35**

Manual:

1. 普通截图点击 `AI`，确认先弹菜单
2. 普通截图选择 `开发报错分析`，确认行为与 Sprint 34 一致
3. 普通截图选择 `摘要总结`，确认输出 3 条重点
4. 长截图点击 `AI`，确认也先弹同样菜单
5. 长截图选择 `开发报错分析`，确认行为与 Sprint 34 一致
6. 长截图选择 `摘要总结`，确认输出 3 条重点
7. `AI 使用视觉取字` 开关关闭时，普通截图与长截图都继续走本地 OCR
8. `AI 使用视觉取字` 开关打开时，普通截图与长截图都继续走视觉取字
9. 无有效文字时，只提示 `AI 未识别到有效文字`
10. 点击 `重试` 时保持原方向，不重新弹菜单
11. `摘要总结` 点击 `复制重点` 时，复制内容包含 `重点 1 / 重点 2 / 重点 3`
12. 普通截图本地 OCR 请求失败时，展示 `OCR 识别失败` 错误窗并可重试

Expected:

- 菜单交互、摘要总结、旧报错分析、双输入链路与重试语义全部正常
- 普通截图与长截图都正确区分“无文字”与“OCR 请求失败”两类反馈

- [ ] **Step 3: 更新 TASK.md 为 Sprint 35 done**

Update `TASK.md` to reflect:

```md
Current Sprint: Sprint 35 Done

## 当前状态

Sprint 35 已完成实现、构建验证与人工验证。
相关文档已完成同步收尾。
```

Expected: `TASK.md` 切换为 Sprint 35 done。

- [ ] **Step 4: 更新 ROADMAP 中 Sprint 35 状态与成果**

Update `docs/ROADMAP.md`:

```md
### Sprint 35

AI 菜单与摘要总结

状态：
✅ Done

成果：

- 点击 `AI` 按钮后先弹出最小菜单
- 菜单支持 `开发报错分析` 与 `摘要总结` 两项
- `摘要总结` 作为本轮唯一新增 AI 能力，输出固定 3 条重点
- 普通截图与长截图中的 `AI` 都使用同一套菜单交互
- 继续复用 Sprint 34 的本地 OCR / 视觉取字双输入链路
- 继续复用当前 `AI` 结果窗容器，不新增第二种 AI 结果窗
- 重试时保持原分析方向，不重新弹菜单
```

Expected: `ROADMAP` 切换为 Sprint 35 done。

- [ ] **Step 5: 更新 Sprint-35.md 的 Result / Validation**

Update `docs/SPRINTS/Sprint-35.md`:

```md
## Status

Done

## Result

已完成。

- 点击 `AI` 按钮后会先弹出最小菜单
- 普通截图与长截图中的 `AI` 都支持 `开发报错分析` 与 `摘要总结`
- `摘要总结` 输出固定 3 条重点
- 当前 `AI` 结果窗已支持按分析方向切换不同 section 标题
- Sprint 34 的本地 OCR / 视觉取字双输入链路保持不变
- 重试保持原分析方向，不重新弹菜单
```

Expected: Sprint 文档切换为 done 并记录实际结果。

- [ ] **Step 6: 在 DEVLOG 记录 Sprint 35 实现与验证**

Append to `docs/DEVLOG.md`:

```md
## Sprint 35 完成

### 主题

AI 菜单与摘要总结

### 实现

- 为普通截图与长截图中的 `AI` 按钮增加最小菜单入口
- 菜单先支持 `开发报错分析` 与 `摘要总结`
- `摘要总结` 作为 Sprint 35 唯一新增 AI 能力接入
- 当前 `AI` 结果窗容器已支持按分析方向切换展示结构
- Sprint 34 的本地 OCR / 视觉取字双输入链路保持不变

### 验证

- `./scripts/build.sh` 构建通过
- 普通截图 `AI` 菜单与两项模式人工验证通过
- 长截图 `AI` 菜单与两项模式人工验证通过
- 本地 OCR / 视觉取字双输入链路人工验证通过
- 重试保持原方向人工验证通过

### 结果

`AI` 分析首次具备了最小多方向入口，既保留了开发报错分析，又新增了摘要总结能力，并为后续扩展更多 AI 方向打下了稳定交互基础。
```

Expected: `DEVLOG` 记录 Sprint 35 的关键结果，而不是琐碎修改清单。

- [ ] **Step 7: 提交这一任务**

```bash
git add TASK.md docs/ROADMAP.md docs/SPRINTS/Sprint-35.md docs/DEVLOG.md
git commit -m "docs(sprint-35): 同步 AI 菜单与摘要总结完成状态"
```

Expected: Sprint 35 收尾文档独立成一个小提交。
