# Sprint 45 - 纯 AppKit + SnapKit UI 迁移设计文档

## 1. 背景

当前项目的 UI 已形成明显的混合结构：

1. 应用入口、菜单栏、Settings 等部分使用 SwiftUI
2. OCR / AI 结果窗口、长截图控制面板、长截图预览窗口采用 `AppKit` 外壳 + `SwiftUI` 内容层
3. 截图 Overlay、画布、窗口层级、热键、浮窗行为等底层能力仍由 `AppKit` 主导

这套混合架构在阶段性演进中是合理的，但对当前项目的长期维护不再是最优解。

原因有三点：

* 该项目是重度依赖 macOS 原生窗口、事件与面板行为的菜单栏工具
* 当前大多数系统级能力本来就必须回到 `AppKit`
* 在继续保留 `SwiftUI` 内容层的情况下，项目会长期承受 `NSHostingView`、`NSHostingController`、`NSViewRepresentable`、`@AppStorage` 双技术体系并存的复杂度

因此，本轮不再延续 “SwiftUI-first” 方向，而是将 UI 技术栈彻底收口为纯 `AppKit + SnapKit`。

---

## 2. 本轮目标

本轮目标是在一个 Sprint 中一次性完成当前项目全部 SwiftUI UI 的移除与替换。

本轮完成后应达到：

* 仓库业务代码中不再保留 `SwiftUI` 依赖
* 不再保留 `NSHostingView`、`NSHostingController`、`NSViewRepresentable`
* 应用入口改为纯 `AppKit` 菜单栏应用
* Settings、OCR 结果窗、AI 结果窗、长截图控制面板、长截图预览窗全部改为纯 `AppKit` 实现
* 普通截图、OCR、AI、Pin、长截图、主题、本地化、设置存储等现有业务能力继续可用
* UI 布局规则统一为：普通界面优先 `SnapKit`，只有窗口定位、绘制、Overlay 这类低层场景才继续使用必要的手动 `frame`

---

## 3. 范围

### Included

本轮包含：

* `SwiftUI App` 入口改为 `AppDelegate` 入口
* 菜单栏从 `MenuBarExtra` 改为 `NSStatusItem + NSMenu`
* `SettingsView` 改为 `NSWindowController + NSViewController`
* 热键录制从 `NSViewRepresentable` 桥接改为原生 `AppKit` 输入控件
* OCR 结果窗内容层改为纯 `AppKit`
* AI 结果窗内容层改为纯 `AppKit`
* 长截图控制面板内容层改为纯 `AppKit`
* 长截图 `AI` 菜单从 SwiftUI `Popover` 改回纯 `AppKit`
* 长截图预览窗口内容层改为纯 `AppKit`
* 移除业务代码中的 `SwiftUI`、`NSHostingView`、`NSHostingController`、`@AppStorage`
* 更新当前有效规则与当前 Sprint 文档口径为 `AppKit + SnapKit`

### Out of Scope

本轮不做：

* 不重写截图主状态机
* 不重写 OCR / AI 请求链路
* 不重写长截图拼接算法
* 不重做 Overlay 与标注画布的已有 `AppKit` 结构
* 不改动无关服务层职责边界
* 不篡改历史 Sprint 已发生事实，只更新当前有效规则和当前 Sprint 结果

---

## 4. 方案选择

### 方案 A：继续保留混合架构，只减少部分 SwiftUI

优点：

* 改动最小
* 可快速落地部分纯化工作

缺点：

* 无法满足“彻底纯 AppKit”的目标
* `SwiftUI` / `AppKit` 双体系复杂度仍长期存在
* 会留下大量过渡结构

结论：

* 不采用

### 方案 B：分两阶段迁移，阶段内允许临时混合

优点：

* 每阶段风险较可控
* 实施过程更平滑

缺点：

* 中间态会持续一段时间
* 与用户要求的“一次性全部改掉”不一致
* 文档、工程、验证要经历两次收口

结论：

* 不采用

### 方案 C：一个 Sprint 内一次性迁移为纯 AppKit + SnapKit

优点：

* 最符合本轮目标
* 最终代码结构最统一
* 后续维护路径清晰

缺点：

* 改动面最大
* 需要更严格的编译与人工回归验证

结论：

* 采用方案 C

---

## 5. 目标架构

本轮完成后的 UI 架构统一为纯 `AppKit + SnapKit`。

分层规则如下：

* **AppKit 负责**
  * 应用入口与生命周期
  * 菜单栏状态项与菜单
  * `NSPanel` / `NSWindow` 外壳
  * 结果窗、面板、预览窗内容视图
  * 热键录制输入控件
  * 事件响应、first responder、窗口激活与层级控制
  * 浅色 / 深色刷新时的原生控件表现

* **SnapKit 负责**
  * Settings 页面布局
  * 结果窗内部布局
  * 长截图控制面板内部布局
  * 长截图预览窗口内部布局
  * 其他普通内容视图的约束布局

* **手动 `frame` / `draw` 保留在**
  * Overlay 选区与标注画布
  * 窗口定位与尺寸计算
  * 必须逐像素控制的绘制逻辑

