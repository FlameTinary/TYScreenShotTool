# 矩形属性面板设计规格

## 概述

为 TShot 截图编辑工具栏的矩形工具新增属性面板，允许用户调整已画矩形的样式（粗细、透明度、圆角、实心/空心、颜色），同时面板的当前值作为新矩形的默认值。

## 数据模型

### 新增：RectangleProperties

```swift
/// 矩形标注样式属性
struct RectangleProperties: Equatable {
    var lineWidth: CGFloat      // 线宽 1-12px，下拉选
    var opacity: CGFloat        // 透明度 0.0-1.0，滑块
    var cornerRadius: CGFloat   // 圆角 0-100px，滑块
    var isFilled: Bool          // false=空心(描边), true=实心(填充)
    var color: RGBColor         // 颜色

    static let `default` = RectangleProperties(
        lineWidth: 3,
        opacity: 1.0,
        cornerRadius: 0,
        isFilled: false,
        color: RGBColor(red: 0.93, green: 0.24, blue: 0.21)  // 红色
    )
}
```

### 新增：RGBColor

```swift
/// 可 Equatable 的颜色值，替代 CGColor
struct RGBColor: Equatable {
    var red: CGFloat   // 0.0-1.0
    var green: CGFloat
    var blue: CGFloat
}
```

预设 8 色：红(0.93,0.24,0.21) / 橙(1.0,0.58,0.0) / 黄(1.0,0.80,0.0) / 绿(0.20,0.78,0.35) / 蓝(0.0,0.48,1.0) / 紫(0.69,0.32,0.87) / 白(1,1,1) / 黑(0,0,0)。

### 修改：CaptureAnnotation

```swift
enum CaptureAnnotation: Equatable {
    case rectangle(CGRect, RectangleProperties)  // 新增属性参数
    case ellipse(CGRect)                          // 不变
    case arrow(start: CGPoint, end: CGPoint)      // 不变
    case pen(points: [CGPoint])                   // 不变
    case mosaic(CGRect)                           // 不变
    case text(value: String, origin: CGPoint)     // 不变
}

// 移除以下全局静态属性（改为由 RectangleProperties 承载）：
// static let strokeColor
// static let lineWidth
```

## UI 组件

### 新增：RectanglePropertyPanelView

继承关系：`NSVisualEffectView`（与顶部栏 `topBarContainerView` 相同的材质 `.popover`）

**间距参数：**
- 内边距：12pt（水平）× 10pt（垂直）
- 控件间距：20pt
- 圆角半径：10pt

**两排布局：**

| 排 | 控件 | 交互方式 |
|----|------|---------|
| 第一排 | 粗细、透明度、圆角 | 粗细=下拉选(1-12px)，透明度=滑块+百分比，圆角=滑块+px值 |
| 第二排 | 样式(实心/空心)、颜色 | 样式=分段按钮(■实心/□空心)，颜色=预设8色圆点 |

**面板尺寸：** 宽 ~320pt，高 ~90pt

**回调解耦：**
```swift
var onPropertyChanged: ((RectangleProperties) -> Void)?
```

面板本身不直接操作数据模型，仅通过回调向上通知属性变更。由 `CaptureOverlayView` 负责将变更应用到选中的标注。

**颜色选择器：**
- 预设 8 色圆点（直径 20pt），点击选中
- 可扩展为点击最后一个色块打开 NSColorPanel（当前版本暂不做，仅预设色块）

### 修改：CaptureOverlayView

在 `init` 调用链中新增：
1. `configurePropertyPanel()` — 创建 RectanglePropertyPanelView 并添加到视图层次
2. `layoutPreviewInterface()` 中布局——面板放在工具栏下方，居中对齐

**面板生命周期：**
- 点击矩形按钮 → `panelView.isHidden = false`
- 点击其他工具 / 取消 → `panelView.isHidden = true`
- 画布上有选中矩形且矩形工具激活 → 显示面板
- 取消选中（点击空白区域）→ 保持面板显示但清空选中状态

