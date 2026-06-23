# Sprint 44 - 标注工具属性面板扩展 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为普通截图编辑态补齐圆形、直线、箭头、画笔、马赛克的属性面板与属性回显链路，并新增直线工具按钮。

**Architecture:** 保留现有 `CaptureOverlayView + CaptureAnnotationCanvasView` 的 AppKit 结构，在 Shared 层为不同标注工具增加明确的属性模型，在 Overlay 层新增独立属性面板，在 Canvas 层扩展 annotation 数据、渲染和选中回显。属性面板继续使用 AppKit，布局统一使用 SnapKit，不在本轮强行把截图编辑态局部切到 SwiftUI。

**Tech Stack:** Swift 6、AppKit、SnapKit 6.0.0、现有 `CaptureOverlayView` / `CaptureAnnotationCanvasView` / `CaptureAnnotation` / `AppText`、项目构建脚本 `./scripts/build.sh`。

---

## 规划说明

本计划基于设计文档 [2026-06-22-sprint-44-annotation-property-panels-design.md](/Users/sheldon/CodeRepo/TYScreenShotTool/docs/superpowers/specs/2026-06-22-sprint-44-annotation-property-panels-design.md)。

当前关键文件：

- `TYScreenShotTool/Shared/AnnotationTool.swift`：标注工具定义，目前没有 `line`
- `TYScreenShotTool/Shared/CaptureAnnotation.swift`：除矩形外其他标注仍未携带样式属性
- `TYScreenShotTool/Shared/RectangleProperties.swift`：矩形属性的现有样板
- `TYScreenShotTool/Shared/RGBColor.swift`：颜色值模型与预设色板
- `TYScreenShotTool/Shared/AppText.swift`：工具名与属性面板文案来源
- `TYScreenShotTool/Features/CaptureOverlay/RectanglePropertyPanelView.swift`：现有矩形属性面板样板，本轮需要一并迁到内容驱动尺寸策略
- `TYScreenShotTool/Features/CaptureOverlay/CaptureOverlayView.swift`：工具栏、属性面板显隐与定位
- `TYScreenShotTool/Features/CaptureOverlay/CaptureAnnotationCanvasView.swift`：绘制、选中、命中检测与渲染

需要创建的文件：

- `TYScreenShotTool/Shared/ShapeStrokeProperties.swift`
- `TYScreenShotTool/Shared/ArrowProperties.swift`
- `TYScreenShotTool/Shared/PenProperties.swift`
- `TYScreenShotTool/Shared/MosaicProperties.swift`
- `TYScreenShotTool/Shared/AnnotationEditableProperties.swift`
- `TYScreenShotTool/Features/CaptureOverlay/StrokePropertyPanelView.swift`
- `TYScreenShotTool/Features/CaptureOverlay/ArrowPropertyPanelView.swift`
- `TYScreenShotTool/Features/CaptureOverlay/PenPropertyPanelView.swift`
- `TYScreenShotTool/Features/CaptureOverlay/MosaicPropertyPanelView.swift`
- `docs/SPRINTS/Sprint-44.md`

需要修改的文件：

- `TYScreenShotTool/Shared/AnnotationTool.swift`
- `TYScreenShotTool/Shared/CaptureAnnotation.swift`
- `TYScreenShotTool/Shared/AppText.swift`
- `TYScreenShotTool/Features/CaptureOverlay/RectanglePropertyPanelView.swift`
- `TYScreenShotTool/Features/CaptureOverlay/CaptureAnnotationCanvasView.swift`
- `TYScreenShotTool/Features/CaptureOverlay/CaptureOverlayView.swift`
- `docs/ROADMAP.md`
- `docs/DEVLOG.md`

本仓库当前没有现成测试 target，本计划以“小步修改 -> 构建验证 -> 人工验证”为主，不额外引入测试基础设施。

执行约束：

- 允许单个任务内部先产生临时编译错误
- 但 **每个任务提交前必须恢复到 `./scripts/build.sh` 构建通过**
- 不提交长期不可构建状态

---

### Task 1：补齐 Shared 层工具、属性模型和属性文案

**Files:**
- Create: `TYScreenShotTool/Shared/ShapeStrokeProperties.swift`
- Create: `TYScreenShotTool/Shared/ArrowProperties.swift`
- Create: `TYScreenShotTool/Shared/PenProperties.swift`
- Create: `TYScreenShotTool/Shared/MosaicProperties.swift`
- Create: `TYScreenShotTool/Shared/AnnotationEditableProperties.swift`
- Modify: `TYScreenShotTool/Shared/AnnotationTool.swift`
- Modify: `TYScreenShotTool/Shared/AppText.swift`

- [ ] **Step 1: 为工具栏补齐 `line` 工具和标题文案**

在 `TYScreenShotTool/Shared/AnnotationTool.swift` 中将枚举顺序改为：

```swift
enum AnnotationTool: CaseIterable, Equatable {
    case rectangle
    case ellipse
    case line
    case arrow
    case pen
    case mosaic
    case text
}
```

同步补齐 `rawIdentifier` / `title` / `symbolName`：

```swift
        case .line:
            return "line"
```

```swift
        case .line:
            return AppText.annotationLine
```

```swift
        case .line:
            return "line.diagonal"
```

在 `TYScreenShotTool/Shared/AppText.swift` 中添加：

```swift
    static var annotationLine: String {
        choose(zhHans: "线条", en: "Line", ja: "線", ko: "선", de: "Linie", fr: "Ligne")
    }
```

- [ ] **Step 2: 新增圆形/直线共用描边属性**

创建 `TYScreenShotTool/Shared/ShapeStrokeProperties.swift`：

```swift
import Foundation

struct ShapeStrokeProperties: Equatable {
    var lineWidth: CGFloat
    var opacity: CGFloat
    var color: RGBColor

    static let `default` = ShapeStrokeProperties(
        lineWidth: 3,
        opacity: 1.0,
        color: RGBColor(red: 0.93, green: 0.24, blue: 0.21)
    )
}
```

- [ ] **Step 3: 新增箭头属性**

创建 `TYScreenShotTool/Shared/ArrowProperties.swift`：

```swift
import Foundation

struct ArrowProperties: Equatable {
    var lineWidth: CGFloat
    var opacity: CGFloat
    var color: RGBColor
    var isCurved: Bool

    static let `default` = ArrowProperties(
        lineWidth: 4,
        opacity: 1.0,
        color: RGBColor(red: 0.0, green: 0.48, blue: 1.0),
        isCurved: false
    )
}
```

- [ ] **Step 4: 新增画笔模式与属性**

创建 `TYScreenShotTool/Shared/PenProperties.swift`：

```swift
import Foundation

enum PenMode: String, CaseIterable, Equatable {
    case singleColor
    case gaussianBlur
    case mosaic
}

struct PenProperties: Equatable {
    var lineWidth: CGFloat
    var opacity: CGFloat
    var color: RGBColor
    var mode: PenMode

    static let `default` = PenProperties(
        lineWidth: 16,
        opacity: 1.0,
        color: RGBColor(red: 0.93, green: 0.24, blue: 0.21),
        mode: .singleColor
    )
}
```

- [ ] **Step 5: 新增矩形马赛克样式与属性**

创建 `TYScreenShotTool/Shared/MosaicProperties.swift`：

```swift
import Foundation

enum MosaicStyle: String, CaseIterable, Equatable {
    case mosaic
    case glass
}

struct MosaicProperties: Equatable {
    var size: CGFloat
    var style: MosaicStyle

    static let `default` = MosaicProperties(
        size: 2,
        style: .glass
    )
}
```

- [ ] **Step 6: 新增通用选中回显载体**

创建 `TYScreenShotTool/Shared/AnnotationEditableProperties.swift`：

```swift
import Foundation

enum AnnotationEditableProperties: Equatable {
    case rectangle(RectangleProperties)
    case ellipse(ShapeStrokeProperties)
    case line(ShapeStrokeProperties)
    case arrow(ArrowProperties)
    case pen(PenProperties)
    case mosaic(MosaicProperties)
}
```

- [ ] **Step 7: 在 `AppText` 中补齐画笔/马赛克/通用属性文案**

在 `TYScreenShotTool/Shared/AppText.swift` 中加入：

