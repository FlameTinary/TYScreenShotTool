# Sprint 44 - 标注工具属性面板扩展设计文档

## 1. 背景

Sprint 41 已经为矩形工具增加了独立属性面板，建立了以下能力基础：

- `CaptureAnnotation.rectangle` 可以携带样式属性
- `CaptureAnnotationCanvasView` 已具备“点击已画矩形 -> 回显属性 -> 实时修改”的最小链路
- `CaptureOverlayView` 已具备工具栏下方面板的显示、隐藏与定位能力

但当前普通截图工具栏中，除矩形外，其余标注工具仍存在两个明显缺口：

1. 圆形、箭头、画笔、马赛克没有独立属性面板
2. 工具栏中缺少“直线”工具，无法与圆形 / 箭头形成完整的基础图形集

同时，本轮需求明确要求：

- 新增 `直线` 工具按钮
- 为 `圆形`、`直线`、`箭头`、`画笔`、`马赛克` 提供属性面板
- 支持“新绘制使用当前属性”
- 支持“选中已有标注后回显属性并继续修改”
- `文字` 工具本轮不进入范围

---

## 2. 本轮目标

Sprint 44 聚焦于普通截图编辑态中的标注属性扩展。

具体目标：

- 在 `AnnotationTool` 中新增 `line` 工具
- 为 `圆形`、`直线`、`箭头`、`画笔`、`马赛克` 建立独立属性数据模型
- 扩展 `CaptureAnnotation`，让上述标注都能携带自己的样式属性
- 在工具栏下方增加对应属性面板，并与当前工具联动显示
- 支持点击已有标注后自动切换到对应工具并回显属性
- 支持修改属性后实时更新已选中标注
- 让画笔支持三种模式：
  - `单一颜色`
  - `高斯模糊`
  - `马赛克`
- 让矩形马赛克支持两种样式：
  - `马赛克`
  - `毛玻璃`

---

## 3. 用户故事

### 用户故事 1

作为截图编辑用户，
我希望点击圆形、直线、箭头、画笔、马赛克工具后都能看到对应的属性面板，
这样我可以在标注前先调整粗细、透明度、颜色或效果模式。

### 用户故事 2

作为已经完成部分标注的用户，
我希望点击已有标注时能直接回显它的属性，并继续修改，
这样我不需要删除再重画。

### 用户故事 3

作为需要表达不同强调语义的用户，
我希望画笔既能画纯色，也能直接画模糊或马赛克，
这样我可以在同一次截图编辑中完成高亮与遮挡。

### 用户故事 4

作为使用基础图形标注的用户，
我希望工具栏里有单独的“直线”按钮，
这样我不需要拿箭头代替直线。

---

## 4. 范围

### Included

- `AnnotationTool` 新增 `line`
- 工具栏新增直线按钮，并按参考图插入在圆形与箭头之间
- 为以下工具新增属性面板：
  - 圆形
  - 直线
  - 箭头
  - 画笔
  - 马赛克
- 扩展 `CaptureAnnotation` 使上述标注都携带自己的样式属性
- 扩展 `CaptureAnnotationCanvasView`：
  - 新绘制时使用当前工具默认属性
  - 选中已有标注并回显属性
  - 修改属性后实时更新选中标注
- 画笔支持 `单一颜色` / `高斯模糊` / `马赛克`
- 马赛克矩形支持 `马赛克` / `毛玻璃`
- 保持矩形属性面板与矩形渲染逻辑继续工作

### Out of Scope

- 不为 `文字` 工具增加属性面板
- 不修改 OCR / AI / Pin / 保存 / 复制 / 长截图链路
- 不重做工具栏整体外观
- 不引入新的第三方依赖
- 不实现多选
- 不实现文字样式编辑
- 不重做画布整体状态机

---

## 5. 技术策略

本轮优先沿用现有截图编辑态的 AppKit 结构，不强行将属性面板内容迁移为 SwiftUI。

原因：

1. 当前普通截图编辑态的工具栏、按钮命中、面板定位、第一响应者、画布选中与鼠标事件链路均基于 AppKit
2. 本轮核心复杂度在于“属性数据回显”和“标注渲染更新”，不是面板 UI 自身
3. 如果在本轮同时引入 SwiftUI 面板内容与 AppKit 选中/回显桥接，会显著增加状态同步复杂度

