# Sprint 41 - 矩形属性面板实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为矩形工具新增属性面板，支持调整粗细(1-12px)、透明度(0-100%)、圆角(0-100)、实心/空心、颜色(预设8色)。点击已画矩形可选中并调整属性，面板值作为新矩形默认值。

**Architecture:** 新增 `RGBColor` + `RectangleProperties` 数据模型，`RectanglePropertyPanelView` 独立面板视图（NSVisualEffectView，两排布局），`CaptureAnnotationCanvasView` 新增选中交互与基于属性的矩形渲染，`CaptureOverlayView` 负责面板生命周期。

**Tech Stack:** Swift 6, AppKit, NSVisualEffectView, NSPopUpButton, NSSlider, NSSegmentedControl, NSButton

---

## File Structure

- Create: `TYScreenShotTool/Shared/RGBColor.swift`
  - `RGBColor` Equatable 颜色结构体 + 预设 8 色 + toCGColor() 方法
- Create: `TYScreenShotTool/Shared/RectangleProperties.swift`
  - `RectangleProperties` 结构体 + static let default
- Create: `TYScreenShotTool/Features/CaptureOverlay/RectanglePropertyPanelView.swift`
  - `RectanglePropertyPanelView: NSVisualEffectView` 两排布局面板
- Modify: `TYScreenShotTool/Shared/CaptureAnnotation.swift`
  - `.rectangle(CGRect)` → `.rectangle(CGRect, RectangleProperties)`
  - 拆分 `case let .rectangle(rect), let .ellipse(rect), let .mosaic(rect)` 的多模式匹配
  - 保留静态 strokeColor/lineWidth 供其他工具使用
- Modify: `TYScreenShotTool/Features/CaptureOverlay/CaptureAnnotationCanvasView.swift`
  - 新增选中交互（selectedAnnotationIndex + 点击检测）
  - 基于 RectangleProperties 的矩形渲染
  - 选中高亮（青色虚线边框）
- Modify: `TYScreenShotTool/Features/CaptureOverlay/CaptureOverlayView.swift`
  - 集成 RectanglePropertyPanelView 生命周期与布局
- Modify: `TYScreenShotTool/Services/CaptureSessionService.swift`
  - 导出渲染中的矩形绘制读取 RectangleProperties

说明：
- 当前项目没有独立 test target，以 `./scripts/build.sh` 与人工验证为主。
- 本轮只改矩形工具，不涉及椭圆/箭头/画笔/马赛克/文字。
- CaptureAnnotation 的 strokeColor/lineWidth 静态常量仍保留（其他工具使用）。
- commit message 需遵守 `docs/GIT_WORKFLOW.md`，使用中文。

---

### Task 1: 新建 RGBColor 数据模型

**Files:**
- Create: `TYScreenShotTool/Shared/RGBColor.swift`

- [ ] **Step 1: 创建 RGBColor.swift**

```swift
//  RGBColor.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/21.
//

import AppKit

/// Equatable 颜色值，用于矩形属性持久化和比较
struct RGBColor: Equatable {
    var red: CGFloat   // 0.0-1.0
    var green: CGFloat
    var blue: CGFloat

    /// 转换为 NSColor
    func toNSColor() -> NSColor {
        NSColor(red: red, green: green, blue: blue, alpha: 1.0)
    }

    /// 转换为 CGColor
    func toCGColor() -> CGColor {
        CGColor(red: red, green: green, blue: blue, alpha: 1.0)
    }

    /// 预设 8 色
    static let presetColors: [RGBColor] = [
        RGBColor(red: 0.93, green: 0.24, blue: 0.21),   // 红
        RGBColor(red: 1.00, green: 0.58, blue: 0.00),   // 橙
        RGBColor(red: 1.00, green: 0.80, blue: 0.00),   // 黄
        RGBColor(red: 0.20, green: 0.78, blue: 0.35),   // 绿
        RGBColor(red: 0.00, green: 0.48, blue: 1.00),   // 蓝
        RGBColor(red: 0.69, green: 0.32, blue: 0.87),   // 紫
        RGBColor(red: 1.00, green: 1.00, blue: 1.00),   // 白
        RGBColor(red: 0.00, green: 0.00, blue: 0.00),   // 黑
    ]
}
```

- [ ] **Step 2: 运行构建验证**

Run:
```bash
./scripts/build.sh
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: 提交**

Run:
```bash
git add TYScreenShotTool/Shared/RGBColor.swift
git commit -m "feat(sprint-41): 新增 RGBColor 数据模型"
```

---

### Task 2: 新建 RectangleProperties 数据模型

**Files:**
- Create: `TYScreenShotTool/Shared/RectangleProperties.swift`

- [ ] **Step 1: 创建 RectangleProperties.swift**

```swift
//  RectangleProperties.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/21.
//

import Foundation

/// 矩形标注的样式属性
struct RectangleProperties: Equatable {
    /// 线宽 1-12px
    var lineWidth: CGFloat
    /// 透明度 0.0-1.0
    var opacity: CGFloat
    /// 圆角 0-100
    var cornerRadius: CGFloat
    /// false=空心（仅描边）, true=实心（填充+描边）
    var isFilled: Bool
    /// 颜色
    var color: RGBColor

