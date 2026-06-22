# Sprint 42 - 结果窗口 SwiftUI 化与 AppKit 布局规范设计文档

## 1. 背景

TShot 当前已经以 SwiftUI 作为主要界面技术方向，但项目中仍存在较多 AppKit 界面实现。

其中一部分 AppKit 是合理且必要的，例如全屏截图 Overlay、窗口层级控制、鼠标事件、鼠标穿透、标注画布绘制、全局热键和 ScreenCaptureKit 周边处理。
这些能力与 macOS 底层窗口和事件模型绑定较深，不适合作为第一阶段 SwiftUI 迁移目标。

另一部分 AppKit 则主要承担普通界面展示与按钮布局，例如 OCR 结果窗口、AI 结果窗口、长截图控制面板和矩形属性面板。
这类 UI 更适合使用 SwiftUI 表达，也更符合项目后续可维护方向。

本轮 Sprint 42 先聚焦风险最低、边界最清楚的结果窗口：

* OCR 结果窗口
* AI 结果窗口

## 2. 长期规则

后续 UI 开发遵循以下优先级：

1. 能使用 SwiftUI 表达的界面，优先使用 SwiftUI
2. 不能使用 SwiftUI、必须保留 AppKit 的地方，AppKit 布局优先使用 SnapKit
3. SwiftUI 和 SnapKit 都不适合的低层场景，才使用手动 `frame` 布局

SwiftUI 主要负责用户可见内容。
AppKit 主要负责窗口、事件、绘制、系统能力和 SwiftUI 难以稳定控制的 macOS 原生行为。

SnapKit 不用于替代 SwiftUI。
SnapKit 只用于必须保留 AppKit 的布局代码，例如 AppKit 窗口外壳中嵌入 `NSHostingView` 时的贴边约束，或无法迁移到 SwiftUI 的 AppKit 容器布局。

SwiftUI 内容层默认保持透明。
结果窗口的材质背景、边框和窗口外观继续由现有 AppKit `NSVisualEffectView` 外壳负责。

## 3. 本轮目标

将 OCR / AI 结果窗口的内容层迁移为 SwiftUI，同时保留现有 AppKit 窗口外壳。

目标是：

* 保持当前 OCR / AI 结果窗口的用户行为不变
* 保持 OCR 结果内容仍可选中
* 使用 SwiftUI 重写结果窗口内部可见内容
* 保留 `NSPanel` 的窗口定位、层级、关闭和多屏摆放逻辑
* 对仍必须存在的 AppKit 布局使用 SnapKit
* 不引入额外材质背景，保持现有结果窗口视觉风格
* 为后续长截图面板、属性面板、工具栏 SwiftUI 化建立模式

## 4. 范围

### Included

本轮包含：

* 确认 SnapKit 已正确链接到 App target
* 新增 SwiftUI OCR 结果视图
* 新增 SwiftUI AI 结果视图
* 改造 `OCRPreviewWindowService`
  * 保留 `NSPanel`
  * 保留左右摆放逻辑
  * 使用 `NSHostingView` 承载 SwiftUI 内容
* 改造 `AIAnalysisPreviewWindowService`
  * 保留 `NSPanel`
  * 保留 loading / error / result 三态入口
  * 保留左右摆放和按钮回调语义
  * 使用 `NSHostingView` 承载 SwiftUI 内容
* AppKit 外壳布局使用 SnapKit
* 保持普通截图与长截图中的 OCR / AI 结果窗口行为一致

### Out of Scope

本轮不做：

* 不迁移截图 Overlay 底层窗口
* 不迁移标注画布
* 不迁移底部截图工具栏
* 不迁移顶部样式栏
* 不迁移长截图控制面板
* 不迁移矩形属性面板
* 不重写 `CaptureSessionService` 的业务编排
* 不改变 OCR / AI 的输入链路
* 不改变 AI prompt、模型配置或网络请求结构
* 不调整窗口视觉风格，只做技术实现迁移

## 5. 推荐方案

采用“SwiftUI 内容视图 + AppKit 窗口外壳”的方案。

AppKit 继续负责：

* `NSPanel` 创建
* 窗口层级
* 选区左右侧摆放
* 多屏可见区域计算
* 关闭窗口
* 嵌入 SwiftUI 内容

SwiftUI 负责：

* 文本展示
* 滚动区域
* loading 状态
* error 状态
* result 状态
* 按钮布局
* 空态和禁用态

这样可以在不扰动截图主链路的前提下，把普通展示 UI 迁移到 SwiftUI。

## 6. 代码职责设计

### OCR 结果窗口

新增 SwiftUI 视图：

* `OCRPreviewView`

职责：

* 展示窗口标题
* 展示 OCR 文本或空态
* 根据文本是否为空控制复制按钮可用状态
* 提供 `复制` 与 `取消` 操作

保留服务：

* `OCRPreviewWindowService`

职责：