```swift
    static var penModeSingleColor: String { choose(zhHans: "单一颜色", en: "Single Color", ja: "単色", ko: "단색", de: "Einfarbig", fr: "Couleur unie") }
    static var penModeGaussianBlur: String { choose(zhHans: "高斯模糊", en: "Gaussian Blur", ja: "ガウスぼかし", ko: "가우시안 블러", de: "Gaußsche Unschärfe", fr: "Flou gaussien") }
    static var penModeMosaic: String { choose(zhHans: "马赛克", en: "Mosaic", ja: "モザイク", ko: "모자이크", de: "Mosaik", fr: "Mosaïque") }
    static var mosaicStyleMosaic: String { choose(zhHans: "马赛克", en: "Mosaic", ja: "モザイク", ko: "모자이크", de: "Mosaik", fr: "Mosaïque") }
    static var mosaicStyleGlass: String { choose(zhHans: "毛玻璃", en: "Glass", ja: "すりガラス", ko: "반투명 유리", de: "Milchglas", fr: "Verre dépoli") }
    static var annotationPanelLineWidth: String { choose(zhHans: "大小", en: "Size", ja: "サイズ", ko: "크기", de: "Größe", fr: "Taille") }
    static var annotationPanelOpacity: String { choose(zhHans: "不透明度", en: "Opacity", ja: "不透明度", ko: "불투명도", de: "Deckkraft", fr: "Opacité") }
    static var annotationPanelColor: String { choose(zhHans: "颜色", en: "Color", ja: "色", ko: "색상", de: "Farbe", fr: "Couleur") }
    static var annotationPanelCurvedArrow: String { choose(zhHans: "曲线箭头", en: "Curved Arrow", ja: "曲線矢印", ko: "곡선 화살표", de: "Gebogener Pfeil", fr: "Flèche courbe") }
```

- [ ] **Step 8: 为 `.line` 补齐最小 `switch currentTool` 编译分支**

因为 Task 1 已经把 `AnnotationTool` 扩成包含 `.line`，所以要在 `TYScreenShotTool/Features/CaptureOverlay/CaptureAnnotationCanvasView.swift` 里先补最小分支，避免现有 `switch currentTool` 立即变成“不穷尽 switch”。

在 `mouseDown(with:)` 中把：

```swift
        case .ellipse, .arrow:
```

先最小改成：

```swift
        case .ellipse, .line, .arrow:
```

在 `mouseDragged(with:)` 中把：

```swift
        case .rectangle, .ellipse, .arrow:
```

先最小改成：

```swift
        case .rectangle, .ellipse, .line, .arrow:
```

在 `mouseUp(with:)` 中把：

```swift
        case .rectangle, .ellipse, .arrow:
```

先最小改成：

```swift
        case .rectangle, .ellipse, .line, .arrow:
```

在 `makeDragAnnotation(from:to:)` 中把：

```swift
        case .ellipse:
            return .ellipse(normalizedRect(from: start, to: end))
        case .arrow:
            return .arrow(start: start, end: end)
```

先最小改成：

```swift
        case .ellipse:
            return .ellipse(normalizedRect(from: start, to: end))
        case .line:
            return .arrow(start: start, end: end)
        case .arrow:
            return .arrow(start: start, end: end)
```

说明：

- 这里只做 Task 1 所需的最小编译补洞
- `line` 的真实数据结构、真实渲染和真实属性接线仍以后续 Task 2 / Task 4 / Task 5 / Task 6 为准
- 这里临时把 `.line` 复用到现有箭头拖拽路径，只是为了让 Task 1 末尾 build 通过

- [ ] **Step 9: 构建确认 Shared 层新增类型已经进入 target**

运行：

```bash
./scripts/build.sh
```

预期：

```text
** BUILD SUCCEEDED **
```

- [ ] **Step 10: 提交**

```bash
git add TYScreenShotTool/Shared/AnnotationTool.swift \
  TYScreenShotTool/Shared/AppText.swift \
  TYScreenShotTool/Shared/ShapeStrokeProperties.swift \
  TYScreenShotTool/Shared/ArrowProperties.swift \
  TYScreenShotTool/Shared/PenProperties.swift \
  TYScreenShotTool/Shared/MosaicProperties.swift \
  TYScreenShotTool/Shared/AnnotationEditableProperties.swift \
  TYScreenShotTool/Features/CaptureOverlay/CaptureAnnotationCanvasView.swift
git commit -m "feat(sprint-44): 新增标注工具属性模型"
```

---

### Task 2：扩展 `CaptureAnnotation` 数据结构，并同步最小调用点以保持可构建

**Files:**
- Modify: `TYScreenShotTool/Shared/CaptureAnnotation.swift`
- Modify: `TYScreenShotTool/Features/CaptureOverlay/CaptureAnnotationCanvasView.swift`

- [ ] **Step 1: 将 `CaptureAnnotation` 扩展为样式随标注存储**

在 `TYScreenShotTool/Shared/CaptureAnnotation.swift` 中改为：

```swift
enum CaptureAnnotation: Equatable {
    case rectangle(CGRect, RectangleProperties)
    case ellipse(CGRect, ShapeStrokeProperties)
    case line(start: CGPoint, end: CGPoint, ShapeStrokeProperties)
    case arrow(start: CGPoint, end: CGPoint, ArrowProperties)
    case pen(points: [CGPoint], PenProperties)
    case mosaic(CGRect, MosaicProperties)
    case text(value: String, origin: CGPoint)
}
```

保留：

```swift
    static let fontSize: CGFloat = 22
    static let mosaicBlurRadius: CGFloat = 18
    static let mosaicOverlayAlpha: CGFloat = 0.10
    static let mosaicCornerRadius: CGFloat = 6
```

- [ ] **Step 2: 更新 `bounds` 计算**

把 `bounds` 中相关 case 改为：

```swift
        case let .ellipse(rect, _):
            return rect.standardized
        case let .line(start, end, props):
            let inset = max(8, props.lineWidth + 4)
            return CGRect(
                x: min(start.x, end.x),
                y: min(start.y, end.y),
                width: abs(end.x - start.x),
                height: abs(end.y - start.y)
            ).insetBy(dx: -inset, dy: -inset)
        case let .arrow(start, end, props):
            let inset = max(12, props.lineWidth + 8)
            return CGRect(
                x: min(start.x, end.x),
                y: min(start.y, end.y),
                width: abs(end.x - start.x),
                height: abs(end.y - start.y)
            ).insetBy(dx: -inset, dy: -inset)
        case let .pen(points, props):
            guard let first = points.first else { return .zero }
            let inset = max(6, props.lineWidth / 2 + 4)
            return points.dropFirst().reduce(
                CGRect(origin: first, size: .zero).insetBy(dx: -inset, dy: -inset)
            ) { partial, point in
                partial.union(CGRect(origin: point, size: .zero).insetBy(dx: -inset, dy: -inset))
            }
        case let .mosaic(rect, _):
            return rect.standardized
```

- [ ] **Step 3: 在 `CaptureAnnotationCanvasView` 里先把旧 case 签名改到新形式，保持旧行为**

只做“签名对齐 + 最小编译修复”，不要提前引入新效果。除 `draw(annotation:at:)` 外，还要同步补齐所有因枚举签名变化而立刻报错的旧构造与旧匹配：

```swift
        case .mosaic:
            if beginMosaicInteraction(at: point) {
                needsDisplay = true
                applyCursorForCurrentState()
                return
            }

            dragStartPoint = point
            currentPoint = point
            temporaryAnnotation = .mosaic(normalizedRect(from: point, to: point), MosaicProperties.default)
            needsDisplay = true
```

```swift
        case .pen:
            dragStartPoint = point
            currentPoint = point
            temporaryAnnotation = .pen(points: [point], PenProperties.default)
            needsDisplay = true
```

```swift
        case .mosaic:
            guard let dragStartPoint else {
                return
            }

            currentPoint = point
            temporaryAnnotation = .mosaic(normalizedRect(from: dragStartPoint, to: point), MosaicProperties.default)
            needsDisplay = true
```

```swift
        case .pen:
            guard case let .pen(points, properties) = temporaryAnnotation else {
                return
            }

            currentPoint = point
            temporaryAnnotation = .pen(points: points + [point], properties)
            needsDisplay = true
```