因此本轮建议：

- **窗口与 Overlay 容器**：继续使用 AppKit
- **属性面板视图**：使用 AppKit
- **属性面板布局**：统一使用 SnapKit

这符合当前 `AGENTS.md` 中“优先已有方案、控制复杂度、结果导向”的要求。

---

## 6. 设计方案

### 6.1 数据模型

本轮不引入复杂协议层，保持按工具拆分的直白结构。

新增或扩展以下类型：

#### 1. `ShapeStrokeProperties`

供 `ellipse` 和 `line` 共用：

```swift
struct ShapeStrokeProperties: Equatable {
    var lineWidth: CGFloat
    var opacity: CGFloat
    var color: RGBColor
}
```

#### 2. `ArrowProperties`

```swift
struct ArrowProperties: Equatable {
    var lineWidth: CGFloat
    var opacity: CGFloat
    var color: RGBColor
    var isCurved: Bool
}
```

#### 3. `PenMode`

```swift
enum PenMode: String, CaseIterable, Equatable {
    case singleColor
    case gaussianBlur
    case mosaic
}
```

#### 4. `PenProperties`

```swift
struct PenProperties: Equatable {
    var lineWidth: CGFloat
    var opacity: CGFloat
    var color: RGBColor
    var mode: PenMode
}
```

说明：

- `singleColor` 模式使用 `color + opacity`
- `gaussianBlur` / `mosaic` 模式仍保留 `color` 字段，主要为保持模型结构统一；渲染时不直接使用颜色

#### 5. `MosaicStyle`

```swift
enum MosaicStyle: String, CaseIterable, Equatable {
    case mosaic
    case glass
}
```

#### 6. `MosaicProperties`

```swift
struct MosaicProperties: Equatable {
    var size: CGFloat
    var style: MosaicStyle
}
```

#### 7. `CaptureAnnotation`

扩展为：

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

这样每个标注在创建时就持有自己的样式快照，后续回显、撤销和重绘都不依赖“当前工具状态”推断。

### 6.2 默认属性状态

`CaptureOverlayView` 与 `CaptureAnnotationCanvasView` 之间继续保持“当前工具默认属性”的同步方式，但从单一矩形扩展为多工具：

- `currentRectangleProperties`
- `currentEllipseProperties`
- `currentLineProperties`
- `currentArrowProperties`
- `currentPenProperties`
- `currentMosaicProperties`

这些默认值用于：

1. 打开面板时的初始显示
2. 新绘制该工具时的属性来源
3. 取消选中后继续绘制同类标注时的默认样式

### 6.3 通用选中回显载体

为了避免 `CaptureOverlayView` 继续只接收 `RectangleProperties?`，本轮新增一个轻量枚举作为选中回显桥梁：

```swift
enum AnnotationEditableProperties: Equatable {
    case rectangle(RectangleProperties)
    case ellipse(ShapeStrokeProperties)
    case line(ShapeStrokeProperties)
    case arrow(ArrowProperties)
    case pen(PenProperties)
    case mosaic(MosaicProperties)
}
```

`CaptureAnnotationCanvasView` 的选中回调改为：

```swift
var onAnnotationSelected: ((Int?, AnnotationTool?, AnnotationEditableProperties?) -> Void)?
```

意义：

- `Int?`：当前选中的 annotation 索引
- `AnnotationTool?`：对应工具类型，供 `CaptureOverlayView` 自动切换工具按钮和面板
- `AnnotationEditableProperties?`：回显到对应属性面板

### 6.4 属性面板拆分

本轮不做“超级通用面板”，而是保留“每类工具一个清晰面板”的结构。

#### 保留

- `RectanglePropertyPanelView`

#### 新增

1. `StrokePropertyPanelView`
   - 供圆形和直线共用
   - 字段：
     - 大小
     - 不透明度
     - 颜色

2. `ArrowPropertyPanelView`
   - 字段：
     - 大小
     - 不透明度
     - 颜色
     - `曲线箭头` 开关

3. `PenPropertyPanelView`
   - 字段：
     - 大小
     - 不透明度
     - 颜色
     - 下拉选：
       - `单一颜色`
       - `高斯模糊`
       - `马赛克`