* 创建和复用 `NSPanel`
* 计算窗口尺寸
* 计算左右摆放位置
* 创建 `NSHostingView<OCRPreviewView>`
* 通过 SnapKit 将 hosting view 固定到容器边缘

### AI 结果窗口

新增 SwiftUI 视图：

* `AIAnalysisPreviewView`

职责：

* 根据状态展示 loading / error / result
* result 状态下展示 `AIAnalysisResult.sections`
* 展示 `复制全部`
* 展示 mode 对应的二级复制按钮
* 展示 `重试` 与 `关闭`
* 保持按钮回调语义与当前实现一致

保留服务：

* `AIAnalysisPreviewWindowService`

职责：

* 创建和复用 `NSPanel`
* 提供 `presentLoading`
* 提供 `presentResult`
* 提供 `presentError`
* 计算窗口尺寸和摆放方向
* 创建 `NSHostingView<AIAnalysisPreviewView>`
* 通过 SnapKit 将 hosting view 固定到容器边缘

## 7. 数据流

OCR 数据流保持不变：

1. `CaptureSessionService` 调用 OCR
2. OCR 成功后调用 `OCRPreviewWindowService.present(...)`
3. service 创建 SwiftUI 内容视图
4. 用户点击复制或取消
5. callback 回到 `CaptureSessionService`

AI 数据流保持不变：

1. `CaptureSessionService` 发起 AI 分析
2. 分析开始时调用 `presentLoading`
3. 成功时调用 `presentResult`
4. 失败时调用 `presentError`
5. 用户点击复制、重试或关闭
6. callback 回到 `CaptureSessionService`

本轮不改变业务状态来源，只替换结果窗口内部 UI 表达方式。

## 8. AppKit 与 SnapKit 规则

本轮允许保留 AppKit 的窗口外壳。

必须使用 SnapKit 的地方：

* `NSHostingView` 添加到 AppKit container 后的边缘约束
* 仍需 AppKit container 承载内容时的固定尺寸或贴边布局

允许继续使用 `setFrame` 的地方：

* `NSPanel` 自身定位
* 全屏 Overlay 窗口尺寸
* 需要基于屏幕坐标精确摆放窗口的场景

本轮不要求清理所有历史 `frame` 布局。
只要求 Sprint 42 触及到的 AppKit 内容布局遵守新规则。

## 9. 错误处理

OCR 错误处理保持现有行为：

* OCR 失败时显示 Toast
* OCR 空结果在窗口内显示空态并禁用复制
* 取消 OCR 结果窗不退出截图编辑态

AI 错误处理保持现有行为：

* loading 状态可关闭
* error 状态展示错误信息
* error 状态支持重试与关闭
* 无有效内容时继续走现有 Toast 或关闭策略

本轮不新增错误类型。

## 10. 验收标准

1. `./scripts/build.sh` 构建通过
2. SnapKit 可在 App target 中正常 `import`
3. 普通截图 OCR 结果窗口可正常显示，文本仍可选中，并且复制与取消行为保持不变
4. 长截图 OCR 结果窗口可正常显示，文本仍可选中，并且复制与取消行为保持不变
5. 普通截图 AI 在开发报错分析、摘要总结、界面结构识别、翻译模式下都可正常显示
6. 长截图 AI 在至少一个多 section 模式和一个单 section 模式下都可正常显示
7. AI loading / result / error 三态行为保持不变
8. AI 复制全部、模式对应的二级复制、重试、关闭行为保持不变
9. OCR / AI 结果窗口继续根据选区左右空间摆放
10. 结果窗口迁移后不引入额外材质背景，视觉风格保持与现有 AppKit 外壳一致
11. 本轮不影响截图 Overlay、标注画布、工具栏、长截图捕获主链路

## 11. 风险与控制

### 风险 1：SwiftUI 内容高度与现有窗口尺寸不一致

控制：

* 本轮保留 service 侧窗口尺寸计算
* SwiftUI 内容使用固定外层尺寸适配现有 panel
* 不在本轮引入动态高度窗口

### 风险 2：AppKit 与 SwiftUI 外观切换不同步

控制：

* service 创建窗口后继续应用现有 `AppThemeCoordinator`
* SwiftUI 内容使用系统颜色与 SwiftUI 原生控件
* SwiftUI 内容层不单独增加材质背景
* 保持现有浅色 / 深色人工验证

### 风险 3：按钮回调语义改变

控制：

* SwiftUI View 不直接处理业务状态
* 所有业务动作仍通过闭包回到现有 service / session
* 迁移前后保持 callback 名称和触发时机一致

## 12. 结论

Sprint 42 不追求全项目 SwiftUI 化。

本轮目标是建立可持续迁移模式：

* 普通用户可见内容优先 SwiftUI
* 必须保留 AppKit 的窗口和系统能力继续 AppKit
* AppKit 布局优先 SnapKit
* 低层坐标和窗口定位场景才使用 `frame`

OCR / AI 结果窗口是第一组迁移对象，风险可控，也能为后续长截图控制面板、矩形属性面板和截图工具栏的 SwiftUI 化提供参考。
