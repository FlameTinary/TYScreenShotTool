# Sprint 41 - 矩形属性面板设计文档

## 1. 背景

当前 `CaptureOverlayView` 中的所有标注工具使用完全相同的渲染参数：

- 描边颜色：红色（全局常量）
- 线宽：3px（全局常量）
- 透明度：1.0（固定）
- 圆角：0（固定）
- 填充：空心（固定）

所有属性存储在 `CaptureAnnotation` 的静态常量上，无法针对单个矩形单独调整。

随着截图编辑功能逐渐完善，用户对标注的个性化控制需求越来越明显——不同的截图场景需要不同的标注视觉效果（如强调某个区域、弱化背景、统一报告风格等）。

因此，本轮需要为矩形工具建立一套属性面板，让用户能在编辑态自由调整矩形的视觉样式，同时面板属性值作为新矩形的默认值。

---

## 2. 本轮目标

Sprint 41 只做矩形工具的属性面板，不做其他工具的属性面板。

具体目标：

- 新增 `RectangleProperties` 与 `RGBColor` 数据模型
- 新增 `RectanglePropertyPanelView` 属性面板（两排布局，在工具栏下方显示）
- 修改 `CaptureAnnotation.rectangle` 关联属性数据
- 修改 `CaptureAnnotationCanvasView` 新增选中交互与基于属性的渲染
- 点击矩形工具按钮 → 面板显示；点击其他工具/取消 → 面板隐藏
- 点击已画矩形 → 选中并同步面板属性；调整面板 → 矩形实时更新
- 面板属性值作为新矩形的默认值
- 不修改椭圆/箭头/画笔/马赛克/文字的渲染与行为

---

## 3. 用户故事

### 用户故事 1

作为截图编辑用户，
我希望在选中矩形工具后能看到一个属性面板，
这样我可以自由调整矩形的粗细、透明度、圆角、实心/空心和颜色，
而不是只能使用固定的红色 3px 描边。

### 用户故事 2

作为需要精细标注的用户，
我希望点击已画好的矩形就能选中它，
然后通过属性面板实时调整它的样式，
这样我不需要删除重画。

### 用户故事 3

作为批量标注的用户，
我调整好属性面板后画的新矩形直接使用面板的当前值，
这样我可以按统一风格连续标注多个区域。

---

## 4. 范围

### Included

- 新增 `RectangleProperties` 结构体（线宽、透明度、圆角、填充、颜色）
- 新增 `RGBColor` 结构体（Equatable 颜色值 + 预设 8 色表）
- 新增 `RectanglePropertyPanelView` NSVisualEffectView（两排布局）
- 修改 `CaptureAnnotation.rectangle(CGRect)` → `.rectangle(CGRect, RectangleProperties)`
- 修改 `CaptureAnnotationCanvasView` 的：
  - 选中机制（点击矩形进入选中态）
  - 选中高亮（青色虚线边框）
  - 基于属性的渲染（颜色、线宽、透明度、圆角、实心/空心）
- 修改 `CaptureOverlayView` 的面板生命周期与布局
- 面板生命周期：点击矩形 → 显示；点击其他工具/取消 → 隐藏
- 面板值作为新矩形默认值

### Out of Scope

- 不修改椭圆/箭头/画笔/马赛克/文字工具的属性控制
- 不修改顶部浮层（size 标签 / 圆角滑块 / 阴影开关）
- 不修改 OCR / AI / Pin / 复制 / 保存的功能行为
- 不支持 NSColorPanel 完整取色器
- 不支持多选
- 不支持选中后拖拽调整矩形大小
- 不引入新的第三方依赖

---

## 5. 设计方案

### 5.1 数据模型

新增 `RectangleProperties` 结构体管理矩形的全部样式属性：

```swift
struct RectangleProperties: Equatable {
    var lineWidth: CGFloat      // 线宽 1-12px
    var opacity: CGFloat        // 透明度 0.0-1.0
    var cornerRadius: CGFloat   // 圆角 0-100
    var isFilled: Bool          // false=空心, true=实心
    var color: RGBColor         // 颜色

    static let `default` = RectangleProperties(
        lineWidth: 3,
        opacity: 1.0,
        cornerRadius: 0,
        isFilled: false,
        color: RGBColor(red: 0.93, green: 0.24, blue: 0.21)
    )
}
```

新增 `RGBColor` 解决 CGColor 不支持 Equatable 的问题：

```swift
struct RGBColor: Equatable {
    var red: CGFloat   // 0.0-1.0
    var green: CGFloat
    var blue: CGFloat
}
```

预设 8 色：红 / 橙 / 黄 / 绿 / 蓝 / 紫 / 白 / 黑。

