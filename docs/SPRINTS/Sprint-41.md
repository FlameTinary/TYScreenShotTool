# Sprint 41 - 矩形属性面板

## Status

In Progress

## Goal

为矩形工具新增属性面板，支持调整粗细(1-12px)、透明度(0-100%)、圆角(0-100)、
实心/空心切换、颜色(预设8色)。点击已画矩形可选中并调整属性，
面板值作为新矩形默认值。

---

## Scope

### Included

- 新增 RGBColor/RectangleProperties 数据模型
- 新增 RectanglePropertyPanelView 属性面板（两排布局，在工具栏下方显示）
- 修改 CaptureAnnotation.rectangle 携带 RectangleProperties 参数
- 画布选中交互：点击已画矩形进入选中态（青色虚线高亮）
- 基于 RectangleProperties 的矩形渲染（圆角/实心空心/透明度）
- 导出渲染适配 RectangleProperties
- 面板生命周期：点击矩形→显示；点击其他工具/取消→隐藏

### Out of Scope

- 不修改椭圆/箭头/画笔/马赛克/文字的属性控制
- 不修改顶部浮层（size 标签/圆角滑块/阴影开关）
- 不修改 OCR / AI / Pin / 复制 / 保存的功能行为
- 不支持 NSColorPanel 完整取色器
- 不支持多选
- 不引入新的第三方依赖

---

## Implementation

### 方向

本轮新增 3 个文件 + 修改 3 个文件：

1. 新增 `RGBColor.swift`（Equatable 颜色值 + 预设 8 色）
2. 新增 `RectangleProperties.swift`（矩形样式属性结构体）
3. 新增 `RectanglePropertyPanelView.swift`（两排布局属性面板）
4. 修改 `CaptureAnnotation.swift`（.rectangle 增加属性参数）
5. 修改 `CaptureAnnotationCanvasView.swift`（选中交互 + 基于属性的渲染）
6. 修改 `CaptureOverlayView.swift`（面板集成与生命周期）
7. 修改 `CaptureSessionService.swift`（导出渲染适配）

### 约束

- 遵循 MVP
- 遵循 KISS
- 遵循 YAGNI
- CaptureAnnotation 的静态 strokeColor/lineWidth 保留（其他工具仍使用）

---

## Validation

### 场景 1

点击矩形工具按钮，属性面板在工具栏下方显示，两排布局规整，默认值正确。

### 场景 2

在画布上画一个新矩形，渲染效果使用面板当前值（颜色/粗细/透明度/圆角/实心空心）。

### 场景 3

点击已画矩形，出现青色虚线高亮，面板同步显示该矩形属性值。

### 场景 4

面板中调整属性，选中矩形实时更新。

### 场景 5

点击其他工具（椭圆/箭头等），面板隐藏。再次点击矩形，面板重新显示。

### 场景 6

修改面板值后画多个矩形，每个新矩形都使用面板当前值。

### 场景 7

原有椭圆/箭头/画笔/马赛克/文字工具不受影响。

### 场景 8

导出保存的图片中矩形正确渲染了属性（颜色/粗细/圆角等）。

### 场景 9

`./scripts/build.sh` 构建通过。

---

## Result

待实现。
