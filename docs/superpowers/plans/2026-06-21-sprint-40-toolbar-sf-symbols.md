# Sprint 40 Toolbar SF Symbols Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将截图编辑态工具栏从文字按钮升级为 SF Symbols 图标按钮，并为标注工具增加青色选中态与 `.drawOn.individually` 单次动画，同时保持截图、标注、OCR、AI、Pin、复制、保存、长截图等主链路行为不变。

**Architecture:** 延续 `CaptureOverlayView` 当前 AppKit 结构，不引入 SwiftUI 或第三方依赖。`AnnotationTool` 只新增 `symbolName` 负责图标映射；`CaptureOverlayView` 负责按钮创建、统一尺寸布局、Tooltip、本地化文本清理，以及标注工具选中态的颜色切换与动画触发。工具栏容器保持当前 `NSVisualEffectView(material: .popover)` 与圆角 12，不改截图业务逻辑。

**Tech Stack:** Swift 6, AppKit, NSButton, NSImage(systemSymbolName:), SF Symbols

---

## File Structure

- Modify: `TYScreenShotTool/Shared/AnnotationTool.swift`
  - 新增 `symbolName` 计算属性，为 6 个标注工具提供稳定的 SF Symbol 映射
- Modify: `TYScreenShotTool/Features/CaptureOverlay/CaptureOverlayView.swift`
  - 新增统一的 symbol configuration / tint color / fixed button size 常量
  - 重写 `configureToolbar()`，将 14 个按钮改为图标按钮并设置 Tooltip
  - 调整 `layoutPreviewInterface()`，将工具栏按钮布局改为统一固定尺寸
  - 扩展 `updateAnnotationToolSelection()`，为标注工具接入青色选中态与 `.drawOn.individually` 动画
  - 清理 `applyLocalizedStrings()` 中对工具栏标题的更新，改为 Tooltip 与无障碍描述更新
- Create: `docs/SPRINTS/Sprint-40.md`
  - 记录 Sprint 40 的 Goal / Scope / Validation / Result
- Modify: `docs/DEVLOG.md`
  - 记录 Sprint 40 完成结果
- Modify: `TASK.md`
  - 将当前执行范围切换到 Sprint 40
- Optional Modify: `docs/ROADMAP.md`
  - 仅当 Sprint 40 状态在本轮完成时再更新

说明：

- 当前项目没有独立 test target，本轮以 `./scripts/build.sh` 与人工验证为主。
- 本轮只改普通截图编辑态工具栏视觉表达，不改长截图面板、OCR 结果窗、AI 结果窗布局。
- commit message 需遵守 `docs/GIT_WORKFLOW.md`，使用中文。

---

### Task 1: 为 AnnotationTool 增加 SF Symbol 映射

**Files:**
- Modify: `TYScreenShotTool/Shared/AnnotationTool.swift`

- [ ] **Step 1: 新增 `symbolName` 计算属性**

在 `AnnotationTool` 中保留现有 `rawIdentifier` 和 `title`，新增如下属性：

```swift
var symbolName: String {
    switch self {
    case .rectangle:
        return "rectangle"
    case .ellipse:
        return "circle"
    case .arrow:
        return "arrow.up.right"
    case .pen:
        return "pencil.tip"
    case .mosaic:
        return "questionmark.square.dashed"
    case .text:
        return "textformat"
    }
}
```

- [ ] **Step 2: 运行构建验证**

Run:

```bash
./scripts/build.sh
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: 提交当前最小映射改动**

Run:

```bash
git add TYScreenShotTool/Shared/AnnotationTool.swift
git commit -m "feat(sprint-40): 新增标注工具图标映射"
```

Expected: 仅提交 `AnnotationTool.swift` 的本轮相关改动。

---

### Task 2: 将工具栏按钮改为 SF Symbols 图标按钮

**Files:**
- Modify: `TYScreenShotTool/Features/CaptureOverlay/CaptureOverlayView.swift`

- [ ] **Step 1: 在 `CaptureOverlayView` 中新增工具栏图标常量**

在按钮属性区域附近新增统一配置：

```swift
private let toolbarSymbolConfiguration = NSImage.SymbolConfiguration(pointSize: 20, weight: .regular)
private let toolbarSelectedTintColor = NSColor.systemCyan
private let toolbarButtonSize = CGSize(width: 32, height: 32)
```

说明：

- `toolbarButtonSize` 使用固定正方形，和 spec 中“统一固定尺寸按钮，优先保持方形”保持一致
- 如人工验证后视觉偏小，可在实现阶段微调为 `34 x 34`，但必须保持正方形

- [ ] **Step 2: 新增一个统一创建图标按钮的私有方法**

在 `CaptureOverlayView` 内新增：

```swift
private func makeToolbarButton(
    symbolName: String,
    accessibilityDescription: String,
    toolTip: String,
    action: Selector
) -> NSButton {
    let image = NSImage(
        systemSymbolName: symbolName,
        accessibilityDescription: accessibilityDescription
    )?.withSymbolConfiguration(toolbarSymbolConfiguration) ?? NSImage()

    let button = NSButton(image: image, target: self, action: action)
    button.imagePosition = .imageOnly
    button.imageScaling = .scaleProportionallyUpOrDown
    button.bezelStyle = .rounded
    button.contentTintColor = nil
    button.toolTip = toolTip
    button.setAccessibilityLabel(accessibilityDescription)
    return button
}
```

- [ ] **Step 3: 重写标注工具按钮创建逻辑**

将 `configureToolbar()` 中这段文字按钮代码：

```swift
let annotationButtons = AnnotationTool.allCases.map { tool -> NSButton in
    let button = NSButton(title: tool.title, target: self, action: #selector(selectAnnotationTool(_:)))
    button.identifier = NSUserInterfaceItemIdentifier(tool.rawIdentifier)
    annotationToolButtons[tool] = button
    return button
}
```

替换为：

```swift
let annotationButtons = AnnotationTool.allCases.map { tool -> NSButton in
    let button = makeToolbarButton(
        symbolName: tool.symbolName,
        accessibilityDescription: tool.title,
        toolTip: tool.title,
        action: #selector(selectAnnotationTool(_:))
    )
    button.identifier = NSUserInterfaceItemIdentifier(tool.rawIdentifier)
    annotationToolButtons[tool] = button
    return button
}
```

- [ ] **Step 4: 重写功能按钮配置逻辑**

保留现有按钮属性实例，但在 `configureToolbar()` 中将它们统一配置为图标按钮：

```swift
private func configureToolbarButton(
    _ button: NSButton,
    symbolName: String,
    accessibilityDescription: String,
    toolTip: String,
    action: Selector
) {
    let image = NSImage(
        systemSymbolName: symbolName,
        accessibilityDescription: accessibilityDescription
    )?.withSymbolConfiguration(toolbarSymbolConfiguration) ?? NSImage()

    button.title = ""
    button.image = image
    button.imagePosition = .imageOnly
    button.imageScaling = .scaleProportionallyUpOrDown
    button.bezelStyle = .rounded
    button.contentTintColor = nil
    button.toolTip = toolTip
    button.target = self
    button.action = action
    button.setAccessibilityLabel(accessibilityDescription)
}
```

然后在 `configureToolbar()` 中按如下方式调用：

```swift
configureToolbarButton(
    undoButton,
    symbolName: "arrow.uturn.backward",
    accessibilityDescription: AppText.captureUndo,
    toolTip: AppText.captureUndo,
    action: #selector(requestUndo)
)
configureToolbarButton(
    longCaptureButton,
    symbolName: "rectangle.arrowtriangle.4.outward",
    accessibilityDescription: AppText.captureLongCapture,
    toolTip: AppText.captureLongCapture,
    action: #selector(requestLongCapture)
)
configureToolbarButton(
    ocrButton,
    symbolName: "text.viewfinder",
    accessibilityDescription: "OCR",
    toolTip: "OCR",
    action: #selector(requestOCR)
)
configureToolbarButton(
    aiButton,
    symbolName: "sparkles",
    accessibilityDescription: "AI",
    toolTip: "AI",
    action: #selector(requestAI)
)
configureToolbarButton(
    pinButton,
    symbolName: "pin",
    accessibilityDescription: AppText.capturePin,
    toolTip: AppText.capturePin,
    action: #selector(requestPin)
)
configureToolbarButton(
    copyButton,
    symbolName: "doc.on.doc",
    accessibilityDescription: AppText.captureCopy,
    toolTip: AppText.captureCopy,
    action: #selector(requestCopy)
)
configureToolbarButton(
    saveButton,
    symbolName: "square.and.arrow.down",
    accessibilityDescription: AppText.captureSave,
    toolTip: AppText.captureSave,
    action: #selector(requestSave)
)
configureToolbarButton(
    cancelButton,
    symbolName: "xmark",
    accessibilityDescription: AppText.captureCancel,
    toolTip: AppText.captureCancel,
    action: #selector(requestCancel)
)
```

说明：

- `OCR` 与 `AI` 保持 acronym 作为按钮 tooltip 与 accessibility label，不额外引入新的本地化字段
- 这样可以保持当前产品语义与现有菜单、结果窗中的命名一致

- [ ] **Step 5: 保持容器材质与层级不变**

确认 `configureToolbar()` 中以下代码保留不变：

```swift
toolbarContainerView.material = .popover
toolbarContainerView.blendingMode = .withinWindow
toolbarContainerView.state = .active
toolbarContainerView.wantsLayer = true
toolbarContainerView.layer?.cornerRadius = 12
```

- [ ] **Step 6: 运行构建验证**

Run:

```bash
./scripts/build.sh
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 7: 提交图标按钮重构**

Run:

```bash
git add TYScreenShotTool/Features/CaptureOverlay/CaptureOverlayView.swift
git commit -m "feat(sprint-40): 工具栏切换为图标按钮"
```

Expected: 提交集中在 `CaptureOverlayView.swift` 中的按钮创建重构。

---

### Task 3: 调整工具栏布局为统一固定尺寸按钮

**Files:**
- Modify: `TYScreenShotTool/Features/CaptureOverlay/CaptureOverlayView.swift`

- [ ] **Step 1: 在 `layoutPreviewInterface()` 中移除对工具栏按钮的 `sizeToFit()` 依赖**

将当前这段：

```swift
let annotationButtons = AnnotationTool.allCases.compactMap { annotationToolButtons[$0] }
annotationButtons.forEach { $0.sizeToFit() }
undoButton.sizeToFit()
longCaptureButton.sizeToFit()
ocrButton.sizeToFit()
aiButton.sizeToFit()
pinButton.sizeToFit()
copyButton.sizeToFit()
saveButton.sizeToFit()
cancelButton.sizeToFit()
let toolbarButtons = annotationButtons + [undoButton, longCaptureButton, ocrButton, aiButton, pinButton, copyButton, saveButton, cancelButton]
```

改为：

```swift
let annotationButtons = AnnotationTool.allCases.compactMap { annotationToolButtons[$0] }
let toolbarButtons = annotationButtons + [
    undoButton,
    longCaptureButton,
    ocrButton,
    aiButton,
    pinButton,
    copyButton,
    saveButton,
    cancelButton
]

toolbarButtons.forEach { button in
    button.frame.size = toolbarButtonSize
}
```

- [ ] **Step 2: 使用固定宽度重新计算工具栏尺寸**

将：

```swift
let toolbarContentHeight = max(
    toolbarButtons.map(\.frame.height).max() ?? 0,
    0
)
let toolbarWidth = toolbarPaddingX * 2
    + toolbarButtons.reduce(CGFloat(0)) { $0 + $1.frame.width }
    + (toolbarSpacing * CGFloat(max(toolbarButtons.count - 1, 0)))
```

改为：

```swift
let toolbarContentHeight = toolbarButtonSize.height
let toolbarWidth = toolbarPaddingX * 2
    + CGFloat(toolbarButtons.count) * toolbarButtonSize.width
    + (toolbarSpacing * CGFloat(max(toolbarButtons.count - 1, 0)))
```

- [ ] **Step 3: 保持位置规则不变**

保留以下定位逻辑不变：

```swift
let toolbarX = min(
    max(previewSelectionRect.midX - (toolbarWidth / 2), 24),
    bounds.maxX - toolbarWidth - 24
)
let toolbarY = max(24, previewSelectionRect.minY - toolbarHeight - 24)
```

说明：

- 本轮只统一按钮尺寸，不改工具栏与选区的相对位置规则

- [ ] **Step 4: 运行构建验证**

Run:

```bash
./scripts/build.sh
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: 提交布局调整**

Run:

```bash
git add TYScreenShotTool/Features/CaptureOverlay/CaptureOverlayView.swift
git commit -m "feat(sprint-40): 统一工具栏图标按钮尺寸"
```

Expected: 提交集中在工具栏布局尺寸调整。

---

### Task 4: 为标注工具增加青色选中态与绘制动画

**Files:**
- Modify: `TYScreenShotTool/Features/CaptureOverlay/CaptureOverlayView.swift`

- [ ] **Step 1: 扩展 `updateAnnotationToolSelection()`**

将当前实现：

```swift
private func updateAnnotationToolSelection() {
    for (tool, button) in annotationToolButtons {
        button.state = tool == currentAnnotationTool ? .on : .off
    }
}
```

替换为：

```swift
private func updateAnnotationToolSelection() {
    for tool in AnnotationTool.allCases {
        guard let button = annotationToolButtons[tool] else {
            continue
        }

        let isSelected = tool == currentAnnotationTool
        button.state = isSelected ? .on : .off
        button.contentTintColor = isSelected ? toolbarSelectedTintColor : nil

        if isSelected {
            button.contentTintColor = toolbarSelectedTintColor
            button.addSymbolEffect(.drawOn.individually, options: .nonRepeating)
        }
    }
}
```

设计约束：

- 选中态只改变颜色，不切换成填充 symbol
- 功能按钮不进入这个更新逻辑，因此不会出现误高亮或误动画

- [ ] **Step 2: 保持再次点击同一工具可取消选中**

确认 `selectAnnotationTool(_:)` 中这段逻辑保持不变：

```swift
if currentAnnotationTool == tool {
    currentAnnotationTool = nil
} else {
    currentAnnotationTool = tool
}
```

说明：

- 这样可以确保“再次点击同一按钮取消选中，无动画”的验收规则仍然成立

- [ ] **Step 3: 为动画 API 准备最小降级方案**

如果 `button.addSymbolEffect(.drawOn.individually, options: .nonRepeating)` 在当前环境编译或运行表现异常，则使用如下最小降级方案替代：

```swift
button.wantsLayer = true

NSAnimationContext.runAnimationGroup { context in
    context.duration = 0.12
    button.animator().alphaValue = 0.8
    button.layer?.animator().setAffineTransform(CGAffineTransform(scaleX: 1.08, y: 1.08))
} completionHandler: {
    NSAnimationContext.runAnimationGroup { context in
        context.duration = 0.12
        button.animator().alphaValue = 1.0
        button.layer?.animator().setAffineTransform(.identity)
    }
}
```

要求：

- 仅在 `.drawOn.individually` 不可用时启用降级
- 默认实现仍以 `.drawOn.individually` 为主路径

- [ ] **Step 4: 运行构建验证**

Run:

```bash
./scripts/build.sh
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: 提交选中态视觉反馈**

Run:

```bash
git add TYScreenShotTool/Features/CaptureOverlay/CaptureOverlayView.swift
git commit -m "feat(sprint-40): 增加标注工具选中态反馈"
```

Expected: 提交集中在 `updateAnnotationToolSelection()` 与相关常量；这是 checkpoint commit，不与最终文档收尾提交混在一起。

---

### Task 5: 清理本地化更新逻辑并保留 Tooltip 文本

**Files:**
- Modify: `TYScreenShotTool/Features/CaptureOverlay/CaptureOverlayView.swift`

- [ ] **Step 1: 从 `applyLocalizedStrings()` 中移除工具栏标题赋值**

删除以下标题赋值：

```swift
undoButton.title = AppText.captureUndo
longCaptureButton.title = AppText.captureLongCapture
pinButton.title = AppText.capturePin
copyButton.title = AppText.captureCopy
saveButton.title = AppText.captureSave
cancelButton.title = AppText.captureCancel

for tool in AnnotationTool.allCases {
    annotationToolButtons[tool]?.title = tool.title
}
```

- [ ] **Step 2: 在 `applyLocalizedStrings()` 中改为刷新 Tooltip 与无障碍描述**

在保留：

```swift
cornerRadiusLabel.stringValue = AppText.captureCornerRadius
shadowToggle.title = AppText.captureShadow
```

的基础上，补充：

```swift
for tool in AnnotationTool.allCases {
    annotationToolButtons[tool]?.toolTip = tool.title
    annotationToolButtons[tool]?.setAccessibilityLabel(tool.title)
}

undoButton.toolTip = AppText.captureUndo
undoButton.setAccessibilityLabel(AppText.captureUndo)
longCaptureButton.toolTip = AppText.captureLongCapture
longCaptureButton.setAccessibilityLabel(AppText.captureLongCapture)
pinButton.toolTip = AppText.capturePin
pinButton.setAccessibilityLabel(AppText.capturePin)
copyButton.toolTip = AppText.captureCopy
copyButton.setAccessibilityLabel(AppText.captureCopy)
saveButton.toolTip = AppText.captureSave
saveButton.setAccessibilityLabel(AppText.captureSave)
cancelButton.toolTip = AppText.captureCancel
cancelButton.setAccessibilityLabel(AppText.captureCancel)
```

同时保留：

```swift
ocrButton.toolTip = "OCR"
ocrButton.setAccessibilityLabel("OCR")
aiButton.toolTip = "AI"
aiButton.setAccessibilityLabel("AI")
```

- [ ] **Step 3: 运行构建验证**

Run:

```bash
./scripts/build.sh
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: 提交本地化清理**

Run:

```bash
git add TYScreenShotTool/Features/CaptureOverlay/CaptureOverlayView.swift
git commit -m "feat(sprint-40): 清理工具栏标题本地化更新"
```

Expected: 提交集中在 `applyLocalizedStrings()` 与 Tooltip 刷新逻辑；这是 checkpoint commit，不与最终文档收尾提交混在一起。

---

### Task 6: Sprint 文档、任务文档与最终验证收尾

**Files:**
- Create: `docs/SPRINTS/Sprint-40.md`
- Modify: `docs/DEVLOG.md`
- Modify: `TASK.md`
- Optional Modify: `docs/ROADMAP.md`

- [ ] **Step 1: 新建 Sprint 40 文档**

创建 `docs/SPRINTS/Sprint-40.md`，结构参考 `docs/SPRINTS/Sprint-39.md`，至少包含：

```md
# Sprint 40 - 工具栏 SF Symbols

## Status

In Progress

## Goal

将截图编辑态工具栏由文字按钮升级为 SF Symbols 图标按钮，
并为标注工具增加青色选中态与单次绘制动画，
同时保持截图主链路功能不变。

## Scope

### Included

- 6 个标注工具按钮改为 SF Symbols
- 8 个功能按钮改为 SF Symbols
- 标注工具选中态改为青色高亮
- 选中时播放 `.drawOn.individually` 单次动画
- 所有按钮使用统一固定尺寸
- 每个按钮提供 Tooltip

### Out of Scope

- 不修改截图主链路功能行为
- 不修改长截图面板 UI
- 不新增快捷键
- 不引入第三方依赖
```

- [ ] **Step 2: 更新 TASK.md 到 Sprint 40 当前范围**

将 `TASK.md` 从 Sprint 39 已完成状态切换为 Sprint 40 当前任务，至少覆盖：

```md
Current Sprint: Sprint 40 In Progress
```

以及：

- 当前目标：工具栏 SF Symbols
- 本次范围：图标按钮、选中态、Tooltip、统一尺寸
- 验收标准：图标替换成功、标注工具青色高亮、功能按钮无选中态、构建通过

- [ ] **Step 3: 运行最终构建验证**

Run:

```bash
./scripts/build.sh
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: 执行人工验证**

人工验证清单：

1. 进入普通截图编辑态后，工具栏 14 个按钮全部显示为图标，无文字。
2. 6 个标注工具图标与 8 个功能按钮图标均显示正确，没有空白按钮。
3. 所有按钮尺寸一致，视觉上为统一固定尺寸，工具栏排列整齐。
4. 点击矩形 / 圆形 / 箭头 / 画笔 / 马赛克 / 文字时，当前按钮变为青色高亮。
5. 标注工具首次选中时播放一次 `.drawOn.individually` 风格动画。
6. 再次点击同一标注工具时，选中态取消，不播放动画。
7. 撤销 / 长截图 / OCR / AI / Pin / 复制 / 保存 / 取消 按钮不会出现选中高亮。
8. hover 所有按钮时均显示正确 Tooltip。
9. 当 AI 当前不可用时，`AI` 图标按钮保持禁用态展示，且不可点击。
10. 拖拽选区、标注绘制、圆角滑块、阴影开关功能正常。
11. OCR / AI / Pin / 复制 / 保存 / 取消 功能正常。
12. 长截图入口仍可正常进入，不受本轮工具栏图标改造影响。

- [ ] **Step 5: 更新 Sprint 文档结果与 DEVLOG**

在人工验证通过后：

- 将 `docs/SPRINTS/Sprint-40.md` 的 `Status` 改为 `Done`
- 在 `Result` 中记录：
  - 工具栏完成 SF Symbols 升级
  - 标注工具完成青色选中态与绘制动画
  - 验证结果
- 在 `docs/DEVLOG.md` 追加 Sprint 40 完成记录

- [ ] **Step 6: 仅在 Sprint 状态完成时更新 ROADMAP**

如果本轮已完成 Sprint 40，则在 `docs/ROADMAP.md` 中新增 Sprint 40 条目或更新当前状态；如果本轮仅完成规划或部分实现，则不要提前改 `ROADMAP`。

- [ ] **Step 7: 按 Git 工作流顺序检查 staged / commit / push 前状态**

Run:

```bash
git status --short
git diff --cached --stat
```

Expected:

- staged 区只包含 Sprint 40 本轮相关文件
- 不包含 `.gitignore` 等无关改动，除非它本身就是本轮范围

- [ ] **Step 8: 只提交收尾文档与最终验证增量**

Run:

```bash
git add docs/SPRINTS/Sprint-40.md docs/DEVLOG.md TASK.md
git commit -m "feat(sprint-40): 补齐工具栏图标迭代文档"
```

如果最终人工验证中发现仍需对 `CaptureOverlayView.swift` 或 `AnnotationTool.swift` 做最后的小修正，再把对应代码文件一并加入这次最终提交。

如果 `docs/ROADMAP.md` 本轮确实发生了状态更新，再单独加入 `git add`。

Expected:

- 前面 Task 1-5 的 checkpoint commits 保持各自边界清晰
- 这里的最终提交只包含收尾文档和最终验证产生的少量增量
- commit message 使用中文，且只包含 Sprint 40 直接相关文件。

---

## Self-Review

### 1. Spec coverage

- 工具栏全部改为 SF Symbols：Task 1 + Task 2
- 标注工具青色选中态：Task 4
- `.drawOn.individually` 单次动画：Task 4
- 统一固定尺寸按钮：Task 3
- Tooltip：Task 2 + Task 5
- 保持现有 `.popover` 容器样式：Task 2
- 不影响截图、OCR、AI、Pin、保存等链路：Task 6 人工验证覆盖

### 2. Placeholder scan

- 已移除 `TBD` / `类似 Task N` / 无作用域示例代码
- 所有代码步骤都给出具体代码或具体命令
- 所有收尾步骤都指向明确文件与命令

### 3. Type consistency

- `symbolName` 与当前 `AnnotationTool` 命名一致
- `toolbarSymbolConfiguration` / `toolbarSelectedTintColor` / `toolbarButtonSize` 均在 `CaptureOverlayView` 内定义
- `updateAnnotationToolSelection()` 仅操作 `annotationToolButtons`
- Tooltip 和 accessibility label 使用当前 `AppText` / 固定 `OCR` / `AI` 字符串，不依赖不存在的字段