```swift
        guard case let .pen(points, properties) = temporaryAnnotation, points.count > 1 else {
            return
        }

        annotations.append(.pen(points: points, properties))
```

```swift
        case let .ellipse(rect, _):
            guard rect.standardized.width > 4, rect.standardized.height > 4 else {
                return
            }
        case let .mosaic(rect, _):
            guard rect.standardized.width > 4, rect.standardized.height > 4 else {
                return
            }
        case let .arrow(start, end, _):
            guard hypot(end.x - start.x, end.y - start.y) > 8 else {
                return
            }
```

旧矩形专用更新入口在本任务末尾保留一个兼容 shim，直到 Task 4 再统一切换：

```swift
    func updateSelectedAnnotation(with properties: RectangleProperties) {
        guard let idx = selectedAnnotationIndex,
              annotations.indices.contains(idx),
              case .rectangle(let rect, _) = annotations[idx] else { return }
        annotations[idx] = .rectangle(rect, properties)
        needsDisplay = true
    }
```

这样 Task 2 的 `./scripts/build.sh` 才具备通过条件。

同时把 `makeDragAnnotation(from:to:)` 也前移做最小编译修复，避免仍然保留旧枚举构造：

```swift
    private func makeDragAnnotation(from start: CGPoint, to end: CGPoint) -> CaptureAnnotation? {
        switch currentTool {
        case .rectangle:
            return .rectangle(normalizedRect(from: start, to: end), currentRectangleProperties)
        case .ellipse:
            return .ellipse(normalizedRect(from: start, to: end), ShapeStrokeProperties.default)
        case .arrow:
            return .arrow(start: start, end: end, ArrowProperties.default)
        case .mosaic:
            return .mosaic(normalizedRect(from: start, to: end), MosaicProperties.default)
        case .line:
            return .line(start: start, end: end, ShapeStrokeProperties.default)
        case .pen, .text, .none:
            return nil
        }
    }
```

注意：这里先用默认属性占位，只为保证 Task 2 可编译；`currentEllipseProperties / currentArrowProperties / currentMosaicProperties / currentLineProperties` 的真正接入，仍在 Task 4 和 Task 5 完成。

`draw(annotation:at:)` 中的最小签名对齐片段保留为：

```swift
        case let .ellipse(rect, _):
            let path = NSBezierPath(ovalIn: rect.standardized)
            configureStroke()
            path.lineWidth = 3
            path.stroke()
```

```swift
        case let .arrow(start, end, _):
            let path = arrowPath(from: start, to: end)
            configureStroke()
            path.stroke()
```

```swift
        case let .pen(points, _):
            guard let first = points.first else { return }
            let path = NSBezierPath()
            path.move(to: first)
            for point in points.dropFirst() {
                path.line(to: point)
            }
            configureStroke()
            path.stroke()
```

```swift
        case let .mosaic(rect, _):
            drawMosaic(in: rect.standardized)
```

- [ ] **Step 4: 构建确认 Task 1 + Task 2 合并后工程可构建**

运行：

```bash
./scripts/build.sh
```

预期：

```text
** BUILD SUCCEEDED **
```

- [ ] **Step 5: 提交 Task 1 + Task 2 的合并结果**

```bash
git add TYScreenShotTool/Shared/AnnotationTool.swift \
  TYScreenShotTool/Shared/AppText.swift \
  TYScreenShotTool/Shared/ShapeStrokeProperties.swift \
  TYScreenShotTool/Shared/ArrowProperties.swift \
  TYScreenShotTool/Shared/PenProperties.swift \
  TYScreenShotTool/Shared/MosaicProperties.swift \
  TYScreenShotTool/Shared/AnnotationEditableProperties.swift \
  TYScreenShotTool/Shared/CaptureAnnotation.swift \
  TYScreenShotTool/Features/CaptureOverlay/CaptureAnnotationCanvasView.swift
git commit -m "refactor(sprint-44): 扩展标注模型与基础兼容层"
```

---

### Task 3：新增 4 个属性面板视图，并补齐完整 `updateDisplay` 行为

**Files:**
- Modify: `TYScreenShotTool/Features/CaptureOverlay/RectanglePropertyPanelView.swift`
- Create: `TYScreenShotTool/Features/CaptureOverlay/StrokePropertyPanelView.swift`
- Create: `TYScreenShotTool/Features/CaptureOverlay/ArrowPropertyPanelView.swift`
- Create: `TYScreenShotTool/Features/CaptureOverlay/PenPropertyPanelView.swift`
- Create: `TYScreenShotTool/Features/CaptureOverlay/MosaicPropertyPanelView.swift`

- [ ] **Step 1: 先把矩形面板迁到统一尺寸策略**

在 `TYScreenShotTool/Features/CaptureOverlay/RectanglePropertyPanelView.swift` 中将：

```swift
import SnapKit

    static let preferredSize = CGSize(width: 320, height: 100)
```

改为：

```swift
    static let minimumPanelSize = CGSize(width: 320, height: 100)
    static let maximumPanelWidth: CGFloat = 380
```

并补充约束要求：

- 保留当前矩形面板已有交互与视觉样式
- 将后续布局语义统一为“内容决定实际尺寸，外层只做 min/max 钳制”
- 不再让 `CaptureOverlayView` 依赖矩形面板的固定 `preferredSize`
- 本轮同步把 `setupLayout()` 里的 `NSLayoutConstraint.activate(...)` 迁为 SnapKit

将容器约束从：

```swift
        NSLayoutConstraint.activate([
            contentContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            contentContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            contentContainer.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            contentContainer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
```

改为：

```swift
        contentContainer.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(14)
            make.trailing.equalToSuperview().inset(14)
            make.top.equalToSuperview().offset(14)
            make.bottom.equalToSuperview().inset(12)
        }
```

将左右列主约束从：

```swift
        NSLayoutConstraint.activate([
            leftColumnStack.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            leftColumnStack.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            leftColumnStack.bottomAnchor.constraint(lessThanOrEqualTo: contentContainer.bottomAnchor),

            rightColumnStack.leadingAnchor.constraint(equalTo: leftColumnStack.trailingAnchor, constant: 4),
            rightColumnStack.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            rightColumnStack.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            rightColumnStack.bottomAnchor.constraint(lessThanOrEqualTo: contentContainer.bottomAnchor),

            leftColumnStack.widthAnchor.constraint(equalToConstant: 130)
        ])
```

改为：

```swift
        leftColumnStack.snp.makeConstraints { make in
            make.leading.top.equalToSuperview()
            make.bottom.lessThanOrEqualToSuperview()
            make.width.equalTo(130)
        }

        rightColumnStack.snp.makeConstraints { make in
            make.leading.equalTo(leftColumnStack.snp.trailing).offset(4)
            make.trailing.top.equalToSuperview()
            make.bottom.lessThanOrEqualToSuperview()
        }
```

把 `makeLabeledRow(...)` 中：

```swift
        NSLayoutConstraint.activate([
            label.widthAnchor.constraint(equalToConstant: labelWidth),
            content.heightAnchor.constraint(greaterThanOrEqualToConstant: 8),
            row.heightAnchor.constraint(greaterThanOrEqualToConstant: 10)
        ])
```

改为：

```swift
        label.snp.makeConstraints { make in
            make.width.equalTo(labelWidth)
        }
        content.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(8)
        }
        row.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(10)
        }
```

把 `makeSliderRow(...)` 中：

```swift
        NSLayoutConstraint.activate([
            label.widthAnchor.constraint(equalToConstant: 44),
            valueLabel.widthAnchor.constraint(equalToConstant: 36),
            slider.heightAnchor.constraint(equalToConstant: 20),
            row.heightAnchor.constraint(equalToConstant: 24)
        ])
```

改为：

```swift
        label.snp.makeConstraints { make in
            make.width.equalTo(44)
        }
        valueLabel.snp.makeConstraints { make in
            make.width.equalTo(36)
        }
        slider.snp.makeConstraints { make in
            make.height.equalTo(20)
        }
        row.snp.makeConstraints { make in
            make.height.equalTo(24)
        }
```

把 `makeColorSection()` 中容器 / 网格主约束：