本轮不再保留任何“AppKit 外壳 + SwiftUI 内容层”的桥接结构。

---

## 6. 组件设计

### 6.1 应用入口与菜单栏

替换关系：

* 下线 `TYScreenShotToolApp.swift`
* 下线 `MenuBarContentView.swift`
* 新增 `AppDelegate`
* 新增菜单栏控制器或状态项协调器

职责划分：

#### `AppDelegate`

负责：

* 初始化原有服务对象
* 建立回调链路
* 创建菜单栏状态项
* 响应设置打开、退出应用、触发截图等入口动作

#### 菜单栏控制器

负责：

* 创建 `NSStatusItem`
* 配置 `NSMenu`
* 绑定菜单项行为
* 刷新菜单文本本地化

本轮不改变菜单栏可用能力，只改变承载方式。

### 6.2 Settings

替换关系：

* 下线 `SettingsView.swift`
* 下线 `HotKeyRecorderField.swift`
* 调整 `SettingsOpenCoordinator.swift`
* 新增 `SettingsWindowController`
* 新增 `SettingsViewController`
* 新增原生热键录制控件

职责划分：

#### `SettingsOpenCoordinator`

继续负责：

* 统一对外暴露“打开设置”能力

改为负责：

* 协调 `NSWindowController`
* 避免重复创建多个设置窗口

#### `SettingsViewController`

负责：

* 快捷键设置区
* 语言设置区
* 外观设置区
* AI 视觉取字设置区
* 保存目录选择区
* 基于 `UserDefaults` 的值回显与变更提交

#### 热键录制控件

负责：

* 捕获 `keyDown`
* 捕获 `flagsChanged`
* 点击外部取消
* `Return` 确认
* `Esc` 取消
* 高亮录制态

本轮不再通过 `NSViewRepresentable` 包装 `NSTextField`。

### 6.3 OCR / AI 结果窗口

替换关系：

* 下线 `OCRPreviewView.swift`
* 下线 `AIAnalysisPreviewView.swift`
* 保留 `OCRPreviewWindowService.swift`
* 保留 `AIAnalysisPreviewWindowService.swift`
* 将两者改为直接安装原生 `NSView` 内容

职责划分：

#### 结果窗口 service

继续负责：

* `NSPanel` 创建与复用
* 窗口位置计算
* 生命周期与关闭行为
* 与主截图流程衔接
* 主题刷新

#### AppKit 内容视图

负责：

* 标题、正文、滚动区、按钮区布局
* 空结果与错误态展示
* 窄宽度下按钮换行或纵向排布

本轮保留现有窗口语义，不改变复制、重试、关闭等行为。

### 6.4 长截图控制面板与 AI 菜单

替换关系：

* 下线 `ScrollingCaptureControlPanelView.swift`
* 下线 `ScrollingCaptureAIPopoverView.swift`
* 保留 `ScrollingCapturePanelService.swift`
* service 改为直接承载 AppKit 内容视图

职责划分：

#### `ScrollingCapturePanelService`

继续负责：

* `NSPanel` 创建与销毁
* 面板尺寸测量与位置计算
* 与截图主会话的动作闭包桥接

#### 控制面板内容视图

负责：

* `取消 / OCR / AI / 保存 / 复制` 按钮布局
* 按钮禁用态
* 浅深色表现
* `AI` 菜单弹出

#### AppKit AI 菜单

负责：

* 展示开发报错分析、摘要总结、界面结构识别、翻译语言
* 触发对应模式回调

本轮不新增 AI 模式，只恢复为纯 `AppKit` 触发方式。

### 6.5 长截图预览窗口

替换关系：

* 下线 `ScrollingCapturePreviewContentView.swift`
* 保留 `ScrollingCapturePreviewWindowService.swift`
* service 改为直接承载 AppKit 内容视图

职责划分：

#### `ScrollingCapturePreviewWindowService`

继续负责：

* `NSPanel` 创建与复用
* 位置与尺寸计算
* `attachmentSide` 维护
* `ignoresMouseEvents` 维持

#### 预览内容视图

负责：

* 初始态 / 空态 / 预览图展示
* 轻量信息层
* 图片展示与裁切策略

本轮不把预览窗口改成交互式编辑面板。

---

## 7. 数据流与状态管理

本轮不新建全局 UI 状态系统。

数据流原则：

* 原有业务 service 继续作为状态源
* AppKit view / view controller 只负责展示和事件回调
* 设置页通过 `UserDefaults` 读写持久化值
* UI 更新通过显式刷新方法、控件回显和原有回调链完成

各块数据流如下：

### 7.1 菜单栏与应用入口

1. `AppDelegate` 初始化服务
2. 菜单项动作回到协调器或 service
3. 热键触发后仍由现有截图会话开始主流程

### 7.2 Settings

1. 打开设置时读取 `UserDefaults`
2. 控件修改后立即写回持久化
3. 热键、外观等需要即时生效的设置继续调用现有 service / coordinator 刷新

### 7.3 OCR / AI 结果窗