    /// 默认值：红色 3px 空心，不透明，无圆角
    static let `default` = RectangleProperties(
        lineWidth: 3,
        opacity: 1.0,
        cornerRadius: 0,
        isFilled: false,
        color: RGBColor(red: 0.93, green: 0.24, blue: 0.21)
    )
}
```

- [ ] **Step 2: 运行构建验证**

Run:
```bash
./scripts/build.sh
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: 提交**

Run:
```bash
git add TYScreenShotTool/Shared/RectangleProperties.swift
git commit -m "feat(sprint-41): 新增 RectangleProperties 数据模型"
```

---

### Task 3: 更新 CaptureAnnotation 枚举

**Files:**
- Modify: `TYScreenShotTool/Shared/CaptureAnnotation.swift`

- [ ] **Step 1: 修改 rectangle case 并拆分多模式匹配**

将：
```swift
case rectangle(CGRect)
```
改为：
```swift
case rectangle(CGRect, RectangleProperties)
```

将 bounds 属性中的多模式匹配：
```swift
case let .rectangle(rect), let .ellipse(rect), let .mosaic(rect):
    return rect.standardized
```
拆分为：
```swift
case let .rectangle(rect, _):
    return rect.standardized
case let .ellipse(rect):
    return rect.standardized
case let .mosaic(rect):
    return rect.standardized
```

同时保留其他 case 和静态常量（strokeColor, lineWidth 等仍然被椭圆/箭头/画笔/文字使用，不能移除）。

修改后的完整 `CaptureAnnotation.swift` 文件：

```swift
import CoreGraphics
import Foundation

/// 截图标注类型
enum CaptureAnnotation: Equatable {
    /// 矩形标注（位置 + 样式属性）
    case rectangle(CGRect, RectangleProperties)
    /// 圆形标注
    case ellipse(CGRect)
    /// 箭头标注，包含起点和终点
    case arrow(start: CGPoint, end: CGPoint)
    /// 画笔标注，包含一系列点
    case pen(points: [CGPoint])
    /// 马赛克标注
    case mosaic(CGRect)
    /// 文字标注，包含文本内容和位置
    case text(value: String, origin: CGPoint)

    /// 标注描边颜色（红色）- 供其他工具（非矩形）使用
    static let strokeColor = CGColor(red: 0.93, green: 0.24, blue: 0.21, alpha: 1)
    /// 标注线条宽度 - 供其他工具（非矩形）使用
    static let lineWidth: CGFloat = 3
    /// 文字标注字体大小
    static let fontSize: CGFloat = 22
    /// 马赛克模糊半径
    static let mosaicBlurRadius: CGFloat = 18
    /// 马赛克覆盖层透明度
    static let mosaicOverlayAlpha: CGFloat = 0.10
    /// 马赛克区域圆角半径
    static let mosaicCornerRadius: CGFloat = 6

    var bounds: CGRect {
        switch self {
        case let .rectangle(rect, _):
            return rect.standardized
        case let .ellipse(rect):
            return rect.standardized
        case let .mosaic(rect):
            return rect.standardized
        case let .arrow(start, end):
            return CGRect(
                x: min(start.x, end.x),
                y: min(start.y, end.y),
                width: abs(end.x - start.x),
                height: abs(end.y - start.y)
            ).insetBy(dx: -12, dy: -12)
        case let .pen(points):
            guard let first = points.first else { return .zero }
            return points.dropFirst().reduce(
                CGRect(origin: first, size: .zero).insetBy(dx: -6, dy: -6)
            ) { partialResult, point in
                partialResult.union(CGRect(origin: point, size: .zero).insetBy(dx: -6, dy: -6))
            }
        case let .text(value, origin):
            let width = max(CGFloat(value.count) * CaptureAnnotation.fontSize * 0.6, CaptureAnnotation.fontSize)
            return CGRect(
                x: origin.x,
                y: origin.y,
                width: width,
                height: CaptureAnnotation.fontSize * 1.4
            )
        }
    }
}
```

- [ ] **Step 2: 运行构建验证**

此时构建会失败（因为 `CaptureAnnotationCanvasView.swift` 和 `CaptureSessionService.swift` 还在用旧的 `.rectangle(CGRect)` 和旧的多模式匹配），验证失败是预期的中间状态。

Run:
```bash
./scripts/build.sh
```
Expected: BUILD FAILED（后续 Task 修复）

- [ ] **Step 3: 提交**

Run:
```bash
git add TYScreenShotTool/Shared/CaptureAnnotation.swift
git commit -m "feat(sprint-41): 更新 CaptureAnnotation.rectangle 携带属性参数"
```

---

### Task 4: 更新画布矩形渲染与选中交互

**Files:**
- Modify: `TYScreenShotTool/Features/CaptureOverlay/CaptureAnnotationCanvasView.swift`

- [ ] **Step 1: 在类中新增选中相关属性和方法**

在 `private var activeTextField: NSTextField?` 附近添加：

```swift
/// 当前选中的标注索引（仅 rectangle 工具使用）
private var selectedAnnotationIndex: Int?
/// 选中状态变更回调：索引, 属性值
var onAnnotationSelected: ((Int?, RectangleProperties?) -> Void)?
```

添加实时更新方法：

```swift
/// 更新选中矩形的样式属性（由面板回调触发）
func updateSelectedAnnotation(with properties: RectangleProperties) {
    guard let idx = selectedAnnotationIndex,
          annotations.indices.contains(idx),
          case .rectangle(let rect, _) = annotations[idx] else { return }
    annotations[idx] = .rectangle(rect, properties)
    needsDisplay = true
}
```