```swift
        NSLayoutConstraint.activate([
            colorTitleLabel.widthAnchor.constraint(equalToConstant: 22),

            colorTitleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            colorTitleLabel.topAnchor.constraint(equalTo: container.topAnchor),

            colorGrid.leadingAnchor.constraint(equalTo: colorTitleLabel.trailingAnchor, constant: 10),
            colorGrid.topAnchor.constraint(equalTo: colorTitleLabel.topAnchor, constant: -3),
            colorGrid.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
```

改为：

```swift
        colorTitleLabel.snp.makeConstraints { make in
            make.width.equalTo(22)
            make.leading.top.equalToSuperview()
        }

        colorGrid.snp.makeConstraints { make in
            make.leading.equalTo(colorTitleLabel.snp.trailing).offset(10)
            make.top.equalTo(colorTitleLabel.snp.top).offset(-3)
            make.bottom.equalToSuperview()
        }
```

把颜色按钮尺寸约束：

```swift
        for button in colorButtons {
            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalToConstant: 18),
                button.heightAnchor.constraint(equalToConstant: 18)
            ])
        }
```

改为：

```swift
        for button in colorButtons {
            button.snp.makeConstraints { make in
                make.width.height.equalTo(18)
            }
        }
```

到这里为止，[RectanglePropertyPanelView.swift](/Users/sheldon/CodeRepo/TYScreenShotTool/TYScreenShotTool/Features/CaptureOverlay/RectanglePropertyPanelView.swift) 中当前所有 `NSLayoutConstraint.activate(...)` 都应迁完，不再保留“其余同理”的开放式步骤。

- [ ] **Step 2: 新增圆形/直线共用描边面板**

创建 `TYScreenShotTool/Features/CaptureOverlay/StrokePropertyPanelView.swift`：

```swift
final class StrokePropertyPanelView: NSVisualEffectView {
    static let minimumPanelSize = CGSize(width: 250, height: 86)
    static let maximumPanelWidth: CGFloat = 320
    var onPropertyChanged: ((ShapeStrokeProperties) -> Void)?

    private var isUpdatingDisplay = false
    private var currentProperties = ShapeStrokeProperties.default {
        didSet {
            guard !isUpdatingDisplay else { return }
            onPropertyChanged?(currentProperties)
        }
    }

    private let lineWidthSlider = NSSlider()
    private let opacitySlider = NSSlider()
    private var colorButtons: [NSButton] = []

    func updateDisplay(with properties: ShapeStrokeProperties) {
        isUpdatingDisplay = true
        currentProperties = properties
        lineWidthSlider.doubleValue = properties.lineWidth
        opacitySlider.doubleValue = properties.opacity * 100
        updateColorSelection(color: properties.color)
        isUpdatingDisplay = false
    }
}
```

- [ ] **Step 3: 新增箭头属性面板**

创建 `TYScreenShotTool/Features/CaptureOverlay/ArrowPropertyPanelView.swift`：

```swift
final class ArrowPropertyPanelView: NSVisualEffectView {
    static let minimumPanelSize = CGSize(width: 300, height: 86)
    static let maximumPanelWidth: CGFloat = 360
    var onPropertyChanged: ((ArrowProperties) -> Void)?

    private var isUpdatingDisplay = false
    private var currentProperties = ArrowProperties.default {
        didSet {
            guard !isUpdatingDisplay else { return }
            onPropertyChanged?(currentProperties)
        }
    }

    private let lineWidthSlider = NSSlider()
    private let opacitySlider = NSSlider()
    private let curvedArrowCheckbox = NSButton(
        checkboxWithTitle: AppText.annotationPanelCurvedArrow,
        target: nil,
        action: nil
    )
    private var colorButtons: [NSButton] = []

    func updateDisplay(with properties: ArrowProperties) {
        isUpdatingDisplay = true
        currentProperties = properties
        lineWidthSlider.doubleValue = properties.lineWidth
        opacitySlider.doubleValue = properties.opacity * 100
        curvedArrowCheckbox.state = properties.isCurved ? .on : .off
        updateColorSelection(color: properties.color)
        isUpdatingDisplay = false
    }
}
```

- [ ] **Step 4: 新增画笔属性面板**

创建 `TYScreenShotTool/Features/CaptureOverlay/PenPropertyPanelView.swift`：

```swift
final class PenPropertyPanelView: NSVisualEffectView {
    static let minimumPanelSize = CGSize(width: 320, height: 86)
    static let maximumPanelWidth: CGFloat = 420
    var onPropertyChanged: ((PenProperties) -> Void)?

    private var isUpdatingDisplay = false
    private var currentProperties = PenProperties.default {
        didSet {
            guard !isUpdatingDisplay else { return }
            onPropertyChanged?(currentProperties)
        }
    }

    private let lineWidthSlider = NSSlider()
    private let opacitySlider = NSSlider()
    private let modePopUp = NSPopUpButton()
    private var colorButtons: [NSButton] = []

    func updateDisplay(with properties: PenProperties) {
        isUpdatingDisplay = true
        currentProperties = properties
        lineWidthSlider.doubleValue = properties.lineWidth
        opacitySlider.doubleValue = properties.opacity * 100
        modePopUp.selectItem(at: index(for: properties.mode))
        updateColorSelection(color: properties.color)
        isUpdatingDisplay = false
    }

    private func index(for mode: PenMode) -> Int {
        switch mode {
        case .singleColor: return 0
        case .gaussianBlur: return 1
        case .mosaic: return 2
        }
    }
}
```

- [ ] **Step 5: 新增马赛克属性面板**

创建 `TYScreenShotTool/Features/CaptureOverlay/MosaicPropertyPanelView.swift`：

```swift
final class MosaicPropertyPanelView: NSVisualEffectView {
    static let minimumPanelSize = CGSize(width: 220, height: 88)
    static let maximumPanelWidth: CGFloat = 300
    var onPropertyChanged: ((MosaicProperties) -> Void)?

    private var isUpdatingDisplay = false
    private var currentProperties = MosaicProperties.default {
        didSet {
            guard !isUpdatingDisplay else { return }
            onPropertyChanged?(currentProperties)
        }
    }

    private let sizeSlider = NSSlider()
    private let disabledOpacitySlider = NSSlider(value: 100, minValue: 0, maxValue: 100, target: nil, action: nil)
    private let mosaicRadio = NSButton(radioButtonWithTitle: AppText.mosaicStyleMosaic, target: nil, action: nil)
    private let glassRadio = NSButton(radioButtonWithTitle: AppText.mosaicStyleGlass, target: nil, action: nil)

    func updateDisplay(with properties: MosaicProperties) {
        isUpdatingDisplay = true
        currentProperties = properties
        sizeSlider.doubleValue = properties.size
        mosaicRadio.state = properties.style == .mosaic ? .on : .off
        glassRadio.state = properties.style == .glass ? .on : .off
        isUpdatingDisplay = false
    }
}
```

同时设置：

```swift
disabledOpacitySlider.isEnabled = false
```

- [ ] **Step 6: 明确内容驱动尺寸约束**

实现要求补充：

- 面板内部使用 SnapKit 约束内容，依赖 `fittingSize` 形成实际尺寸
- 不写死最终 `frame.width` / `frame.height`
- 仅允许通过内部约束表达最小高度、最小宽度和最大宽度
- 当本地化文本变长时，面板优先自然扩宽，超过最大宽度后再通过控件压缩策略兜底

- [ ] **Step 7: 构建确认矩形面板迁移与 4 个新面板文件可编译**

运行：

```bash
./scripts/build.sh
```

预期：

```text
** BUILD SUCCEEDED **
```

- [ ] **Step 8: 提交**

```bash
git add TYScreenShotTool/Features/CaptureOverlay/RectanglePropertyPanelView.swift \
  TYScreenShotTool/Features/CaptureOverlay/StrokePropertyPanelView.swift \
  TYScreenShotTool/Features/CaptureOverlay/ArrowPropertyPanelView.swift \
  TYScreenShotTool/Features/CaptureOverlay/PenPropertyPanelView.swift \
  TYScreenShotTool/Features/CaptureOverlay/MosaicPropertyPanelView.swift
git commit -m "feat(sprint-44): 新增标注工具属性面板"
```

