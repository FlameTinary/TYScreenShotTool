# 工具栏文字改为 SF Symbols 设计文档

## 1. 背景

当前 `CaptureOverlayView` 中的工具栏按钮（标注工具 + 功能按钮）全部使用纯文字展示，
存在以下问题：

- 视觉信息密度不够，按钮宽度受文字长度影响（中英文切换更明显）
- 缺乏 macOS 原生截图工具的视觉语言
- 工具栏整体显得拥挤，与截图画面的对比度不突出

随着 Sprint 38 完成 App 本地化，
工具栏文案已经从 String Catalog 取值，
但"纯文字"的呈现方式仍然是主要的视觉瓶颈。

本轮将工具栏改为 SF Symbols 图标展示，
保持功能完全不变，只做视觉升级。

---

## 2. 本轮目标

本轮只改工具栏，不动其他功能。

具体目标：

- `CaptureOverlayView` 的工具栏所有按钮由文字改为 SF Symbols 图标
- 标注工具选中态使用 `.variableColor` configuration，选中切换时播放 `.drawOn.wholeSymbol` 动画
- 功能按钮（撤销 / 长截图 / OCR / AI / Pin / 复制 / 保存 / 取消）不做选中态动画
- 所有按钮统一宽度 36pt，保持工具栏视觉对齐
- 工具栏容器保持现有 `NSVisualEffectView(material: .hudWindow)` + 圆角 12
- 不修改拖拽选区、标注绘制、OCR / AI / Pin / 复制 / 保存等核心逻辑
- 不新增依赖，不引入第三方库

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
- 标注工具选中态：`.variableColor` configuration + `.drawOn.wholeSymbol` 动画
- 工具栏布局：统一按钮宽度 36pt，保持现有间距和容器样式
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
- `bezelStyle = .texturedRounded` + `.borderless`
- `preferredSymbolConfiguration = .init(pointSize: 24)`
- 每个按钮的 `image` 由 SF Symbol 名称构造
- 按钮统一 frame 宽度 36pt

不采用 SwiftUI + NSHostingView，
原因是：
- 当前 `CaptureOverlayView` 完全基于 AppKit，改动范围最小
- `.borderless` + SF Symbol 的原生效果最符合 macOS 设计规范
- 无需为图标单独引入 SwiftUI 层

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
- `.variableColor` configuration（从描边变填充色调）
- 切换时播放动画：`.symbolEffect(.drawOn.wholeSymbol, options: .nonRepeating)`
- 取消选中：切回默认 symbol configuration，不播动画

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

### 5.3 按钮样式参数

统一参数：

- **bezelStyle**：`.texturedRounded` + `.borderless`
- **imageScaling**：`.scaleProportionallyUpOrDown`
- **preferredSymbolConfiguration**：`.init(pointSize: 24, weight: .regular)`
- **frame**：`NSRect(x: 0, y: 0, width: 36, height: 36)`
- **toolTip**：对应中文功能名（矩形 / 椭圆 / 箭头 / 画笔 / 马赛克 / 文字 / 撤销 / 长截图 / OCR / AI / Pin / 复制 / 保存 / 取消）

原因：
- 24pt 符号在 36pt 按钮内有足够呼吸空间
- 36pt 方型按钮比文字按钮更统一
- `.texturedRounded` 配合 `.hudWindow` 视觉效果与 macOS 原生截图工具最接近

### 5.4 标注工具选中态实现

选中态通过更新按钮的 symbol configuration 实现：

- 未选中：`.init(pointSize: 24, weight: .regular)`
- 选中：`.init(pointSize: 24, weight: .bold)` + `.variableColor`
- 选中切换时调用 `button.addSymbolEffect(.drawOn, options: .nonRepeating)`
- 取消选中：切回 default configuration，不播动画

`updateAnnotationToolSelection()` 方法的调用时机不变，
仅在内部更新 symbol configuration。

### 5.5 工具栏布局调整

由于按钮从文字自动宽度改为固定 36pt 方型，
需要调整 `toolbarContainerView` 的自动布局：

- **按钮宽度**：统一 36pt（取代原来自适应文字宽度）
- **按钮间距**：保持现有 12pt
- **容器内边距**：保持现有 12pt
- **容器位置**：保持现有 24pt 边距规则

容器宽度 = 12 * 2 + 36 * 14 + 12 * 13 ≈ 444pt，
比原文字工具栏更紧凑。

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

## 6. 需要改动的模块

### 6.1 `CaptureOverlayView`

这是本轮的核心改动点。