- [ ] **Step 2: 修改 makeDragAnnotation 中的矩形创建逻辑**

将：
```swift
case .rectangle:
    return .rectangle(normalizedRect(from: start, to: end))
```
改为使用 RectangleProperties.default：
```swift
case .rectangle:
    return .rectangle(normalizedRect(from: start, to: end), RectangleProperties.default)
```

- [ ] **Step 3: 修改 finalizeDragAnnotation 的多模式匹配**

将：
```swift
case let .rectangle(rect), let .ellipse(rect), let .mosaic(rect):
    guard rect.standardized.width > 4, rect.standardized.height > 4 else { return }
```
拆分为：
```swift
case let .rectangle(rect, _):
    guard rect.standardized.width > 4, rect.standardized.height > 4 else { return }
case let .ellipse(rect):
    guard rect.standardized.width > 4, rect.standardized.height > 4 else { return }
case let .mosaic(rect):
    guard rect.standardized.width > 4, rect.standardized.height > 4 else { return }
```

- [ ] **Step 4: 修改矩形绘制方法，使用 RectangleProperties**

将 draw(annotation:) 中的：
```swift
case let .rectangle(rect):
    let path = NSBezierPath(rect: rect.standardized)
    configureStroke()
    path.lineWidth = CaptureAnnotation.lineWidth
    path.stroke()
```
替换为：
```swift
case let .rectangle(rect, props):
    let standardizedRect = rect.standardized
    let path: NSBezierPath
    if props.cornerRadius > 0 {
        path = NSBezierPath(roundedRect: standardizedRect, xRadius: props.cornerRadius, yRadius: props.cornerRadius)
    } else {
        path = NSBezierPath(rect: standardizedRect)
    }

    let color = props.color.toNSColor().withAlphaComponent(props.opacity)

    if props.isFilled {
        color.setFill()
        path.fill()
        // 实心模式下描边线宽减半
        color.setStroke()
        path.lineWidth = props.lineWidth / 2
        path.stroke()
    } else {
        color.setStroke()
        path.lineWidth = props.lineWidth
        path.stroke()
    }
```

- [ ] **Step 5: 为已选中矩形绘制选中高亮**

在 draw(annotation:) 的 `.rectangle` case 渲染完成后，追加选中高亮绘制。在 `.rectangle` case 的末尾（path.stroke() 之后），添加：

```swift
// 选中高亮 — 青色虚线边框
if annotations[idx] == annotation,
   let selectedIdx = selectedAnnotationIndex,
   annotations.indices.contains(selectedIdx),
   case .rectangle(let selectedRect, _) = annotations[selectedIdx],
   selectedRect == rect {
    let highlightRect = standardizedRect.insetBy(dx: -4, dy: -4)
    let highlightPath: NSBezierPath
    if props.cornerRadius > 0 {
        highlightPath = NSBezierPath(roundedRect: highlightRect, xRadius: props.cornerRadius + 4, yRadius: props.cornerRadius + 4)
    } else {
        highlightPath = NSBezierPath(rect: highlightRect)
    }
    NSColor.systemCyan.setStroke()
    highlightPath.lineWidth = 2
    let dashes: [CGFloat] = [6, 4]
    highlightPath.setLineDash(dashes, count: 2, phase: 0)
    highlightPath.stroke()
}
```

注意：由于 `draw(annotation:)` 接收 `CaptureAnnotation` 值，而不是索引，我们需要一种方式来知道当前绘制的 annotation 是否是被选中的那个。然而，`draw(annotation:)` 是通过遍历 `annotations` 并在循环中调用 `draw(annotation: annotation)` 来实现的。我们需要一种方式来判断。

更好的方式：修改 `draw(_:)` 方法中的循环，传入索引：

```swift
override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)

    for (index, annotation) in annotations.enumerated() {
        draw(annotation: annotation, at: index)
    }

    if let temporaryAnnotation {
        draw(annotation: temporaryAnnotation, at: nil)
    }
}

private func draw(annotation: CaptureAnnotation, at index: Int?) {
    switch annotation {
    case let .rectangle(rect, props):
        // ... existing rectangle rendering ...

        // 选中高亮
        if let index, index == selectedAnnotationIndex {
            let standardizedRect = rect.standardized
            let highlightRect = standardizedRect.insetBy(dx: -4, dy: -4)
            let highlightPath: NSBezierPath
            if props.cornerRadius > 0 {
                highlightPath = NSBezierPath(roundedRect: highlightRect,
                    xRadius: props.cornerRadius + 4, yRadius: props.cornerRadius + 4)
            } else {
                highlightPath = NSBezierPath(rect: highlightRect)
            }
            NSColor.systemCyan.setStroke()
            highlightPath.lineWidth = 2
            let dashes: [CGFloat] = [6, 4]
            highlightPath.setLineDash(dashes, count: 2, phase: 0)
            highlightPath.stroke()
        }
    // ... other cases unchanged ...
    }
}
```

同时将原来的 `draw(annotation: CaptureAnnotation)` 私有方法签名改为 `draw(annotation: CaptureAnnotation, at index: Int?)`，其他 case 保持不变。

- [ ] **Step 6: 修改 mouseDown 增加选中检测**