---

### Task 4：在 `CaptureOverlayView` 中接入多面板、默认属性和回显分发

**Files:**
- Modify: `TYScreenShotTool/Features/CaptureOverlay/CaptureOverlayView.swift`
- Modify: `TYScreenShotTool/Features/CaptureOverlay/CaptureAnnotationCanvasView.swift`

- [ ] **Step 1: 前移 Overlay 依赖的最小 Canvas 接口，保证本任务末尾可构建**

先在 `TYScreenShotTool/Features/CaptureOverlay/CaptureAnnotationCanvasView.swift` 中补齐 Overlay 本任务会直接调用的最小接口集：

```swift
    var currentRectangleProperties = RectangleProperties.default
    var currentEllipseProperties = ShapeStrokeProperties.default
    var currentLineProperties = ShapeStrokeProperties.default
    var currentArrowProperties = ArrowProperties.default
    var currentPenProperties = PenProperties.default
    var currentMosaicProperties = MosaicProperties.default
```

```swift
    var onAnnotationSelected: ((Int?, AnnotationTool?, AnnotationEditableProperties?) -> Void)?
```

同时把当前仍然是旧两参数调用的最小回调发送点一并改掉，避免 Task 4 末尾构建失败：

```swift
            if let hitIndex = hitTestRectangle(at: point) {
                selectedAnnotationIndex = hitIndex
                if case .rectangle(_, let props) = annotations[hitIndex] {
                    onAnnotationSelected?(hitIndex, .rectangle, .rectangle(props))
                }
                needsDisplay = true
                return
            }

            selectedAnnotationIndex = nil
            onAnnotationSelected?(nil, currentTool, nil)
```

`undoLastAnnotation()` 里删除选中标注后的回调也要同步改成三参数：

```swift
        if let selectedIdx = selectedAnnotationIndex, !annotations.indices.contains(selectedIdx) {
            selectedAnnotationIndex = nil
            onAnnotationSelected?(nil, currentTool, nil)
        }
```

```swift
    func updateSelectedAnnotationProperties(_ properties: AnnotationEditableProperties) {
        guard let idx = selectedAnnotationIndex, annotations.indices.contains(idx) else { return }

        switch (annotations[idx], properties) {
        case let (.rectangle(rect, _), .rectangle(value)):
            annotations[idx] = .rectangle(rect, value)
        case let (.ellipse(rect, _), .ellipse(value)):
            annotations[idx] = .ellipse(rect, value)
        case let (.line(start, end, _), .line(value)):
            annotations[idx] = .line(start: start, end: end, value)
        case let (.arrow(start, end, _), .arrow(value)):
            annotations[idx] = .arrow(start: start, end: end, value)
        case let (.pen(points, _), .pen(value)):
            annotations[idx] = .pen(points: points, value)
        case let (.mosaic(rect, _), .mosaic(value)):
            annotations[idx] = .mosaic(rect, value)
        default:
            return
        }

        annotationsDidChange?(annotations)
        needsDisplay = true
    }
```

说明：

- 这一步只前移“让 Task 4 编译通过”所必需的接口
- 这里只前移矩形场景下最小的三参数回调适配
- `mouseDown` 通用命中分发、`line` 生命周期、`pen/mosaic` 选中回显仍放在 Task 5 完成

- [ ] **Step 2: 新增默认属性状态与面板实例**

在属性状态区补齐：

```swift
    private var currentRectangleProperties = RectangleProperties.default
    private var currentEllipseProperties = ShapeStrokeProperties.default
    private var currentLineProperties = ShapeStrokeProperties.default
    private var currentArrowProperties = ArrowProperties.default
    private var currentPenProperties = PenProperties.default
    private var currentMosaicProperties = MosaicProperties.default
```

在 view 成员区补齐：

```swift
    private let rectanglePanelView = RectanglePropertyPanelView()
    private let strokePanelView = StrokePropertyPanelView()
    private let arrowPanelView = ArrowPropertyPanelView()
    private let penPanelView = PenPropertyPanelView()
    private let mosaicPanelView = MosaicPropertyPanelView()
```

- [ ] **Step 3: 配置多面板回调，显式区分每种工具**

扩展 `configurePropertyPanel()`：

```swift
        rectanglePanelView.onPropertyChanged = { [weak self] properties in
            guard let self else { return }
            self.currentRectangleProperties = properties
            self.annotationCanvasView.currentRectangleProperties = properties
            self.annotationCanvasView.updateSelectedAnnotationProperties(.rectangle(properties))
        }
```

```swift
        strokePanelView.onPropertyChanged = { [weak self] properties in
            guard let self else { return }
            switch self.currentAnnotationTool {
            case .ellipse:
                self.currentEllipseProperties = properties
                self.annotationCanvasView.currentEllipseProperties = properties
                self.annotationCanvasView.updateSelectedAnnotationProperties(.ellipse(properties))
            case .line:
                self.currentLineProperties = properties
                self.annotationCanvasView.currentLineProperties = properties
                self.annotationCanvasView.updateSelectedAnnotationProperties(.line(properties))
            default:
                break
            }
        }
```

```swift
        arrowPanelView.onPropertyChanged = { [weak self] properties in
            guard let self else { return }
            self.currentArrowProperties = properties
            self.annotationCanvasView.currentArrowProperties = properties
            self.annotationCanvasView.updateSelectedAnnotationProperties(.arrow(properties))
        }
```

```swift
        penPanelView.onPropertyChanged = { [weak self] properties in
            guard let self else { return }
            self.currentPenProperties = properties
            self.annotationCanvasView.currentPenProperties = properties
            self.annotationCanvasView.updateSelectedAnnotationProperties(.pen(properties))
        }
```

```swift
        mosaicPanelView.onPropertyChanged = { [weak self] properties in
            guard let self else { return }
            self.currentMosaicProperties = properties
            self.annotationCanvasView.currentMosaicProperties = properties
            self.annotationCanvasView.updateSelectedAnnotationProperties(.mosaic(properties))
        }
```

- [ ] **Step 4: 把全部属性面板加入视图树并设置初始隐藏状态**

在 `configurePropertyPanel()` 末尾补齐：

```swift
        rectanglePanelView.isHidden = true
        strokePanelView.isHidden = true
        arrowPanelView.isHidden = true
        penPanelView.isHidden = true
        mosaicPanelView.isHidden = true

        addSubview(rectanglePanelView)
        addSubview(strokePanelView)
        addSubview(arrowPanelView)
        addSubview(penPanelView)
        addSubview(mosaicPanelView)
```

- [ ] **Step 5: 扩展选中回显闭包**

将 `annotationCanvasView.onAnnotationSelected` 改为：

```swift
        annotationCanvasView.onAnnotationSelected = { [weak self] index, tool, properties in
            guard let self else { return }
            self.annotationCanvasView.selectedAnnotationIndex = index

            if let tool {
                self.currentAnnotationTool = tool
                self.annotationCanvasView.currentTool = tool
            }

            self.applySelection(properties)
            self.updateVisiblePropertyPanel()
            self.updateAnnotationToolSelection()
        }
```

新增：

```swift
    private func applySelection(_ properties: AnnotationEditableProperties?) {
        switch properties {
        case let .rectangle(value):
            currentRectangleProperties = value
            annotationCanvasView.currentRectangleProperties = value
            rectanglePanelView.updateDisplay(with: value)
        case let .ellipse(value):
            currentEllipseProperties = value
            annotationCanvasView.currentEllipseProperties = value
            strokePanelView.updateDisplay(with: value)
        case let .line(value):
            currentLineProperties = value
            annotationCanvasView.currentLineProperties = value
            strokePanelView.updateDisplay(with: value)
        case let .arrow(value):
            currentArrowProperties = value
            annotationCanvasView.currentArrowProperties = value
            arrowPanelView.updateDisplay(with: value)
        case let .pen(value):
            currentPenProperties = value
            annotationCanvasView.currentPenProperties = value
            penPanelView.updateDisplay(with: value)
        case let .mosaic(value):
            currentMosaicProperties = value
            annotationCanvasView.currentMosaicProperties = value
            mosaicPanelView.updateDisplay(with: value)
        case nil:
            refreshCurrentToolPanelFromDefaults()
        }
    }
```

