# Sprint 40 - 工具栏 SF Symbols 设计文档

## 1. 背景

当前 `CaptureOverlayView` 中的工具栏按钮（标注工具 + 功能按钮）全部使用纯文字展示，
存在以下问题：

- 视觉信息密度不够，按钮宽度受文字长度影响
- 缺乏 macOS 原生截图工具的视觉语言
- 工具栏整体显得拥挤，与截图画面的对比度不突出

随着各 Sprint 逐步完善截图编辑体验，
工具栏作为最常用的交互入口，
已到达需要做一次视觉升级的时间点。

本轮将工具栏改为 SF Symbols 图标展示，
保持功能完全不变，只做视觉升级。

---

## 2. 本轮目标

Sprint 40 只改工具栏，不动其他功能。

具体目标：

- `CaptureOverlayView` 的工具栏所有按钮由文字改为 SF Symbols 图标
- 标注工具选中态使用青色高亮，选中切换时播放 `.drawOn.individually` 动画
- 功能按钮（撤销 / 长截图 / OCR / AI / Pin / 复制 / 保存 / 取消）不做选中态动画
- 所有按钮统一尺寸，保持工具栏视觉对齐
- 工具栏容器保持现有 `NSVisualEffectView(material: .popover)` + 圆角 12
- 不修改拖拽选区、标注绘制、OCR / AI / Pin / 复制 / 保存等核心逻辑

---

## 3. 用户故事

### 用户故事 1

作为截图用户，
我希望工具栏以图标方式呈现，
这样我能更快识别每个按钮的功能，工具栏也更简洁不抢镜。

### 用户故事 2

作为标注工具使用者，
我希望点击某个标注工具时，
图标有明确的选中态视觉（颜色变化）和轻量动画，
这样我能清楚地知道当前正在使用哪支工具。

### 用户故事 3

作为功能按钮使用者（复制 / 保存 / OCR / AI 等），
我希望这些按钮稳定呈现图标，不需要选中态动画，
这样不会因为点击后残留的"选中"视觉干扰我的工作流。

---

## 4. 范围

### Included

- 标注工具 6 个按钮（矩形 / 椭圆 / 箭头 / 画笔 / 马赛克 / 文字）改为 SF Symbols 图标
- 功能按钮 8 个（撤销 / 长截图 / OCR / AI / Pin / 复制 / 保存 / 取消）改为 SF Symbols 图标
- 标注工具选中态：图标切换为青色高亮 + `.drawOn.individually` 动画
- 工具栏布局：统一按钮尺寸，保持现有间距和容器样式
- Tooltip：每个按钮提供中文 Tooltip，hover 时显示功能名

### Out of Scope

- 不修改拖拽选区预览区视觉（虚线 / 遮罩 / 发光边框）
- 不修改标注绘制逻辑（颜色 / 线宽 / 字体大小）
- 不修改 OCR / AI / Pin / 复制 / 保存的功能行为
- 不修改顶部浮层（size 标签 / 圆角滑块 / 阴影开关）
- 不为工具栏新增快捷键支持
- 不修改长截图面板的 UI

---

## 5. 设计方案

### 5.1 总体方案

本轮采用 `NSButton + NSImage(systemSymbolName:)` 方案：
- `bezelStyle` 使用适合图标的样式（`.rounded` 或 `.texturedRounded`）
- `preferredSymbolConfiguration = .init(pointSize: 20, weight: .regular)`
- 每个按钮的 `image` 由 SF Symbol 名称构造
- 按钮统一 frame 尺寸

不采用 SwiftUI + NSHostingView，
原因是：
- 当前 `CaptureOverlayView` 完全基于 AppKit，改动范围最小
- `.borderless` + SF Symbol 的原生效果最符合 macOS 设计规范
- 无需为图标单独引入 SwiftUI 层

---

### 5.2 Symbol 映射表

#### 标注工具按钮（有选中态）

| 工具 | Symbol（未选中） |
|------|-----------------|
| 矩形 | `rectangle` |
| 椭圆 | `circle` |
| 箭头 | `arrow.up.right` |
| 画笔 | `pencil.tip` |
| 马赛克 | `questionmark.square.dashed` |
| 文字 | `textformat` |

选中态：
- 图标颜色切换为青色高亮，保持原有 symbol 不变，不改成填充态
- 切换时播放动画：参考 `.symbolEffect(.drawOn.individually, options: .nonRepeating)`
- 取消选中：切回默认颜色，不播动画

#### 功能按钮（无选中态）

| 按钮 | Symbol |
|------|--------|
| 撤销 | `arrow.uturn.backward` |
| 长截图 | `rectangle.arrowtriangle.4.outward` |
| OCR | `text.viewfinder` |
| AI | `sparkles` |
| Pin | `pin` |
| 复制 | `doc.on.doc` |
| 保存 | `square.and.arrow.down` |
| 取消 | `xmark` |

功能按钮始终使用 `.default` symbol configuration，
不根据 state 切换符号，
`AI` 按钮的 `isEnabled` 状态仍由现有逻辑控制。

---

### 5.3 按钮样式参数

统一参数：

- **bezelStyle**：保持 `.rounded` 或调整为更适合图标的样式
- **imageScaling**：`.scaleProportionallyUpOrDown`
- **preferredSymbolConfiguration**：`.init(pointSize: 20, weight: .regular)`
- **contentTintColor**：未选中保持默认单色；选中切换为系统青色
- **frame**：统一固定尺寸按钮（优先保持接近方形，具体尺寸在实现时根据视觉对齐确定）
- **toolTip**：对应中文功能名（矩形 / 椭圆 / 箭头 / 画笔 / 马赛克 / 文字 / 撤销 / 长截图 / OCR / AI / Pin / 复制 / 保存 / 取消）