在 `mouseDown` 方法的 `case .rectangle, .ellipse, .arrow:` 分支中，在调用 `makeDragAnnotation` 之前插入选中检测逻辑：

将：
```swift
case .rectangle, .ellipse, .arrow:
    dragStartPoint = point
    currentPoint = point
    temporaryAnnotation = makeDragAnnotation(from: point, to: point)
    needsDisplay = true
```
改为：
```swift
case .rectangle:
    // 先检测是否点击了已画矩形（从后往前）
    if let hitIndex = hitTestRectangle(at: point) {
        selectedAnnotationIndex = hitIndex
        if case .rectangle(_, let props) = annotations[hitIndex] {
            onAnnotationSelected?(hitIndex, props)
        }
        needsDisplay = true
        return
    }
    selectedAnnotationIndex = nil
    onAnnotationSelected?(nil, nil)
    fallthrough
case .ellipse, .arrow:
    dragStartPoint = point
    currentPoint = point
    temporaryAnnotation = makeDragAnnotation(from: point, to: point)
    needsDisplay = true
```

添加命中检测辅助方法：

```swift
/// 检测点击点是否落在某个已画矩形上
/// 从后往前遍历，返回最顶层矩形的索引
private func hitTestRectangle(at point: CGPoint) -> Int? {
    for index in annotations.indices.reversed() {
        guard case .rectangle(let rect, _) = annotations[index] else {
            continue
        }
        if rect.standardized.contains(point) {
            return index
        }
    }
    return nil
}
```

- [ ] **Step 7: 在 undoLastAnnotation 中处理选中索引失效**

修改 `undoLastAnnotation()`，在 `annotations.removeLast()` 后检查选中索引：

```swift
func undoLastAnnotation() {
    commitActiveTextIfNeeded()

    guard annotations.isEmpty == false else { return }

    _ = annotations.removeLast()

    // 如果删除的标注恰好是被选中的，清空选中
    if let selectedIdx = selectedAnnotationIndex, !annotations.indices.contains(selectedIdx) {
        selectedAnnotationIndex = nil
        onAnnotationSelected?(nil, nil)
    }

    annotationsDidChange?(annotations)
    needsDisplay = true
    applyCursorForCurrentState()
}
```

- [ ] **Step 8: 在 resetAnnotations 中清空选中状态**

修改 `resetAnnotations()`，在末尾添加：

```swift
selectedAnnotationIndex = nil
```

- [ ] **Step 9: 运行构建验证**

Run:
```bash
./scripts/build.sh
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 10: 提交**

Run:
```bash
git add TYScreenShotTool/Features/CaptureOverlay/CaptureAnnotationCanvasView.swift
git commit -m "feat(sprint-41): 实现矩形选中交互与基于属性的渲染"
```

---

### Task 5: 新建 RectanglePropertyPanelView 面板

**Files:**
- Create: `TYScreenShotTool/Features/CaptureOverlay/RectanglePropertyPanelView.swift`

- [ ] **Step 1: 创建面板视图文件**

```swift
//  RectanglePropertyPanelView.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/21.
//

import AppKit

/// 矩形属性面板 — 在工具栏下方显示，支持调整粗细/透明度/圆角/实心空心/颜色
final class RectanglePropertyPanelView: NSVisualEffectView {
    /// 属性变更回调
    var onPropertyChanged: ((RectangleProperties) -> Void)?

    /// 防止 updateDisplay 触发重复回调的标志
    private var isUpdatingDisplay = false

    private var currentProperties = RectangleProperties.default {
        didSet {
            guard !isUpdatingDisplay else { return }
            onPropertyChanged?(currentProperties)
        }
    }

    // MARK: - 控件

    private let lineWidthPopUp = NSPopUpButton()
    private let opacitySlider = NSSlider()
    private let opacityLabel = NSTextField(labelWithString: "100%")
    private let cornerRadiusSlider = NSSlider()
    private let cornerRadiusLabel = NSTextField(labelWithString: "0px")
    private let styleSegmented = NSSegmentedControl()
    private var colorButtons: [NSButton] = []