修改 `CaptureAnnotation.rectangle` 由只携带 `CGRect` 改为携带位置+属性：

```swift
case rectangle(CGRect, RectangleProperties)
```

移除 `CaptureAnnotation` 中不再需要的静态常量：
- `strokeColor` → 由 `RectangleProperties.color` 承载
- `lineWidth` → 由 `RectangleProperties.lineWidth` 承载

### 5.2 面板 UI 设计

采用 `NSVisualEffectView(material: .popover)`，与顶部栏相同材质。

两排横向布局，面板直接放在工具栏下方，居中对齐：

**第一排（3 个控件）：**

| 控件 | 交互类型 | 取值范围 |
|------|---------|---------|
| 粗细 | 下拉选 `NSPopUpButton` | 1 ~ 12px |
| 透明度 | 滑块 `NSSlider` + 百分比标签 | 0% ~ 100% |
| 圆角 | 滑块 `NSSlider` + px 标签 | 0 ~ 100px |

**第二排（2 个控件）：**

| 控件 | 交互类型 | 取值 |
|------|---------|------|
| 样式 | 分段按钮 `NSSegmentedControl` | 实心 / 空心 |
| 颜色 | 预设 8 色圆点 `NSButton` | 红/橙/黄/绿/蓝/紫/白/黑 |

面板尺寸：宽 ~320pt，高 ~90pt。

回调解耦：
```swift
var onPropertyChanged: ((RectangleProperties) -> Void)?
```
面板通过回调向上通知属性变更，不直接操作数据模型。

### 5.3 选中交互

在 `CaptureAnnotationCanvasView` 中新增选中机制：

```swift
var selectedAnnotationIndex: Int?
var onAnnotationSelected: ((Int?, RectangleProperties?) -> Void)?
```

选中检测（`mouseDown` 中）：
1. 仅当 `currentTool == .rectangle` 时启用
2. 从后往前遍历 `annotations`，找到第一个 `.rectangle` 且点击点在矩形边界内
3. 选中该矩形，触发回调
4. 点击空白区域 → 取消选中

选中视觉高亮：
- 青色（`systemCyan`）虚线边框，外扩 4pt
- 线宽 2pt，虚线模式 `[6, 4]`
- 不影响矩形本身样式的渲染

实时更新：
```swift
func updateSelectedAnnotation(with properties: RectangleProperties) {
    guard let idx = selectedAnnotationIndex,
          case .rectangle(let rect, _) = annotations[idx] else { return }
    annotations[idx] = .rectangle(rect, properties)
    needsDisplay = true
}
```

### 5.4 矩形渲染更新

绘制 `.rectangle` 时从关联的 `RectangleProperties` 读取属性：

- **空心**：仅描边，使用 `lineWidth`、`color`、`opacity`
- **实心**：填充 `color`（按 `opacity`）+ 描边（线宽减半）
- **圆角**：使用 `NSBezierPath(roundedRect:xRadius:yRadius:)`
- 全部渲染通过 `NSColor(cgColor:)` 结合 `withAlphaComponent(opacity)` 控制透明度

### 5.5 面板生命周期

| 事件 | 面板显示状态 |
|------|------------|
| 点击矩形工具按钮 | 显示，填充默认值/新矩形默认值 |
| 点击已画矩形 | 显示，同步选中矩形属性 |
| 画新矩形 | 保持显示，值不变 |
| 点击其他工具按钮 | 隐藏 |
| 取消截图 | 隐藏 |
| 点击空白区域取消选中 | 保持显示，清空选中状态 |

### 5.6 颜色选择器

预设 8 色圆点按钮群（直径 20pt）：

| 颜色 | RGB |
|------|-----|
| 红 | 0.93, 0.24, 0.21 |
| 橙 | 1.0, 0.58, 0.0 |
| 黄 | 1.0, 0.80, 0.0 |
| 绿 | 0.20, 0.78, 0.35 |
| 蓝 | 0.0, 0.48, 1.0 |
| 紫 | 0.69, 0.32, 0.87 |
| 白 | 1.0, 1.0, 1.0 |
| 黑 | 0.0, 0.0, 0.0 |

点击圆点直接选中颜色，当前色由圆点边框高亮标识。

---

## 6. 代码职责建议

### 新建文件（3 个）

**`Shared/RectangleProperties.swift`**（~30 行）
- `RectangleProperties` 结构体定义
- 默认值 `static let default`
- `Equatable` 实现（由编译器合成）

**`Shared/RGBColor.swift`**（~15 行）
- `RGBColor` 结构体定义
- 预设色表（`static let presetColors: [RGBColor]`）
- 转换为 `CGColor` 的便捷方法