- [ ] **Step 6: 新增当前工具默认面板刷新 helper**

在 `CaptureOverlayView` 中新增：

```swift
    private func refreshCurrentToolPanelFromDefaults() {
        switch currentAnnotationTool {
        case .rectangle:
            annotationCanvasView.currentRectangleProperties = currentRectangleProperties
            rectanglePanelView.updateDisplay(with: currentRectangleProperties)
        case .ellipse:
            annotationCanvasView.currentEllipseProperties = currentEllipseProperties
            strokePanelView.updateDisplay(with: currentEllipseProperties)
        case .line:
            annotationCanvasView.currentLineProperties = currentLineProperties
            strokePanelView.updateDisplay(with: currentLineProperties)
        case .arrow:
            annotationCanvasView.currentArrowProperties = currentArrowProperties
            arrowPanelView.updateDisplay(with: currentArrowProperties)
        case .pen:
            annotationCanvasView.currentPenProperties = currentPenProperties
            penPanelView.updateDisplay(with: currentPenProperties)
        case .mosaic:
            annotationCanvasView.currentMosaicProperties = currentMosaicProperties
            mosaicPanelView.updateDisplay(with: currentMosaicProperties)
        case .text, nil:
            break
        }
    }
```

- [ ] **Step 7: 扩展工具选择与面板显隐**

将 `selectAnnotationTool(_:)` 中“只处理矩形面板”的逻辑改为：

```swift
        currentAnnotationTool = tool
        annotationCanvasView.currentTool = tool
        annotationCanvasView.selectedAnnotationIndex = nil
        refreshCurrentToolPanelFromDefaults()
        updateVisiblePropertyPanel()
```

新增：

```swift
    private func updateVisiblePropertyPanel() {
        rectanglePanelView.isHidden = currentAnnotationTool != .rectangle
        strokePanelView.isHidden = currentAnnotationTool != .ellipse && currentAnnotationTool != .line
        arrowPanelView.isHidden = currentAnnotationTool != .arrow
        penPanelView.isHidden = currentAnnotationTool != .pen
        mosaicPanelView.isHidden = currentAnnotationTool != .mosaic
    }
```

- [ ] **Step 8: 扩展面板定位**

将 `layoutRectanglePropertyPanel(...)` 抽为：

```swift
    private func layoutPropertyPanel(
        _ panel: NSView,
        tool: AnnotationTool,
        toolbarFrame: CGRect,
        topBarFrame: CGRect
    )
```

尺寸策略改为：

```swift
        panel.layoutSubtreeIfNeeded()

        let fittingSize = panel.fittingSize
        let measuredWidth = fittingSize.width
        let measuredHeight = fittingSize.height
```

按工具做最小 / 最大钳制，而不是固定宽高：

```swift
        let minSize: CGSize
        let maxWidth: CGFloat

        switch tool {
        case .rectangle:
            minSize = RectanglePropertyPanelView.minimumPanelSize
            maxWidth = RectanglePropertyPanelView.maximumPanelWidth
        case .ellipse, .line:
            minSize = StrokePropertyPanelView.minimumPanelSize
            maxWidth = StrokePropertyPanelView.maximumPanelWidth
        case .arrow:
            minSize = ArrowPropertyPanelView.minimumPanelSize
            maxWidth = ArrowPropertyPanelView.maximumPanelWidth
        case .pen:
            minSize = PenPropertyPanelView.minimumPanelSize
            maxWidth = PenPropertyPanelView.maximumPanelWidth
        case .mosaic:
            minSize = MosaicPropertyPanelView.minimumPanelSize
            maxWidth = MosaicPropertyPanelView.maximumPanelWidth
        case .text:
            return
        }

        let panelSize = CGSize(
            width: min(max(measuredWidth, minSize.width), maxWidth),
            height: max(measuredHeight, minSize.height)
        )
```

内部继续沿用当前算法，只将按钮来源改为：

```swift
        let preferredX: CGFloat
        if let button = annotationToolButtons[tool] {
            preferredX = max(button.frame.minX, toolbarFrame.minX)
        } else {
            preferredX = toolbarFrame.minX
        }
```

然后按当前工具布局：

```swift
        switch currentAnnotationTool {
        case .rectangle:
            layoutPropertyPanel(rectanglePanelView, tool: .rectangle, toolbarFrame: toolbarFrame, topBarFrame: topBarFrame)
        case .ellipse:
            layoutPropertyPanel(strokePanelView, tool: .ellipse, toolbarFrame: toolbarFrame, topBarFrame: topBarFrame)
        case .line:
            layoutPropertyPanel(strokePanelView, tool: .line, toolbarFrame: toolbarFrame, topBarFrame: topBarFrame)
        case .arrow:
            layoutPropertyPanel(arrowPanelView, tool: .arrow, toolbarFrame: toolbarFrame, topBarFrame: topBarFrame)
        case .pen:
            layoutPropertyPanel(penPanelView, tool: .pen, toolbarFrame: toolbarFrame, topBarFrame: topBarFrame)
        case .mosaic:
            layoutPropertyPanel(mosaicPanelView, tool: .mosaic, toolbarFrame: toolbarFrame, topBarFrame: topBarFrame)
        case .text, nil:
            break
        }
```

- [ ] **Step 9: 构建确认 Overlay 接线完成后仍可构建**

运行：

```bash
./scripts/build.sh
```

预期：

```text
** BUILD SUCCEEDED **
```

- [ ] **Step 10: 提交**

```bash
git add TYScreenShotTool/Features/CaptureOverlay/CaptureOverlayView.swift \
  TYScreenShotTool/Features/CaptureOverlay/CaptureAnnotationCanvasView.swift
git commit -m "feat(sprint-44): 接入多工具属性面板"
```

---

### Task 5：扩展 `CaptureAnnotationCanvasView` 的创建、选中与回显链路，并显式覆盖 `line/pen/mosaic`

**Files:**
- Modify: `TYScreenShotTool/Features/CaptureOverlay/CaptureAnnotationCanvasView.swift`

- [ ] **Step 1: 基于 Task 4 已前移接口，补齐本任务剩余交互链路**

本任务不再重复定义 `current*Properties`、`onAnnotationSelected`、`updateSelectedAnnotationProperties(_:)`，直接在 Task 4 前移接口的基础上继续补齐拖拽创建、命中回显和选中状态刷新。

- [ ] **Step 2: 扩展 annotation 创建逻辑，并把 `line` 加入完整拖拽生命周期**

更新 `makeDragAnnotation(from:to:)`：

```swift
        case .rectangle:
            return .rectangle(normalizedRect(from: start, to: end), currentRectangleProperties)
        case .ellipse:
            return .ellipse(normalizedRect(from: start, to: end), currentEllipseProperties)
        case .line:
            return .line(start: start, end: end, currentLineProperties)
        case .arrow:
            return .arrow(start: start, end: end, currentArrowProperties)
        case .mosaic:
            return .mosaic(normalizedRect(from: start, to: end), currentMosaicProperties)
```

同步把 `mouseDown(with:)` 中拖拽创建入口从：

```swift
        case .ellipse, .arrow:
```

改为：

```swift
        case .ellipse, .line, .arrow:
```

把 `mouseDragged(with:)` 中拖拽更新入口从：

```swift
        case .rectangle, .ellipse, .arrow:
```

改为：

```swift
        case .rectangle, .ellipse, .line, .arrow:
```

把 `mouseUp(with:)` 中拖拽完成入口从：

```swift
        case .rectangle, .ellipse, .arrow:
```

改为：

```swift
        case .rectangle, .ellipse, .line, .arrow:
```

更新 `pen` 创建：

```swift
            temporaryAnnotation = .pen(points: [point], currentPenProperties)
```

和拖拽追加：

```swift
        guard case let .pen(points, properties) = temporaryAnnotation else {
            return
        }
        temporaryAnnotation = .pen(points: points + [point], properties)
```

- [ ] **Step 3: 扩展多工具点击选中，补齐 `pen` / `mosaic` 命中回显**

将 `mouseDown(with:)` 中“仅矩形可选中”的分支改为通用流程：