    // MARK: - 初始化

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
        setupControls()
        layoutControls()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        material = .popover
        blendingMode = .withinWindow
        state = .active
        wantsLayer = true
        layer?.cornerRadius = 10
    }

    private func setupControls() {
        // 粗细下拉选 1-12px
        for i in 1...12 {
            lineWidthPopUp.addItem(withTitle: "\(i)px")
        }
        lineWidthPopUp.selectItem(at: 2) // 默认 3px
        lineWidthPopUp.target = self
        lineWidthPopUp.action = #selector(lineWidthChanged)
        lineWidthPopUp.font = .systemFont(ofSize: 11)
        lineWidthPopUp.bezelStyle = .texturedRounded

        // 透明度滑块 0-100%
        opacitySlider.minValue = 0
        opacitySlider.maxValue = 100
        opacitySlider.doubleValue = 100
        opacitySlider.isContinuous = true
        opacitySlider.target = self
        opacitySlider.action = #selector(opacityChanged)
        opacitySlider.controlSize = .small

        opacityLabel.font = .monospacedDigitSystemFont(ofSize: 10, weight: .medium)
        opacityLabel.textColor = .secondaryLabelColor
        opacityLabel.alignment = .right

        // 圆角滑块 0-100
        cornerRadiusSlider.minValue = 0
        cornerRadiusSlider.maxValue = 100
        cornerRadiusSlider.doubleValue = 0
        cornerRadiusSlider.isContinuous = true
        cornerRadiusSlider.target = self
        cornerRadiusSlider.action = #selector(cornerRadiusChanged)
        cornerRadiusSlider.controlSize = .small

        cornerRadiusLabel.font = .monospacedDigitSystemFont(ofSize: 10, weight: .medium)
        cornerRadiusLabel.textColor = .secondaryLabelColor
        cornerRadiusLabel.alignment = .right

        // 样式分段按钮
        styleSegmented.segmentCount = 2
        styleSegmented.setLabel("■ 实心", forSegment: 0)
        styleSegmented.setLabel("□ 空心", forSegment: 1)
        styleSegmented.selectedSegment = 1 // 默认空心
        styleSegmented.segmentStyle = .texturedRounded
        styleSegmented.target = self
        styleSegmented.action = #selector(styleChanged)
        styleSegmented.font = .systemFont(ofSize: 10)

        // 颜色圆点按钮
        for (index, preset) in RGBColor.presetColors.enumerated() {
            let button = NSButton(frame: .zero)
            button.wantsLayer = true
            button.isBordered = false
            button.layer?.backgroundColor = preset.toNSColor().cgColor
            button.layer?.cornerRadius = 10
            button.tag = index
            button.target = self
            button.action = #selector(colorChanged(_:))
            button.toolTip = colorName(at: index)
            colorButtons.append(button)
            addSubview(button)
        }
        updateColorSelection(selectedIndex: 0) // 默认红色选中
    }

    private func layoutControls() {
        // 布局由外部通过 frame 控制
        // 两排控件在 layout() 中定位
    }

    override func layout() {
        super.layout()

        let paddingX: CGFloat = 12
        let paddingY: CGFloat = 10
        let spacing: CGFloat = 20
        let controlHeight: CGFloat = 22
        let rowWidth = bounds.width - paddingX * 2
        let rowCenterY1 = bounds.height - paddingY - controlHeight / 2
        let rowCenterY2 = paddingY + controlHeight / 2

        // 第一排：粗细 + 透明度 + 圆角
        let lineWidthWidth: CGFloat = 60
        let sliderWidth: CGFloat = 80
        let labelWidth: CGFloat = 32
        let firstRowItemCount: CGFloat = 3
        let firstRowTotalWidth = lineWidthWidth + spacing + sliderWidth + labelWidth + spacing + sliderWidth + labelWidth
        let firstRowX = paddingX

        // 粗细
        lineWidthPopUp.frame = CGRect(x: firstRowX, y: rowCenterY1 - controlHeight / 2,
                                       width: lineWidthWidth, height: controlHeight)

        // 透明度
        let opacityX = firstRowX + lineWidthWidth + spacing
        opacitySlider.frame = CGRect(x: opacityX, y: rowCenterY1 - 14,
                                      width: sliderWidth, height: 28)
        opacityLabel.frame = CGRect(x: opacityX + sliderWidth + 4, y: rowCenterY1 - 8,
                                     width: labelWidth, height: 16)

        // 圆角
        let cornerX = opacityX + sliderWidth + labelWidth + spacing
        cornerRadiusSlider.frame = CGRect(x: cornerX, y: rowCenterY1 - 14,
                                           width: sliderWidth, height: 28)
        cornerRadiusLabel.frame = CGRect(x: cornerX + sliderWidth + 4, y: rowCenterY1 - 8,
                                          width: labelWidth, height: 16)

        // 第二排：样式 + 颜色
        let styleWidth: CGFloat = 120
        styleSegmented.frame = CGRect(x: paddingX, y: rowCenterY2 - controlHeight / 2,
                                       width: styleWidth, height: controlHeight)

        // 颜色圆点
        let colorSize: CGFloat = 20
        let colorSpacing: CGFloat = 6
        let colorStartX = styleSegmented.frame.maxX + spacing
        for (i, button) in colorButtons.enumerated() {
            button.frame = CGRect(
                x: colorStartX + CGFloat(i) * (colorSize + colorSpacing),
                y: rowCenterY2 - colorSize / 2,
                width: colorSize,
                height: colorSize
            )
        }
    }

    // MARK: - Actions

    @objc private func lineWidthChanged() {
        let selectedIndex = lineWidthPopUp.indexOfSelectedItem
        currentProperties.lineWidth = CGFloat(selectedIndex + 1)
    }

    @objc private func opacityChanged() {
        let value = opacitySlider.doubleValue
        opacityLabel.stringValue = "\(Int(value))%"
        currentProperties.opacity = CGFloat(value) / 100.0
    }

    @objc private func cornerRadiusChanged() {
        let value = cornerRadiusSlider.doubleValue
        cornerRadiusLabel.stringValue = "\(Int(value))px"
        currentProperties.cornerRadius = CGFloat(value)
    }

    @objc private func styleChanged() {
        currentProperties.isFilled = (styleSegmented.selectedSegment == 0)
    }

    @objc private func colorChanged(_ sender: NSButton) {
        let index = sender.tag
        guard index >= 0, index < RGBColor.presetColors.count else { return }
        currentProperties.color = RGBColor.presetColors[index]
        updateColorSelection(selectedIndex: index)
    }

    // MARK: - 更新面板显示

    /// 外部调用：将面板值同步到指定属性（用于选中矩形后同步）
    func updateDisplay(with properties: RectangleProperties) {
        isUpdatingDisplay = true
        currentProperties = properties

        // 粗细
        let lineWidthIndex = max(0, min(Int(properties.lineWidth) - 1, 11))
        lineWidthPopUp.selectItem(at: lineWidthIndex)

        // 透明度
        opacitySlider.doubleValue = Double(properties.opacity * 100)
        opacityLabel.stringValue = "\(Int(properties.opacity * 100))%"

        // 圆角
        cornerRadiusSlider.doubleValue = Double(properties.cornerRadius)
        cornerRadiusLabel.stringValue = "\(Int(properties.cornerRadius))px"

        // 样式
        styleSegmented.selectedSegment = properties.isFilled ? 0 : 1

        // 颜色
        if let colorIndex = RGBColor.presetColors.firstIndex(of: properties.color) {
            updateColorSelection(selectedIndex: colorIndex)
        }

        isUpdatingDisplay = false
    }

    private func updateColorSelection(selectedIndex: Int) {
        for (i, button) in colorButtons.enumerated() {
            button.layer?.borderWidth = (i == selectedIndex) ? 2 : 0
            button.layer?.borderColor = (i == selectedIndex) ?
                NSColor.systemCyan.cgColor : nil
        }
    }

    private func colorName(at index: Int) -> String {
        ["红", "橙", "黄", "绿", "蓝", "紫", "白", "黑"][safe: index] ?? ""
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
```

- [ ] **Step 2: 运行构建验证**

Run:
```bash
./scripts/build.sh
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: 提交**

Run:
```bash
git add TYScreenShotTool/Features/CaptureOverlay/RectanglePropertyPanelView.swift
git commit -m "feat(sprint-41): 新增矩形属性面板视图"
```

---

### Task 6: 集成面板到 CaptureOverlayView

**Files:**
- Modify: `TYScreenShotTool/Features/CaptureOverlay/CaptureOverlayView.swift`

- [ ] **Step 1: 添加 rectanglePanelView 属性和 currentRectangleProperties 状态**

在 `CaptureOverlayView` 中现有按钮属性附近添加：

```swift
/// 矩形属性面板
private let rectanglePanelView = RectanglePropertyPanelView()
/// 当前矩形属性（新矩形默认值 + 面板状态）
private var currentRectangleProperties = RectangleProperties.default
```

- [ ] **Step 2: 在 init 或 configureToolbar 后添加面板配置**

在 `configureToolbar()` 调用之后（如 `init` 中），或在 `configurePropertyPanel()` 中添加：

```swift
private func configurePropertyPanel() {
    rectanglePanelView.onPropertyChanged = { [weak self] properties in
        guard let self else { return }
        // 更新当前默认属性（新矩形使用）
        self.currentRectangleProperties = properties
        // 如果有选中的矩形，实时更新
        self.annotationCanvasView.updateSelectedAnnotation(with: properties)
    }

    annotationCanvasView.onAnnotationSelected = { [weak self] index, properties in
        guard let self else { return }
        if let properties {
            self.rectanglePanelView.updateDisplay(with: properties)
            self.rectanglePanelView.isHidden = false
        } else {
            // 取消选中时，面板保持显示但显示默认值
            self.rectanglePanelView.updateDisplay(with: self.currentRectangleProperties)
        }
    }

    rectanglePanelView.isHidden = true
    addSubview(rectanglePanelView)
}
```

在 `init(frame:)` 中追加调用：

```swift
override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    configurePreviewViews()
    configureTopBar()
    configureToolbar()
    configurePropertyPanel()  // 新增
    applyAppearanceStyling()
    resetToSelectionMode()
}
```

- [ ] **Step 3: 在 selectAnnotationTool 中控制面板显隐**

修改 `selectAnnotationTool(_:)`：

在 `annotationCanvasView.currentTool = currentAnnotationTool` 之后，添加：

```swift
// 控制矩形属性面板显隐
rectanglePanelView.isHidden = (currentAnnotationTool != .rectangle)
if currentAnnotationTool == .rectangle {
    rectanglePanelView.updateDisplay(with: currentRectangleProperties)
}
```

当选择其他工具时也要清空选中状态：

```swift
// 切到非矩形工具时清空选中
if currentAnnotationTool != .rectangle {
    annotationCanvasView.selectedAnnotationIndex = nil
}
```

整体修改后的 `selectAnnotationTool`：

```swift
@objc private func selectAnnotationTool(_ sender: NSButton) {
    guard let tool = annotationToolButtons.first(where: { $0.value === sender })?.key else {
        return
    }

    if currentAnnotationTool != tool {
        currentAnnotationTool = tool
    }

    annotationCanvasView.currentTool = currentAnnotationTool

    // 控制矩形属性面板显隐
    if currentAnnotationTool == .rectangle {
        rectanglePanelView.isHidden = false
        rectanglePanelView.updateDisplay(with: currentRectangleProperties)
    } else {
        rectanglePanelView.isHidden = true
        annotationCanvasView.selectedAnnotationIndex = nil
    }

    updateAnnotationToolSelection()
    window?.makeFirstResponder(annotationCanvasView)
    updateCursorFromCurrentEvent()
}
```

- [ ] **Step 4: 在 layoutPreviewInterface 中添加面板布局**

在 toolbar 布局完成后（工具栏 frame 设置之后），添加面板布局逻辑：

```swift
// 矩形属性面板布局（在工具栏下方）
let panelY = max(24, toolbarY - 90 - 8)  // 防止溢出屏幕底部
rectanglePanelView.frame = CGRect(
    x: toolbarX + (toolbarWidth - 320) / 2,
    y: panelY,
    width: 320,
    height: 90
)
```

注意：这块代码需要在 `toolbarContainerView.frame` 设置之后执行。
同时，`toolbarX` 和 `toolbarWidth` 是 `layoutPreviewInterface` 方法中的局部变量，因此面板布局代码需要放在同一个方法中、工具栏布局之后。

找到 `toolbarContainerView.frame = CGRect(...)` 之后的位置，添加上述面板布局代码。

- [ ] **Step 5: 在 makeDragAnnotation 中传入当前属性**

修改 `CaptureAnnotationCanvasView` 的 `makeDragAnnotation` 或对外暴露一个属性让 CaptureOverlayView 能设置当前矩形属性。

因为 `makeDragAnnotation` 当前在 canvas 内部调用 `.rectangle(rect, RectangleProperties.default)`，我们需要让它可以读取外部设置的当前属性。

有两种方案：

**方案 A**: 在 CaptureAnnotationCanvasView 上新增一个属性 `currentRectangleProperties`

在 `CaptureAnnotationCanvasView` 中添加：
```swift
/// 新矩形使用的默认属性（由 CaptureOverlayView 同步）
var currentRectangleProperties = RectangleProperties.default
```

将 makeDragAnnotation 中的：
```swift
case .rectangle:
    return .rectangle(normalizedRect(from: start, to: end), RectangleProperties.default)
```
改为：
```swift
case .rectangle:
    return .rectangle(normalizedRect(from: start, to: end), currentRectangleProperties)
```

然后在 `CaptureOverlayView` 中，每次 `currentRectangleProperties` 变化时，同步给 canvas：

```swift
// 在 configurePropertyPanel 中：
rectanglePanelView.onPropertyChanged = { [weak self] properties in
    guard let self else { return }
    self.currentRectangleProperties = properties
    self.annotationCanvasView.currentRectangleProperties = properties  // 同步
    self.annotationCanvasView.updateSelectedAnnotation(with: properties)
}
```

- [ ] **Step 6: 在 requestCancel 和取消选中时确保隐藏面板**

`requestCancel` 中不需要额外改动（它会触发 `onCancel` 回调，关闭整个覆盖层）。

但需要在 `resetToSelectionMode()` 中添加面板隐藏：

```swift
func resetToSelectionMode() {
    mode = .selection
    currentAnnotationTool = nil
    annotationCanvasView.currentTool = nil
    if previewSelectionRect == nil {
        previewContainerView.isHidden = true
        topBarContainerView.isHidden = true
        toolbarContainerView.isHidden = true
        rectanglePanelView.isHidden = true  // 新增
    }
    annotationCanvasView.resetAnnotations()
    // ...
}
```

同时在 `showSelectionPreview` 中确保面板初始隐藏：

```swift
func showSelectionPreview(selectionRect: CGRect, sourceScreenImage: CGImage?, screenFrame: CGRect) {
    // ...
    currentAnnotationTool = nil
    rectanglePanelView.isHidden = true  // 新增
    // ...
}
```

同时让 `enterLongCaptureGuideMode` 也隐藏面板：

```swift
func enterLongCaptureGuideMode() {
    guard mode == .preview, previewSelectionRect != nil else { return }
    isLongCaptureGuideMode = true
    suppressFrozenBackground = true
    previewContainerView.isHidden = true
    topBarContainerView.isHidden = true
    toolbarContainerView.isHidden = true
    rectanglePanelView.isHidden = true  // 新增
    needsDisplay = true
}
```

- [ ] **Step 7: 运行构建验证**

Run:
```bash
./scripts/build.sh
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 8: 提交**

Run:
```bash
git add TYScreenShotTool/Features/CaptureOverlay/CaptureOverlayView.swift
git commit -m "feat(sprint-41): 集成矩形属性面板到覆盖层视图"
```

---

### Task 7: 更新导出渲染中的矩形绘制

**Files:**
- Modify: `TYScreenShotTool/Services/CaptureSessionService.swift`

- [ ] **Step 1: 修改导出渲染中的矩形绘制**

在 `CaptureSessionService` 的 render annotations 方法中，将：

```swift
case let .rectangle(rect):
    context.setStrokeColor(CaptureAnnotation.strokeColor)
    context.setLineWidth(CaptureAnnotation.lineWidth)
    context.stroke(rect.standardized)
```
改为：

```swift
case let .rectangle(rect, props):
    let standardizedRect = rect.standardized
    let color = props.color.toNSColor().withAlphaComponent(props.opacity).cgColor

    if props.cornerRadius > 0 {
        let path = CGPath(roundedRect: standardizedRect,
                          cornerWidth: props.cornerRadius,
                          cornerHeight: props.cornerRadius, transform: nil)
        context.addPath(path)
    } else {
        context.addRect(standardizedRect)
    }

    if props.isFilled {
        context.setFillColor(color)
        context.fillPath()
    } else {
        context.setStrokeColor(color)
        context.setLineWidth(props.lineWidth)
        context.strokePath()
    }
```

- [ ] **Step 2: 运行构建验证**

Run:
```bash
./scripts/build.sh
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: 提交**

Run:
```bash
git add TYScreenShotTool/Services/CaptureSessionService.swift
git commit -m "feat(sprint-41): 导出渲染读取矩形属性参数"
```

---

### Task 8: 最终验证与收尾

**Files:**
- Modify: `TASK.md`（更新到 Sprint 41 状态）
- Create: `docs/SPRINTS/Sprint-41.md`
- Modify: `docs/DEVLOG.md`

- [ ] **Step 1: 运行最终构建验证**

Run:
```bash
./scripts/build.sh
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 2: 执行人工验证**

人工验证清单：

1. 点击矩形工具按钮，属性面板在工具栏下方显示，两排布局规整，值显示为默认（粗细=3px，透明度=100%，圆角=0px，空心，红色）
2. 面板中调整粗细下拉选（切换到 5px），透明度滑块（到 80%），圆角滑块（到 10px），切换到实心，选择蓝色
3. 在画布上画一个新矩形，渲染效果为：蓝色实心、5px 线宽、80% 透明度、10px 圆角
4. 再画一个矩形，使用同样的面板值
5. 在画布上点击已画好的矩形 → 青色虚线高亮边框出现，面板同步显示该矩形的属性值
6. 在面板中调整粗细/透明度/圆角/颜色/实心空心 → 选中矩形实时更新
7. 点击其他工具（椭圆/箭头）→ 面板隐藏，矩形高亮消失
8. 再次点击矩形工具 → 面板重新显示，显示当前 currentRectangleProperties 值
9. 点击空白区域（非矩形区域）→ 无选中，面板保持显示
10. 新建矩形（先用实心蓝画一个，切回空心红画第二个）→ 各自独立属性，点击切换选中正常
11. 原有椭圆/箭头/画笔/马赛克/文字工具不受影响，可正常绘制
12. 导出保存的图片中矩形正确渲染了属性（颜色、粗细、圆角等）
13. OCR / AI / Pin / 复制 / 保存 / 取消功能正常

- [ ] **Step 3: 创建 Sprint 文档**

创建 `docs/SPRINTS/Sprint-41.md`：

```md
# Sprint 41 - 矩形属性面板

## Status

Done

## Goal

为矩形工具新增属性面板，支持调整粗细、透明度、圆角、实心/空心、颜色。
点击已画矩形可选中并调整属性，面板值作为新矩形默认值。

## Scope

- 新增 RGBColor/RectangleProperties 数据模型
- 新增 RectanglePropertyPanelView 面板视图（两排布局）
- 画布选中交互（点击选中 + 青色虚线高亮）
- 基于属性的矩形渲染（圆角/实心空心/透明度）
- 导出导出时矩形样式正确渲染

## Verification

1. 点击矩形 → 面板在工具栏下方显示
2. 面板调整属性 → 新矩形使用面板值
3. 点击已画矩形 → 高亮选中 + 面板同步
4. 面板调整 → 选中矩形实时更新
5. 切换工具 → 面板隐藏
6. 其他工具不受影响
7. 构建通过

## Result

实现完成，人工验证通过。
```

- [ ] **Step 4: 更新 TASK.md 和 DEVLOG.md**

将 `TASK.md` 更新为 Sprint 41 已完成状态。
在 `docs/DEVLOG.md` 追加 Sprint 41 完成记录。

- [ ] **Step 5: 检查 Git 状态并提交收尾**

Run:
```bash
git status --short
git diff --cached --stat
```
Expected: 只包含 Sprint 41 本轮相关文件。

Run:
```bash
git add docs/SPRINTS/Sprint-41.md docs/DEVLOG.md TASK.md
git commit -m "feat(sprint-41): 补齐矩形属性面板迭代文档"
```

---

## Self-Review

### 1. Spec coverage

- 数据模型（RGBColor + RectangleProperties）：Task 1 + Task 2
- CaptureAnnotation.rectangle 增加属性参数：Task 3
- 选中交互（点击检测、高亮、实时更新）：Task 4
- 基于属性的渲染（圆角、实心空心、透明度）：Task 4
- 面板 UI（两排布局、NSPopUpButton/NSSlider/NSSegmentedControl/颜色圆点）：Task 5
- 面板生命周期（显示/隐藏、回调连接）：Task 6
- 默认值传递（面板值→新矩形）：Task 4 Step 5 + Task 6 Step 5
- 导出渲染正确使用 RectangleProperties：Task 7
- 验证与收尾：Task 8

### 2. Placeholder scan

- 所有步骤包含具体代码或具体命令
- 无 `TODO` / `待定` / `类似 Task N` 占位符
- 所有文件路径精确

### 3. Type consistency

- `RectangleProperties` 字段与设计文档一致（lineWidth/opacity/cornerRadius/isFilled/color）
- `RGBColor` 预设 8 色与设计文档一致
- `CaptureAnnotation.rectangle(CGRect, RectangleProperties)` 命名一致
- `selectedAnnotationIndex` / `onAnnotationSelected` 在 canvas 与 overlay 之间一致
- `updateSelectedAnnotation(with:)` 方法名在 canvas 和 overlay 间匹配