4. `MosaicPropertyPanelView`
   - 字段：
     - 大小
     - 样式单选：
       - `马赛克`
       - `毛玻璃`
   - 不透明度显示为禁用态，不参与值变更，贴近参考图表达

### 6.5 面板布局与定位

属性面板继续出现在工具栏下方，一次仅显示一个。

规则：

1. 点击某个工具按钮 -> 显示对应面板，隐藏其他面板
2. 点击已有标注 -> 自动切换到对应工具，并显示对应面板
3. 点击其他非标注功能按钮或取消截图 -> 隐藏所有属性面板
4. 点击空白区域取消选中 -> 面板保持显示，但回到当前工具默认属性

面板定位继续沿用 Sprint 41 已验证通过的策略：

- 优先放在工具栏下方
- 优先对齐当前工具按钮附近
- 下方空间不足时回退到工具栏上方或边界内

本轮只扩展现有定位逻辑，不重写整套布局系统。

### 6.6 工具栏按钮顺序

根据参考图，本轮将标注工具顺序调整为：

1. 矩形
2. 圆形
3. 直线
4. 箭头
5. 画笔
6. 马赛克
7. 文字

`line` 使用单独的 SF Symbol，视觉上与箭头区分明确。

### 6.7 画布交互

#### 圆形

- 拖拽生成 `ellipse(CGRect, ShapeStrokeProperties)`
- 点击已有圆形可选中
- 选中后修改属性实时生效

#### 直线

- 新增 `line` 工具
- `mouseDown` 记录起点
- `mouseDragged` 更新终点
- `mouseUp` 生成 `line(start:end:properties)`
- 点击已有直线可选中并回显

#### 箭头

- 保持拖拽起止点交互不变
- 新增属性参数
- 点击已有箭头可选中并回显

#### 画笔

- 保持自由路径采样交互
- `mouseUp` 时生成 `pen(points:properties)`
- 点击已有画笔笔迹可选中并回显

#### 马赛克

- 保持矩形区域交互与已有 resize 命中逻辑
- 在 annotation 中持有 `MosaicProperties`
- 点击已有马赛克矩形可回显样式与大小

### 6.8 命中检测

本轮将现有“仅矩形可选中”扩展为多工具可选中，但仍保持最小可维护实现。

建议：

- `rectangle` / `ellipse` / `mosaic`
  - 使用标准化 bounds 作为第一层命中区域
- `line` / `arrow`
  - 以线段路径为中心，使用容差带命中
  - 容差建议：`max(8, lineWidth + 4)`
- `pen`
  - 遍历路径段，检测点到折线段距离是否落入容差带

这样可以避免为了本轮需求引入完整的几何编辑系统。

### 6.9 渲染

#### 圆形与直线

- 使用各自 `ShapeStrokeProperties`
- 支持颜色、透明度、线宽

#### 箭头

- `isCurved == false`
  - 沿用当前直箭头路径
- `isCurved == true`
  - 使用一条二次或三次贝塞尔曲线作为主路径
  - 箭头头部仍根据终点切线方向绘制

#### 画笔

##### 1. `singleColor`

- 按现有自由路径方式绘制
- 线宽、透明度、颜色来自 `PenProperties`

##### 2. `gaussianBlur`

- 根据笔迹点列生成一条带宽路径
- 将路径作为裁剪区域
- 对源图对应区域执行高斯模糊
- 仅在路径覆盖区域内输出模糊结果

##### 3. `mosaic`

- 同样基于笔迹路径生成裁剪区域
- 对源图对应区域执行马赛克像素化
- 仅在笔迹覆盖区域内输出马赛克结果

说明：

- 本轮不实现复杂的纹理笔刷系统
- 目标是得到“用户可见、可区分、可控制”的 3 种画笔效果

#### 马赛克矩形

##### 1. `mosaic`

- 继续使用当前像素化马赛克效果

##### 2. `glass`

- 在当前矩形区域内使用较轻模糊 + 半透明提亮覆盖
- 目标是呈现接近参考图中的毛玻璃观感
- 不追求复杂材质模拟或系统级玻璃折射

### 6.10 选中后的实时更新

当用户修改属性面板时：

1. 更新当前工具默认属性
2. 如果当前有选中标注，立即回写到该 annotation
3. `CaptureAnnotationCanvasView` 触发重绘
4. 标注视觉立即变化