```swift
        if let hitResult = hitTestEditableAnnotation(at: point) {
            selectedAnnotationIndex = hitResult.index
            onAnnotationSelected?(hitResult.index, hitResult.tool, hitResult.properties)
            needsDisplay = true
            return
        }

        selectedAnnotationIndex = nil
        onAnnotationSelected?(nil, currentTool, nil)
        needsDisplay = true
```

新增命中结果：

```swift
    private struct EditableAnnotationHit {
        let index: Int
        let tool: AnnotationTool
        let properties: AnnotationEditableProperties
    }
```

补齐完整命中分发：

```swift
    private func hitTestEditableAnnotation(at point: CGPoint) -> EditableAnnotationHit? {
        for index in annotations.indices.reversed() {
            switch annotations[index] {
            case let .rectangle(rect, properties):
                if rect.standardized.contains(point) {
                    return EditableAnnotationHit(index: index, tool: .rectangle, properties: .rectangle(properties))
                }
            case let .ellipse(rect, properties):
                if rect.standardized.insetBy(dx: -6, dy: -6).contains(point) {
                    return EditableAnnotationHit(index: index, tool: .ellipse, properties: .ellipse(properties))
                }
            case let .line(start, end, properties):
                if isPoint(point, nearLineFrom: start, to: end, tolerance: max(8, properties.lineWidth + 4)) {
                    return EditableAnnotationHit(index: index, tool: .line, properties: .line(properties))
                }
            case let .arrow(start, end, properties):
                if isPoint(point, nearLineFrom: start, to: end, tolerance: max(10, properties.lineWidth + 6)) {
                    return EditableAnnotationHit(index: index, tool: .arrow, properties: .arrow(properties))
                }
            case let .pen(points, properties):
                if isPoint(point, nearPolyline: points, tolerance: max(10, properties.lineWidth / 2 + 4)) {
                    return EditableAnnotationHit(index: index, tool: .pen, properties: .pen(properties))
                }
            case let .mosaic(rect, properties):
                if rect.standardized.insetBy(dx: -6, dy: -6).contains(point) {
                    return EditableAnnotationHit(index: index, tool: .mosaic, properties: .mosaic(properties))
                }
            case .text:
                continue
            }
        }

        return nil
    }
```

- [ ] **Step 4: 验证前移的通用属性回写入口已覆盖 `line/pen/mosaic`**

确认 Task 4 前移的 `updateSelectedAnnotationProperties(_:)` 至少包含以下 case，不再重复定义第二份实现：

```swift
    func updateSelectedAnnotationProperties(_ properties: AnnotationEditableProperties) {
        guard let idx = selectedAnnotationIndex, annotations.indices.contains(idx) else { return }

        switch (annotations[idx], properties) {
        case let (.rectangle(rect, _), .rectangle(value)):
            annotations[idx] = .rectangle(rect, value)
        case let (.ellipse(rect, _), .ellipse(value)):
            annotations[idx] = .ellipse(rect, value)
        case let (.line(start, end, _), .line(value)):
            annotations[idx] = .line(start: start, end: end, value)
        case let (.arrow(start, end, _), .arrow(value)):
            annotations[idx] = .arrow(start: start, end: end, value)
        case let (.pen(points, _), .pen(value)):
            annotations[idx] = .pen(points: points, value)
        case let (.mosaic(rect, _), .mosaic(value)):
            annotations[idx] = .mosaic(rect, value)
        default:
            return
        }

        annotationsDidChange?(annotations)
        needsDisplay = true
    }
```

- [ ] **Step 5: 补齐折线命中辅助方法**

新增：

```swift
    private func isPoint(_ point: CGPoint, nearPolyline points: [CGPoint], tolerance: CGFloat) -> Bool {
        guard points.count > 1 else { return false }

        for index in 0..<(points.count - 1) {
            if isPoint(point, nearLineFrom: points[index], to: points[index + 1], tolerance: tolerance) {
                return true
            }
        }

        return false
    }
```

- [ ] **Step 6: 构建确认数据链路和回显链路已打通**

运行：

```bash
./scripts/build.sh
```

预期：

```text
** BUILD SUCCEEDED **
```

- [ ] **Step 7: 提交**

```bash
git add TYScreenShotTool/Features/CaptureOverlay/CaptureAnnotationCanvasView.swift
git commit -m "feat(sprint-44): 接入标注属性回显链路"
```

---

### Task 6：补齐圆形、直线、箭头的渲染与命中辅助方法

**Files:**
- Modify: `TYScreenShotTool/Features/CaptureOverlay/CaptureAnnotationCanvasView.swift`

- [ ] **Step 1: 更新圆形渲染**

把：

```swift
        case let .ellipse(rect, _):
            let path = NSBezierPath(ovalIn: rect.standardized)
            configureStroke()
            path.lineWidth = 3
            path.stroke()
```

改为：

```swift
        case let .ellipse(rect, props):
            let path = NSBezierPath(ovalIn: rect.standardized)
            props.color.toNSColor().withAlphaComponent(props.opacity).setStroke()
            path.lineWidth = props.lineWidth
            path.stroke()
```

- [ ] **Step 2: 新增直线渲染**

在 `draw(annotation:at:)` 中加入：

```swift
        case let .line(start, end, props):
            let path = NSBezierPath()
            path.move(to: start)
            path.line(to: end)
            path.lineWidth = props.lineWidth
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            props.color.toNSColor().withAlphaComponent(props.opacity).setStroke()
            path.stroke()
```

- [ ] **Step 3: 更新箭头渲染并支持曲线箭头**

先把 `draw(annotation:at:)` 中箭头渲染从：

```swift
        case let .arrow(start, end, _):
            let path = arrowPath(from: start, to: end)
            configureStroke()
            path.stroke()
```

改为：

```swift
        case let .arrow(start, end, props):
            let path = arrowPath(from: start, to: end, isCurved: props.isCurved)
            path.lineWidth = props.lineWidth
            props.color.toNSColor().withAlphaComponent(props.opacity).setStroke()
            path.stroke()
```

将：

```swift
    private func arrowPath(from start: CGPoint, to end: CGPoint) -> NSBezierPath
```

改为：

```swift
    private func arrowPath(from start: CGPoint, to end: CGPoint, isCurved: Bool) -> NSBezierPath
```

其中曲线主路径：

```swift
        let control = CGPoint(
            x: (start.x + end.x) / 2,
            y: max(start.y, end.y) + min(abs(end.x - start.x), 60)
        )

        path.move(to: start)
        path.curve(to: end, controlPoint1: control, controlPoint2: control)
```

箭头头部方向使用终点附近切线近似，而不是原来的直线角度。

- [ ] **Step 4: 新增线段命中辅助**

补齐：

```swift
    private func isPoint(_ point: CGPoint, nearLineFrom start: CGPoint, to end: CGPoint, tolerance: CGFloat) -> Bool {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else {
            return hypot(point.x - start.x, point.y - start.y) <= tolerance
        }

        let t = max(0, min(1, ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared))
        let projection = CGPoint(x: start.x + dx * t, y: start.y + dy * t)
        return hypot(point.x - projection.x, point.y - projection.y) <= tolerance
    }
```

- [ ] **Step 5: 构建确认基础图形工具全部通过编译**

运行：

```bash
./scripts/build.sh
```

预期：

```text
** BUILD SUCCEEDED **
```

- [ ] **Step 6: 提交**

```bash
git add TYScreenShotTool/Features/CaptureOverlay/CaptureAnnotationCanvasView.swift
git commit -m "feat(sprint-44): 扩展基础图形标注属性渲染"
```

---

### Task 7：补齐画笔三种模式与矩形马赛克两种样式

**Files:**
- Modify: `TYScreenShotTool/Features/CaptureOverlay/CaptureAnnotationCanvasView.swift`

- [ ] **Step 1: 更新画笔纯色渲染**

把：

```swift
        case let .pen(points, _):
```

改为：

```swift
        case let .pen(points, props):
            guard let first = points.first else { return }

            let path = NSBezierPath()
            path.lineWidth = props.lineWidth
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.move(to: first)

            for point in points.dropFirst() {
                path.line(to: point)
            }

            if props.mode == .singleColor {
                props.color.toNSColor().withAlphaComponent(props.opacity).setStroke()
                path.stroke()
            } else {
                drawEffectStroke(path: path, mode: props.mode)
            }
```