1. `CaptureSessionService` 继续驱动结果窗展示
2. 窗口 service 继续计算 panel frame
3. service 将结果数据传给 AppKit 内容视图
4. 视图按钮回调仍回到既有业务闭包

### 7.4 长截图 UI

1. `CaptureSessionService` 继续驱动控制面板与预览窗更新
2. 各 window service 继续负责窗口级控制
3. AppKit 内容视图只处理按钮点击与界面刷新

---

## 8. 错误处理与兼容策略

### 8.1 热键录制失败

* 保持当前已有策略：注册失败恢复旧热键并给出明确提示
* 设置页控件展示错误文案，不让 UI 状态与真实热键状态脱节

### 8.2 保存目录选择失败或权限无效

* 延续当前目录选择和 bookmark 恢复逻辑
* 仅替换界面层，不改动底层保存策略

### 8.3 OCR / AI 空结果

* 保持当前空结果提示语义
* 不因为视图迁移改变文案或关闭行为

### 8.4 长截图窗口刷新异常

* service 仍是唯一窗口控制源
* 避免在视图层自行计算窗口尺寸和摆放
* 内容层只返回自然布局结果，由 service 统一决定 panel size 与 frame

---

## 9. 风险与应对

### 风险 1：菜单栏应用入口替换后启动或激活行为回归

应对：

* 保留现有服务初始化顺序
* 在 `AppDelegate` 中显式设置状态项、前台激活与热键触发回调
* 优先验证“启动后常驻菜单栏”和“热键触发截图”两条主链路

### 风险 2：Settings 从 SwiftUI 改为 AppKit 后即时回显和持久化失效

应对：

* 使用显式读写 `UserDefaults`
* 关键设置项改动后立即调用现有刷新逻辑
* 保持字段命名和存储 key 不变，避免迁移数据

### 风险 3：结果窗和长截图面板去掉 `NSHostingView` 后尺寸表现变化

应对：

* 所有普通内容布局统一交给 `SnapKit`
* 保留现有窗口最小 / 最大尺寸策略
* 对按钮区换行与滚动区高度做显式约束

### 风险 4：一次性迁移范围过大导致局部修复拖累整体节奏

应对：

* 坚持“保留 service，替换内容层和入口层”的边界
* 不借机重构无关业务模块
* 每替换一块即构建验证，最后再做整体人工回归

---

## 10. 验证标准

本轮完成必须满足以下验证：

1. 项目构建通过
2. 仓库业务代码中不再存在 `import SwiftUI`
3. 仓库业务代码中不再存在 `NSHostingView`
4. 仓库业务代码中不再存在 `NSHostingController`
5. 仓库业务代码中不再存在 `NSViewRepresentable`
6. 菜单栏应用可正常启动并显示状态项
7. 打开 Settings 正常，且以下设置可真实生效：
   * 热键
   * 保存目录
   * AI 视觉取字
   * 语言
   * 外观
8. 普通截图主链路可用：
   * 截图
   * 复制
   * 保存
   * OCR
   * AI
   * Pin
9. 长截图主链路可用：
   * 进入长截图
   * 预览显示
   * OCR
   * AI
   * 保存
   * 复制
   * 取消
10. OCR / AI 结果窗口位置与交互语义保持不变

---

## 11. 受影响文件方向

### 重点替换

* `TYScreenShotTool/App/TYScreenShotToolApp.swift`
* `TYScreenShotTool/App/MenuBarContentView.swift`
* `TYScreenShotTool/App/SettingsView.swift`
* `TYScreenShotTool/App/SettingsOpenCoordinator.swift`
* `TYScreenShotTool/App/HotKeyRecorderField.swift`
* `TYScreenShotTool/Features/Preview/OCRPreviewView.swift`
* `TYScreenShotTool/Features/Preview/AIAnalysisPreviewView.swift`
* `TYScreenShotTool/Features/ScrollingCapture/ScrollingCaptureAIPopoverView.swift`
* `TYScreenShotTool/Features/ScrollingCapture/ScrollingCaptureControlPanelView.swift`
* `TYScreenShotTool/Features/ScrollingCapture/ScrollingCapturePreviewContentView.swift`
* `TYScreenShotTool/Services/OCRPreviewWindowService.swift`
* `TYScreenShotTool/Services/AIAnalysisPreviewWindowService.swift`
* `TYScreenShotTool/Services/ScrollingCapturePanelService.swift`
* `TYScreenShotTool/Services/ScrollingCapturePreviewWindowService.swift`
* `TYScreenShotTool.xcodeproj/project.pbxproj`

### 需要同步的当前有效文档

* `AGENTS.md`
* `README.md`
* `docs/ROADMAP.md`
* `docs/DEVLOG.md`
* 当前 Sprint 文档

---

## 12. 完成定义

当且仅当以下条件全部满足时，本轮才算完成：

* 纯 `AppKit + SnapKit` UI 技术栈已经落地
* 业务功能无关键回归
* 工程可构建
* 当前规则文档已同步
* 不再依赖 SwiftUI 作为任何业务 UI 的实现手段

本轮的核心不是“把界面看起来改对”，而是把项目的 UI 技术方向彻底收口为单一可维护体系。