涉及的私有方法/属性：
- `configureToolbar()` — 重构按钮创建逻辑，使用 SF Symbol 替代文字
- `layoutPreviewInterface()` — 调整工具栏按钮尺寸计算
- `updateAnnotationToolSelection()` — 新增选中态 symbol configuration 切换逻辑
- 新增属性：
  - `private let defaultSymbolConfig = NSImage.SymbolConfiguration(pointSize: 24, weight: .regular)`
  - `private let selectedSymbolConfig = NSImage.SymbolConfiguration(pointSize: 24, weight: .bold).applying(.variableColor)`

不改动的方法：
- 所有标注绘制 / undo / 保存 / 复制 / OCR / AI 的业务逻辑
- 拖拽选区处理
- 顶部浮层

### 6.2 `AnnotationTool`

新增一个计算属性用于返回对应 SF Symbol 名称：
- `var symbolName: String { get }`

不改动 `title` 和 `rawIdentifier`。

---

## 7. 运行时行为

### 场景 1：打开截图进入编辑态

工具栏显示 14 个 SF Symbol 图标，
全为默认配置，未选中任何标注工具。

### 场景 2：点击标注工具（如矩形）

- 该按钮切换为 `.variableColor` 配置（填充/颜色变化）
- 播放 `.drawOn.wholeSymbol` 动画
- 其他标注工具保持默认配置
- `CaptureAnnotationCanvasView` 的当前工具切换逻辑不变

### 场景 3：点击其他标注工具（如从矩形切到椭圆）

- 原按钮切回 default configuration，无动画
- 新按钮切到 `.variableColor` 并播放 `.drawOn.wholeSymbol` 动画

### 场景 4：再次点击同一标注工具取消

- 该按钮切回 default configuration
- 不播动画

### 场景 5：点击功能按钮（如 AI / 保存 / 复制）

- 仅触发原有 action
- symbol configuration 保持 default，不切换
- 不播动画

### 场景 6：AI 按钮禁用态

- 当 `isEnabled = false` 时，
  macOS 自动将 SF Symbol 渲染为灰度/半透明
- 无需额外代码处理

---

## 8. 验收标准

1. `CaptureOverlayView` 进入编辑态后，工具栏所有按钮显示为 SF Symbols 图标，不再显示文字
2. 14 个按钮统一尺寸 36pt x 36pt，布局整齐对齐
3. 标注工具点击选中后：
   - 视觉上有明显颜色变化（`.variableColor`）
   - 播放 `.drawOn.wholeSymbol` 动画一次
   - 再次点击同一按钮取消选中，无动画
4. 功能按钮（撤销 / 长截图 / OCR / AI / Pin / 复制 / 保存 / 取消）点击后不改变图标，不播动画
5. hover 每个按钮显示中文 Tooltip
6. 截图主链路（框选 → 标注 → 复制 / 保存 / OCR / AI / Pin / 长截图）全部正常工作
7. `./scripts/build.sh` 构建通过
8. 不引入新的第三方依赖

---

## 9. 风险与约束

### 风险 1

部分 SF Symbol 在某些 macOS 版本上可能不存在或渲染有差异。

应对：
- 使用 macOS 14+ 普遍支持的基础符号
- 如果某个 symbol 在编译时不可用，
  回退到备选 symbol（如 `square.fill` 替代 `square.grid.3x3.topleft.filled`）

### 风险 2

`.variableColor` symbol configuration 在某些 SF Symbol 上的视觉效果可能不明显。

应对：
- 实现后人工验证每个标注工具的选中态视觉
- 如果某个 symbol 的 `.variableColor` 效果不理想，
  临时改用 `.palette` configuration 或简单增大 weight

### 风险 3

`addSymbolEffect(.drawOn, options: .nonRepeating)` 在 macOS 15 上的可用性需要确认。

应对：
- 如果 API 不可用，
  回退到 `NSAnimationContext` + `scale` 动画实现轻量放大回弹效果

### 风险 4

从文字按钮切换为图标按钮后，工具栏整体宽度变化可能影响其在大屏 / 小屏的居中位置。

应对：
- `layoutPreviewInterface()` 中只调整按钮 frame 计算，
  容器位置的 margin 规则保持不变

---

## 10. 结论

本轮是一次纯粹的视觉升级，
核心价值是：

- 让工具栏更符合 macOS 原生设计语言
- 降低中英文切换对按钮宽度的影响
- 用选中态动画提供清晰的"当前工具"反馈

不改变任何业务逻辑，
不影响 OCR / AI / Pin / 复制 / 保存等核心链路。
改动集中在 `CaptureOverlayView` 的工具栏配置和布局两个方法，
以及 `AnnotationTool` 的 symbol 名称映射。