- [ ] **Step 2: 新增画笔模糊/马赛克路径效果**

新增完整方法：

```swift
    private func drawEffectStroke(path: NSBezierPath, mode: PenMode) {
        guard let sourceImage, let context = NSGraphicsContext.current?.cgContext else {
            return
        }

        let clipBounds = path.bounds.insetBy(dx: -20, dy: -20)
        guard clipBounds.width > 0, clipBounds.height > 0, bounds.width > 0, bounds.height > 0 else {
            return
        }

        let imageScaleX = CGFloat(sourceImage.width) / bounds.width
        let imageScaleY = CGFloat(sourceImage.height) / bounds.height
        let cropRect = CGRect(
            x: clipBounds.minX * imageScaleX,
            y: clipBounds.minY * imageScaleY,
            width: clipBounds.width * imageScaleX,
            height: clipBounds.height * imageScaleY
        ).integral

        let input = CIImage(cgImage: sourceImage).cropped(to: cropRect)
        let output: CIImage?

        switch mode {
        case .gaussianBlur:
            let filter = CIFilter(name: "CIGaussianBlur")
            filter?.setValue(input, forKey: kCIInputImageKey)
            filter?.setValue(12, forKey: kCIInputRadiusKey)
            output = filter?.outputImage?.cropped(to: cropRect)
        case .mosaic:
            let filter = CIFilter(name: "CIPixellate")
            filter?.setValue(input, forKey: kCIInputImageKey)
            filter?.setValue(18, forKey: kCIInputScaleKey)
            output = filter?.outputImage?.cropped(to: cropRect)
        case .singleColor:
            output = nil
        }

        guard let output, let cgImage = ciContext.createCGImage(output, from: cropRect) else {
            return
        }

        context.saveGState()
        path.addClip()
        context.draw(cgImage, in: clipBounds)
        context.restoreGState()
    }
```

- [ ] **Step 3: 更新矩形马赛克渲染入口**

把：

```swift
        case let .mosaic(rect, _):
            drawMosaic(in: rect.standardized)
```

改为：

```swift
        case let .mosaic(rect, props):
            drawMosaic(in: rect.standardized, properties: props)
```

并把签名改为：

```swift
    private func drawMosaic(in rect: CGRect, properties: MosaicProperties)
```

- [ ] **Step 4: 实现 `glass` 样式**

在 `drawMosaic(in:properties:)` 内区分：

```swift
        switch properties.style {
        case .mosaic:
            pixelateFilter.setValue(max(10, properties.size * 8), forKey: kCIInputScaleKey)
        case .glass:
            blurFilter.setValue(max(8, properties.size * 6), forKey: kCIInputRadiusKey)
        }
```

`glass` 叠加层：

```swift
outputContext.setFillColor(NSColor.white.withAlphaComponent(0.12).cgColor)
```

- [ ] **Step 5: 构建确认全部效果接入完成**

运行：

```bash
./scripts/build.sh
```

预期：

```text
** BUILD SUCCEEDED **
```

- [ ] **Step 6: 提交**

```bash
git add TYScreenShotTool/Features/CaptureOverlay/CaptureAnnotationCanvasView.swift
git commit -m "feat(sprint-44): 支持画笔与马赛克效果模式"
```

---

### Task 8：人工验证并同步 Sprint 文档

**Files:**
- Create: `docs/SPRINTS/Sprint-44.md`
- Modify: `docs/ROADMAP.md`
- Modify: `docs/DEVLOG.md`

- [ ] **Step 1: 按清单进行人工验证**

验证顺序：

1. 打开普通截图编辑态，确认工具栏中新增 `直线` 按钮
2. 点击 `圆形`，确认出现大小 / 不透明度 / 颜色面板
3. 画一个圆形，切换颜色和透明度，确认新画图形生效
4. 点击已画圆形，确认属性回显，修改后图形实时更新
5. 点击 `直线`，确认面板与圆形一致，绘制和回显都可用
6. 点击 `箭头`，确认支持 `曲线箭头` 开关；开关前后都能绘制
7. 点击 `画笔`，分别验证 `单一颜色` / `高斯模糊` / `马赛克`
8. 点击已画画笔笔迹，确认 `pen` 的属性可以回显并修改
9. 点击 `马赛克`，分别验证 `马赛克` / `毛玻璃`
10. 点击已有马赛克区域，确认属性回显并修改
11. 切回矩形，确认 Sprint 41 原有面板不回归
12. 再验证 `文字`、`OCR`、`AI`、`Pin`、`复制`、`保存`、`取消` 主链路未受影响

- [ ] **Step 2: 编写 Sprint 44 文档**

创建 `docs/SPRINTS/Sprint-44.md`，结构参照 Sprint 43，至少包含：

```md
# Sprint 44 - 标注工具属性面板扩展

## Status

✅ Done

## Goal

为普通截图编辑态补齐圆形、直线、箭头、画笔、马赛克的属性面板与属性回显链路，并新增直线工具按钮。

## Scope

### Included

- 新增 `直线` 工具
- 新增 5 类工具属性面板能力
- 支持选中已有标注后回显并继续修改
- 画笔支持 `单一颜色` / `高斯模糊` / `马赛克`
- 马赛克支持 `马赛克` / `毛玻璃`
```

- [ ] **Step 3: 同步 `docs/ROADMAP.md`**

在 `docs/ROADMAP.md` 中追加：

```md
### Sprint 44

标注工具属性面板扩展

状态：
✅ Done

成果：

- 新增 `直线` 标注工具
- 圆形、直线、箭头、画笔、马赛克补齐属性面板
- 支持选中已有标注后回显并继续修改
- 画笔支持单一颜色 / 高斯模糊 / 马赛克
- 马赛克支持马赛克 / 毛玻璃
```

- [ ] **Step 4: 同步 `docs/DEVLOG.md`**

在 `docs/DEVLOG.md` 顶部新增 Sprint 44 条目，按“主题 / 实现 / 验证 / 结果”四段写法记录。

- [ ] **Step 5: 最终构建确认**

运行：

```bash
./scripts/build.sh
```

预期：

```text
** BUILD SUCCEEDED **
```

- [ ] **Step 6: 提交**

```bash
git add docs/SPRINTS/Sprint-44.md docs/ROADMAP.md docs/DEVLOG.md
git commit -m "docs(sprint-44): 同步标注工具属性面板结果"
```

---

## 自检

### Spec coverage

- `line` 工具：Task 1、Task 4、Task 5、Task 6
- 5 个工具属性面板：Task 3、Task 4
- 新画使用当前属性：Task 4、Task 5
- 选中已有标注后回显并继续修改：Task 4、Task 5、Task 6、Task 7
- `pen` 回显与修改：Task 5、Task 7、Task 8
- `mosaic` 回显与修改：Task 5、Task 7、Task 8
- 画笔 3 种模式：Task 1、Task 3、Task 7
- 马赛克 2 种样式：Task 1、Task 3、Task 7
- 文档收尾：Task 8

### Placeholder scan

- 已移除 `...`、`TODO`、`TBD`、以及“类似 Task N”的占位语句
- 关键难点方法均给出了实际代码骨架或完整实现片段

### Type consistency

- `AnnotationEditableProperties` 作为唯一回显载体
- `ShapeStrokeProperties` 仅供 `ellipse` / `line` 共用
- `PenMode` 固定为 `singleColor` / `gaussianBlur` / `mosaic`
- `MosaicStyle` 固定为 `mosaic` / `glass`
- `RectanglePropertyPanelView` 也迁到 `minimumPanelSize + maximumPanelWidth` 语义
- Overlay 面板修改会同步更新 Overlay 默认属性与 Canvas 默认属性
- 每个 task 结束前都要求恢复构建通过

---

## 执行建议

建议按以下顺序执行：

1. 先完成 Shared 层和 `CaptureAnnotation` 改造
2. 再做属性面板文件
3. 之后接 `CaptureOverlayView`
4. 最后集中收口 `CaptureAnnotationCanvasView`

这样每一步的回退边界更清晰，也不会把数据层、UI 层和渲染层的风险叠在一个 checkpoint 里。