## 选中交互

### 修改：CaptureAnnotationCanvasView

新增属性：
```swift
var selectedAnnotationIndex: Int?
var onAnnotationSelected: ((Int?, RectangleProperties?) -> Void)?
```

**选中检测（mouseDown）：**
1. 仅当 `currentTool == .rectangle` 时启用
2. 从后往前遍历 `annotations`
3. 找到第一个 `.rectangle` 且点击点在矩形边界内
4. 设有 `selectedAnnotationIndex`，触发回调
5. 点击空白区域 → 取消选中

**视觉高亮：**
- 选中的矩形外围绘制青色（`systemCyan`）虚线边框
- 外扩 4pt，线宽 2pt，虚线模式 [6,4]
- 不影响矩形本身样式的渲染

**实时更新：**
```swift
func updateSelectedAnnotation(with properties: RectangleProperties) {
    guard let idx = selectedAnnotationIndex,
          case .rectangle(let rect, _) = annotations[idx] else { return }
    annotations[idx] = .rectangle(rect, properties)
    needsDisplay = true
}
```

**渲染更新：** 绘制 `.rectangle` 时，从关联的 `RectangleProperties` 读取颜色、线宽、透明度、圆角、填充值：
- 空心：仅描边（`lineWidth` 粗细，按 `opacity` 渲染）
- 实心：填充颜色 + 描边（描边线宽减半，填充按 `opacity` 渲染）
- 圆角：使用 `NSBezierPath(roundedRect:xRadius:yRadius:)`

## 文件变更清单

### 新建文件（3 个）

| 文件 | 行数估 | 说明 |
|------|--------|------|
| `Shared/RectangleProperties.swift` | ~30 | RectangleProperties 结构体 + default |
| `Shared/RGBColor.swift` | ~15 | Equatable 颜色值 + 预设色表 |
| `Features/CaptureOverlay/RectanglePropertyPanelView.swift` | ~80 | 面板视图：控件布局、回调 |

### 修改文件（3 个）

| 文件 | 行数估 | 修改内容 |
|------|--------|---------|
| `Shared/CaptureAnnotation.swift` | ~20 | rectangle case 增加属性参数，移除静态常量 |
| `Features/CaptureOverlay/CaptureAnnotationCanvasView.swift` | ~90 | 选中机制，新渲染逻辑 |
| `Features/CaptureOverlay/CaptureOverlayView.swift` | ~50 | 面板集成、布局调整 |

**总计变动：** ~285 行

## 交互流程

```
点击矩形按钮
  ├→ panelView.hidden = false
  ├→ panelView 填充 RectangleProperties.default
  └→ 画布进入矩形绘制模式

拖动画矩形
  └→ 新矩形使用面板当前属性值

点击已画矩形
  ├→ 矩形高亮（青色虚线边框）
  ├→ panelView 同步为该矩形的属性
  └→ 调整面板 → 矩形实时更新

点击其他工具 / 取消
  └→ panelView.hidden = true
  └→ 取消选中状态
```

## 错误处理与边界情况

- 无标注时点击画布 → 无操作（不会崩溃）
- 选中后删除标注（如 undo） → 选中索引失效 → 检查索引有效性
- 批量修改时透明度为 0 → 矩形不可见，但选中高亮框仍可见
- 颜色选择不涉及系统 NSColorPanel（当前版本）

## 未包含的范围（YAGNI）

- 不支持其他工具（椭圆、箭头等）的属性面板（设计可扩展但暂不实现）
- 不支持 NSColorPanel 完整取色器
- 不支持多选
- 不支持拖拽选中框调整大小（与现有马赛克调整机制类似但暂不实现）

## 参考

- 顶部栏 `topBarContainerView` 设计模式（NSVisualEffectView, .popover 材质）
- 现有 `CaptureAnnotation` 枚举模式
- 工具栏布局定位逻辑