---

### 5.4 标注工具选中态实现

选中态通过更新按钮 tint 与 symbol effect 实现：

- 未选中：`.init(pointSize: 20, weight: .regular)` + 默认单色图标
- 选中：保持同一个 SF Symbol，图标颜色切换为系统青色
- 选中切换时播放一次绘制动画，视觉基准参考 `.symbolEffect(.drawOn.individually, options: .nonRepeating)`
- 取消选中：切回默认颜色，不播动画

`updateAnnotationToolSelection()` 方法的调用时机不变，
仅在内部更新按钮颜色与动画触发逻辑。

---

### 5.5 工具栏布局调整

由于按钮从文字自动宽度改为固定尺寸按钮，
需要调整 `toolbarContainerView` 的自动布局：

- **按钮尺寸**：统一方形（取代原来自适应文字宽度）
- **按钮间距**：保持现有 12pt
- **容器内边距**：保持现有 12pt
- **容器位置**：保持现有 24pt 边距规则

---

### 5.6 Tooltip 设计

每个按钮提供中文 Tooltip：

- 标注工具：矩形 / 椭圆 / 箭头 / 画笔 / 马赛克 / 文字
- 功能按钮：撤销 / 长截图 / OCR / AI / Pin / 复制 / 保存 / 取消

理由：
- 纯图标界面首次接触可能需要文字辅助理解
- Tooltip 不占屏，hover 才出现
- 符合 macOS 设计规范

Tooltip 文本从现有 `AnnotationTool.title` 和功能按钮已有文案取值，
不新增额外资源。

---

## 6. 代码职责建议

### `CaptureOverlayView`

这是本轮的核心改动点。

涉及的私有方法/属性：
- `configureToolbar()` — 重构按钮创建逻辑，使用 SF Symbol 替代文字
- `layoutPreviewInterface()` — 调整工具栏按钮尺寸计算
- `updateAnnotationToolSelection()` — 新增选中态颜色切换与动画触发逻辑
- 新增属性：
  - `private let defaultSymbolConfig`
  - `private let selectedTintColor`

不改动的方法：
- 所有标注绘制 / undo / 保存 / 复制 / OCR / AI 的业务逻辑
- 拖拽选区处理
- 顶部浮层

### `AnnotationTool`

新增一个计算属性用于返回对应 SF Symbol 名称：
- `var symbolName: String { get }`

不改动 `title` 和 `rawIdentifier`。

---

## 7. 错误处理

### 7.1 Symbol 不可用

部分 SF Symbol 在某些 macOS 版本上可能不存在或渲染有差异。

应对：
- 使用 macOS 14+ 普遍支持的基础符号
- 如果某个 symbol 在编译时不可用，
  回退到备选 symbol

### 7.2 选中态视觉不明显

部分 SF Symbol 在单色模式下切换高亮色后，视觉差异可能不够明显。

应对：
- 实现后人工验证每个标注工具的选中态视觉
- 如果某个 symbol 在常规 weight 下不够醒目，
  优先微调 pointSize / weight，而不是改成填充态

### 7.3 动画 API 不可用

`.drawOn.individually` 相关 symbol effect 在当前目标平台上的实际表现需要确认。

应对：
- 如果 API 不可用，
  回退到 `NSAnimationContext` 的轻量 alpha / scale 动画

---

## 8. 验证场景

### 场景 1

`CaptureOverlayView` 进入编辑态后，
工具栏所有按钮显示为 SF Symbols 图标，不再显示文字。

### 场景 2

14 个按钮统一尺寸，布局整齐对齐。

### 场景 3

标注工具点击选中后：
- 视觉上有明显青色高亮变化
- 播放 `.drawOn.individually` 动画一次
- 再次点击同一按钮取消选中，无动画

### 场景 4

功能按钮（撤销 / 长截图 / OCR / AI / Pin / 复制 / 保存 / 取消）点击后不改变图标，不播动画。

### 场景 5

hover 每个按钮显示中文 Tooltip。

### 场景 6

截图主链路（框选 → 标注 → 复制 / 保存 / OCR / AI / Pin / 长截图）全部正常工作。

### 场景 7

`./scripts/build.sh` 构建通过。

---

## 9. 非目标

Sprint 40 明确不做：

- 不修改拖拽选区预览区视觉
- 不修改标注绘制逻辑
- 不修改 OCR / AI / Pin / 复制 / 保存的功能行为
- 不修改顶部浮层
- 不为工具栏新增快捷键支持
- 不修改长截图面板的 UI
- 不引入新的第三方依赖

---

## 10. 推荐落地顺序

建议按以下顺序实现：

1. 在 `AnnotationTool` 中新增 `symbolName` 计算属性
2. 重构 `CaptureOverlayView.configureToolbar()`，
   将所有按钮改为 SF Symbol
3. 调整 `layoutPreviewInterface()` 中的按钮尺寸计算
4. 在 `updateAnnotationToolSelection()` 中接入选中态颜色切换与 `.drawOn` 动画
5. 为所有按钮增加 Tooltip
6. 构建验证与人工验证

---

## 11. 本轮结论

Sprint 40 是一次纯粹的视觉升级，
核心价值是：

- 让工具栏更符合 macOS 原生设计语言
- 降低中英文切换对按钮宽度的影响
- 用选中态动画提供清晰的"当前工具"反馈

不改变任何业务逻辑，
不影响 OCR / AI / Pin / 复制 / 保存等核心链路。
改动集中在 `CaptureOverlayView` 的工具栏配置和布局两个方法，
以及 `AnnotationTool` 的 symbol 名称映射。