这保持与 Sprint 41 矩形面板一致的交互预期。

---

## 7. 代码职责建议

### 新增文件

#### `Shared/ShapeStrokeProperties.swift`

- 定义圆形 / 直线共用样式属性

#### `Shared/ArrowProperties.swift`

- 定义箭头样式属性

#### `Shared/PenProperties.swift`

- 定义画笔样式属性与 `PenMode`

#### `Shared/MosaicProperties.swift`

- 定义矩形马赛克样式属性与 `MosaicStyle`

#### `Shared/AnnotationEditableProperties.swift`

- 作为画布与 Overlay 间的属性回显载体

#### `Features/CaptureOverlay/StrokePropertyPanelView.swift`

- 圆形 / 直线共用属性面板

#### `Features/CaptureOverlay/ArrowPropertyPanelView.swift`

- 箭头属性面板

#### `Features/CaptureOverlay/PenPropertyPanelView.swift`

- 画笔属性面板

#### `Features/CaptureOverlay/MosaicPropertyPanelView.swift`

- 马赛克属性面板

### 修改文件

#### `Shared/AnnotationTool.swift`

- 新增 `.line`
- 增加 `rawIdentifier` / `title` / `symbolName`

#### `Shared/CaptureAnnotation.swift`

- 为 `ellipse` / `arrow` / `pen` / `mosaic` 增加属性
- 新增 `line`
- 更新 `bounds`

#### `Features/CaptureOverlay/CaptureOverlayView.swift`

- 管理新增面板实例
- 管理当前默认属性
- 扩展工具切换与面板显隐
- 扩展选中回显处理
- 扩展工具栏布局与 `line` 按钮

#### `Features/CaptureOverlay/CaptureAnnotationCanvasView.swift`

- 扩展 annotation 创建逻辑
- 扩展多工具选中与命中检测
- 扩展属性回写逻辑
- 扩展多工具渲染
- 扩展画笔模糊 / 马赛克路径效果

---

## 8. 风险与控制

### 风险 1：画笔效果实现复杂度高于基础图形

控制：

- 将 `singleColor`、`gaussianBlur`、`mosaic` 统一收敛为“基于笔迹路径的局部裁剪渲染”
- 不引入复杂笔刷引擎

### 风险 2：多工具选中回显可能让 Overlay 状态分支变多

控制：

- 通过 `AnnotationEditableProperties` 统一回显载体
- 不在本轮做多选、拖拽变形、旋转等额外交互

### 风险 3：属性面板数量增加后布局分散

控制：

- 所有面板继续遵守同一定位规则
- 结构上保持“一工具一面板”，避免一个面板里塞太多条件分支

---

## 9. 验证要求

### 构建验证

- `./scripts/build.sh` 构建通过

### 人工验证

1. 工具栏中新增 `直线` 按钮，顺序与参考图一致
2. 点击 `圆形` / `直线` / `箭头` / `画笔` / `马赛克` 时，对应属性面板显示正确
3. 点击其他工具或取消时，属性面板隐藏正确
4. 圆形支持大小 / 不透明度 / 颜色，并可选中已有圆形继续修改
5. 直线支持大小 / 不透明度 / 颜色，并可选中已有直线继续修改
6. 箭头支持大小 / 不透明度 / 颜色 / 曲线箭头，并可选中已有箭头继续修改
7. 画笔支持 `单一颜色` / `高斯模糊` / `马赛克` 三种模式，并可选中已有笔迹继续修改
8. 马赛克支持 `马赛克` / `毛玻璃` 两种样式，并可选中已有区域继续修改
9. 矩形原有属性面板不回归
10. 文字、OCR、AI、Pin、复制、保存、取消主链路不回归

---

## 10. 结论

Sprint 44 建议在普通截图编辑态中继续沿用当前 AppKit Overlay 架构，通过新增 `line` 工具、扩展 `CaptureAnnotation` 样式属性、增加 4 类属性面板，以及建立多工具通用的“选中回显 -> 实时修改”链路，补齐除文字外主要标注工具的属性控制能力。

本轮重点不是重构截图编辑态，而是在现有结构上完成一轮可验证、可维护、可继续扩展的能力收口。
