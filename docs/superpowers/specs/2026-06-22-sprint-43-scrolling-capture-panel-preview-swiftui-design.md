# Sprint 43 - 长截图控制面板与预览窗口 SwiftUI 化设计文档

## 1. 背景

Sprint 42 已完成 OCR / AI 结果窗口的 SwiftUI 内容层迁移，并明确了当前项目的 UI 实现优先级：

1. 能使用 SwiftUI 表达的界面，优先使用 SwiftUI
2. 必须保留 AppKit 的场景，布局优先使用 SnapKit
3. 只有 SwiftUI 和 SnapKit 都不适合的低层场景，才使用手动 `frame`

当前长截图相关 UI 仍主要由 AppKit 手写内容组成，尤其是：

* `ScrollingCapturePanelService` 中的长截图控制面板
* `ScrollingCapturePreviewWindowService` 中的长截图预览窗口

这两处都属于“用户可见内容明确、系统窗口行为仍需保留”的典型迁移对象，适合作为 Sprint 43 的下一步收口目标。

---

## 2. 本轮目标

本轮目标是将长截图控制面板与长截图预览窗口的**内容层**迁移为 SwiftUI，同时保留现有 AppKit 窗口外壳与坐标控制逻辑。

本轮完成后应达到：

* 长截图控制面板内容层改为 SwiftUI
* 长截图预览窗口内容层改为 SwiftUI
* `AI` 入口从 AppKit `NSMenu` 改为 SwiftUI `Popover`
* 长截图窗口的浅色 / 深色 / 文案 / 间距结构进一步统一
* 长截图预览窗口补齐更清晰的初始态 / 空态 / 信息层表达
* 不改变长截图滚动捕获、拼接与结果窗口反向摆放主链路

---

## 3. 长期规则延续

Sprint 43 继续沿用 Sprint 42 已建立的分层方式：

* **SwiftUI 负责**
  * 用户可见内容
  * 按钮布局
  * 状态表达
  * Popover 菜单
  * 预览区的信息层与空态

* **AppKit 负责**
  * `NSPanel` 外壳
  * 窗口层级
  * 窗口位置与尺寸计算
  * 跨 Space / 全屏辅助行为
  * 预览窗口 `ignoresMouseEvents`
  * 与截图主流程的生命周期衔接

也就是说，本轮追求的是 **SwiftUI 内容化**，而不是 **去掉 AppKit 窗口系统行为**。

---

## 4. 范围

### Included

本轮包含：

* 长截图控制面板内容层 SwiftUI 化
* 长截图预览窗口内容层 SwiftUI 化
* `AI` 菜单改为 SwiftUI `Popover`
* 控制面板按钮禁用态、浅深色、文案与间距收口
* 预览窗口初始态 / 空态 / 信息层表达收口
* 保留现有长截图预览窗口与 OCR / AI 结果窗口的左右联动规则

### Out of Scope

本轮不做：

* 不重写滚动捕获逻辑
* 不重写拼接算法
* 不修改长截图主状态机
* 不修改 OCR / AI 结果窗口业务语义
* 不改变 `attachmentSide` 的对外含义
* 不迁移普通截图工具栏
* 不迁移 Overlay
* 不迁移标注画布

---

## 5. 方案选择

本轮采用 **方案 A：双 service 保留，分别承载各自 SwiftUI 内容**。

即：

* `ScrollingCapturePanelService` 继续负责控制面板窗口
* `ScrollingCapturePreviewWindowService` 继续负责预览窗口
* 两边分别通过 `NSHostingView` 承载 SwiftUI 内容视图
* `AI` 入口在控制面板内部使用 SwiftUI `Popover`

不采用更激进的“统一长截图 UI 协调层”或“重做长截图工作区”的原因：

* 当前项目是单人长期维护项目，应优先保持简单
* 本轮目标是 UI 迁移，而不是架构重组
* 保留现有 service 边界，可以显著降低回归风险

---

## 6. 组件设计

### 6.1 长截图控制面板

保留：

* `ScrollingCapturePanelService`

新增 SwiftUI 视图：

* `ScrollingCaptureControlPanelView`
* `ScrollingCaptureAIPopoverView`

职责划分：

#### `ScrollingCapturePanelService`

继续负责：

* 创建与销毁 `NSPanel`
* 面板位置计算
* 外观刷新注册
* 业务回调桥接：
  * `取消`
  * `OCR`
  * `AI`
  * `保存`
  * `复制`

#### `ScrollingCaptureControlPanelView`

负责：

* `取消 / OCR / AI / 保存 / 复制` 按钮布局
* 按钮禁用态
* 本地化文案显示
* 浅色 / 深色下的统一视觉层级
* `AI` 按钮点击后的 Popover 展示

#### `ScrollingCaptureAIPopoverView`

负责：

* 展示现有 AI 模式：
  * 开发报错分析
  * 摘要总结
  * 界面结构识别
  * 翻译语言
* 翻译语言的二级层级表达
* 触发模式选择闭包

本轮不新增 AI 模式，不修改 AI 触发后的业务流程。

### 6.2 长截图预览窗口

保留：

* `ScrollingCapturePreviewWindowService`