**`Features/CaptureOverlay/RectanglePropertyPanelView.swift`**（~80 行）
- `RectanglePropertyPanelView: NSVisualEffectView`
- 初始化与控件布局
- 属性变更回调
- 更新面板显示值的方法

### 修改文件（3 个）

**`Shared/CaptureAnnotation.swift`**（~20 行）
- `.rectangle(CGRect)` → `.rectangle(CGRect, RectangleProperties)`
- 移除 `static let strokeColor`、`static let lineWidth`
- 保留其他 case 与静态常量不变

**`Features/CaptureOverlay/CaptureAnnotationCanvasView.swift`**（~90 行）
- 新增 `selectedAnnotationIndex`、`onAnnotationSelected` 属性
- 修改 `draw(annotation:)` 中 `.rectangle` 渲染逻辑，读取 `RectangleProperties`
- 修改 `mouseDown` 增加矩形选中检测
- 新增选中高亮绘制
- 新增 `updateSelectedAnnotation(with:)` 方法
- 新增 `hitTestRectangle(at:)` 辅助方法

**`Features/CaptureOverlay/CaptureOverlayView.swift`**（~50 行）
- 新增 `rectanglePanelView` 属性
- 新增 `configurePropertyPanel()` 方法
- 修改 `layoutPreviewInterface()` 增加面板布局逻辑
- 修改 `selectAnnotationTool()` 控制面板显隐
- 连接面板回调与 `annotationCanvasView.updateSelectedAnnotation`
- 连接 `annotationCanvasView.onAnnotationSelected` 与面板同步

---

## 7. 错误处理

### 7.1 选中索引有效性

选中后如果通过 `undoLastAnnotation()` 删除了矩形，`selectedAnnotationIndex` 可能指向不存在的索引。

应对：
- `updateSelectedAnnotation` 和渲染逻辑中，每次使用前检查索引有效性
- 如果发现无效索引，自动清空 `selectedAnnotationIndex`

### 7.2 透明度为 0

设置透明度为 0 时矩形不可见。

应对：
- 选中高亮框不受透明度影响，始终保持可见
- 用户可以通过选中矩形重新调整透明度

### 7.3 多个矩形堆叠

多个矩形重叠时，点击命中检测从后往前遍历，确保返回最顶层（最后绘制）的矩形。

---

## 8. 验证场景

### 场景 1

点击矩形工具按钮，属性面板出现在工具栏下方，显示默认属性值。

### 场景 2

面板两排布局规整：第一排粗细/透明度/圆角，第二排样式/颜色。

### 场景 3

在画布上画一个新矩形，渲染效果使用面板当前值（如线宽 5px、蓝色）。

### 场景 4

点击已画矩形，矩形外围出现青色虚线高亮，面板同步显示该矩形的属性值。

### 场景 5

在面板中调整粗细/透明度/圆角/颜色/实心空心，选中的矩形实时更新。

### 场景 6

点击其他工具（椭圆/箭头等），面板隐藏。再点击矩形工具，面板重新显示。

### 场景 7

修改面板值后画多个矩形，每个新矩形都使用面板当前值。

### 场景 8

原有椭圆/箭头/画笔/马赛克/文字工具不受影响，渲染和行为保持不变。

### 场景 9

`./scripts/build.sh` 构建通过。

---

## 9. 非目标

Sprint 41 明确不做：

- 不修改椭圆/箭头/画笔/马赛克/文字的属性控制
- 不修改顶部浮层
- 不修改 OCR / AI / Pin / 复制 / 保存的功能行为
- 不支持 NSColorPanel 完整取色器
- 不支持多选
- 不支持选中后拖拽调整矩形大小
- 不引入新的第三方依赖

---

## 10. 推荐落地顺序

建议按以下顺序实现：

1. 新建 `RGBColor.swift` 和 `RectangleProperties.swift` 数据模型
2. 修改 `CaptureAnnotation.swift`，更新 `.rectangle` case 并移除静态常量
3. 新建 `RectanglePropertyPanelView.swift` 面板视图
4. 修改 `CaptureAnnotationCanvasView.swift`，实现基于属性的渲染
5. 在 `CaptureAnnotationCanvasView.swift` 中实现选中交互
6. 修改 `CaptureOverlayView.swift`，集成面板生命周期与布局
7. 构建验证与人工验证

---

## 11. 本轮结论

Sprint 41 为 TShot 引入矩形工具的个性化属性控制能力，也是截图编辑体验从"统一样式"迈向"灵活标注"的第一步。

核心变化：
- 新增矩形属性数据模型与面板 UI
- 画布标注选中交互
- 基于属性的矩形渲染

不改变其他工具的行为，不影响 OCR / AI / Pin / 复制 / 保存等核心链路。
改动主要集中在 3 个新建文件 + 3 个修改文件。