新增 SwiftUI 视图：

* `ScrollingCapturePreviewContentView`

职责划分：

#### `ScrollingCapturePreviewWindowService`

继续负责：

* 创建与复用 `NSPanel`
* 根据 `selectionRect` 和屏幕可见区域计算预览窗位置
* 计算预览尺寸
* 继续维护 `attachmentSide`
* 保持 `panel.ignoresMouseEvents = true`

#### `ScrollingCapturePreviewContentView`

负责：

* 展示当前长图预览内容
* 展示更明确的初始态 / 空态
* 补充轻量信息层
* 统一内边距、圆角内层与视觉层次

本轮不把预览窗口改成可直接交互的编辑区。

---

## 7. 数据流

### 7.1 控制面板数据流

控制面板的数据流保持现有业务编排不变：

1. `CaptureSessionService` 继续设置长截图面板的动作闭包
2. `ScrollingCapturePanelService` 将动作闭包桥接到 SwiftUI 控制面板
3. 用户点击某个按钮后，动作仍回到现有 service / session 逻辑
4. 选择 AI 模式后，继续复用现有 AI 分析主链路

本轮不让 SwiftUI 视图持有截图业务状态机。

### 7.2 预览窗口数据流

预览窗口的数据流同样保持现有主链路不变：

1. 长截图结果更新时，继续调用 `presentOrUpdatePreview(image:selectionRect:)`
2. `ScrollingCapturePreviewWindowService` 继续计算窗口位置与尺寸
3. service 将当前预览图与展示状态传给 SwiftUI 内容视图
4. `attachmentSide` 继续暴露给 OCR / AI 结果窗口摆放逻辑使用

---

## 8. 交互设计

### 8.1 控制面板

本轮不改变按钮语义，只改变表达形式：

* `取消 / OCR / AI / 保存 / 复制` 保持当前顺序
* `OCR` 与 `AI` 的可用性规则保持不变
* `AI` 点击后展示 SwiftUI `Popover`
* `Popover` 中展示的模式集合保持与当前一致
* 模式选择后关闭 `Popover`，并继续走现有 AI 分析流程

### 8.2 预览窗口

预览窗口本轮做“轻交互优化”，但不改核心交互职责：

* 已有长图结果时，主视觉仍是当前预览图
* 暂无有效预览图时，应出现明确的初始态 / 空态，而不是纯空白材质块
* 预览窗口可补充轻量说明性信息层，但不能压过长图本体
* 预览窗口继续不接收鼠标事件，保持辅助显示层定位

---

## 9. 风险与控制

### 风险 1：迁移时误伤长截图主链路

控制：

* 本轮不改滚动捕获逻辑
* 本轮不改拼接算法
* 本轮不改结果图生成链路
* 所有行为改动只限窗口内容层

### 风险 2：AI Popover 改造后触发语义变化

控制：

* 仅替换菜单表现，不替换 AI 模式定义与业务入口
* 保持现有 AI 模式枚举与回调签名
* 保持 loading / result / error 流程不变

### 风险 3：预览窗口内容 SwiftUI 化后左右联动信息丢失

控制：

* `attachmentSide` 继续由 `ScrollingCapturePreviewWindowService` 维护
* OCR / AI 结果窗口仍只依赖这个既有字段，不新增新的联动协议

### 风险 4：外观收口后浅深色下可读性回退

控制：

* 继续使用系统颜色与 SwiftUI 原生控件风格
* 不在 SwiftUI 内容层中额外叠加新的材质背景
* 外壳材质继续由 AppKit `NSVisualEffectView` 负责

---

## 10. 验收标准

1. `./scripts/build.sh` 构建通过
2. 长截图控制面板内容层已迁移为 SwiftUI
3. 长截图预览窗口内容层已迁移为 SwiftUI
4. 长截图控制面板中的 `取消 / OCR / AI / 保存 / 复制` 行为保持不变
5. `AI` 菜单已改为 SwiftUI `Popover`，并支持当前全部模式选择
6. 长截图预览窗口可正确展示当前长图内容
7. 长截图预览窗口在无有效预览内容时可正确展示初始态 / 空态
8. 长截图预览窗口继续保持左右附着与现有 `attachmentSide` 语义
9. OCR / AI 结果窗口与长截图预览窗口的左右联动规则保持不变
10. 长截图继续滚动追加时，预览更新链路保持正常
11. 浅色 / 深色外观下，控制面板与预览窗口均保持可读
12. 长截图主链路、OCR / AI 主链路与现有结果窗口不受影响

---

## 11. 结论

Sprint 43 的目标不是重做长截图系统，而是在 Sprint 42 已经验证可行的分层模式上，继续向长截图相关窗口推进：

* 用户可见内容优先 SwiftUI
* `NSPanel` 外壳与坐标行为继续由 AppKit 承载
* Popover 菜单等普通交互尽量回到 SwiftUI 表达
* 业务主链路保持稳定，不为 UI 迁移引入架构级重写

如果本轮完成，TShot 的长截图相关窗口将形成一条更一致的 SwiftUI-first 路径，为后续属性面板或其他普通窗口迁移提供参考。
