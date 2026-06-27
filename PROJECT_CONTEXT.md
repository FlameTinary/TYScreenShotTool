# PROJECT_CONTEXT.md

## 项目概览

TShot 是一个面向真实用户持续演进的 macOS 原生截图产品，而不只是练手 Demo。

这是项目的必要上下文文档。
进入开发、评审、规划或 AI 协作前，默认应先阅读本文件，再继续查看 `docs/ROADMAP.md` 和当前 Sprint 文档。

项目当前定位：

- 提供稳定、可用、可验证的截图工作流
- 以原生 macOS 体验为优先，围绕截图后的继续处理展开
- 在真实产品迭代中实践 AI 协作开发、原生 UI、截图、OCR 与后续 AI 工作流

当前阶段：

- 已有正式版本 `v1.0.0`
- 当前处于 `v1.0.0` 之后的持续迭代阶段
- 当前 Sprint 状态以 `docs/ROADMAP.md` 为准

---

## 当前有效产品认知

如果只想快速理解这个项目，先记住下面几件事：

1. 这是一个菜单栏常驻的 macOS 截图工具。
2. 截图不是终点，目标是把“截图后处理”收拢到一条连续工作流里。
3. 当前主要 UI 基线默认推荐 `AppKit + SnapKit`，但后续开发不强制限定为这一组合。
4. 当前普通截图与长截图都已有独立「翻译」入口，默认优先走本地 OCR + 系统本地翻译链路。
5. 文档很多，真正的当前权威入口是 `AGENTS.md`、`PROJECT_CONTEXT.md`、`README.md`、`docs/ROADMAP.md` 和当前 Sprint 文档。

---

## 当前开发状态

当前线上版本：

- `v1.0.0`

当前开发主线：

- 默认开发主线为 `dev`
- 实际工作时以当前 Git 分支为准

当前状态：

- 持续迭代

当前 Sprint：

- Sprint 53 - AI 订阅服务区域化底座
- 详情参考 `docs/ROADMAP.md` 与 `docs/SPRINTS/Sprint-53.md`

当前最高优先级：

- 先完成中国大陆纯本地模式与海外 AI Pro 订阅模式的需求、技术边界和后续 Feature 拆分

---

## 当前技术基线

### 技术栈

- `Swift 6`
- `AppKit`
- `SnapKit`
- `SwiftUI`
- `ScreenCaptureKit`
- `Vision`
- `Translation`
- `UserNotifications`
- `XCTest`

### UI 基线

当前主要 UI 实现以 AppKit 为主，布局常用 SnapKit：

- 应用入口为 `main.swift + AppDelegate`
- App 以 `NSApplication.setActivationPolicy(.accessory)` 方式运行
- 菜单栏入口由 `NSStatusItem` 驱动
- Settings、OCR/AI 结果窗、长截图控制面板、长截图预览窗均为 AppKit 实现
- 本地翻译结果面板使用 AppKit `NSPanel` 承载 SwiftUI 翻译视图

后续开发默认推荐继续使用 `AppKit + SnapKit`，但这不是强限制。
如果评估后 `SwiftUI` 或手动 `frame` 更适合具体场景，也可以按场景选择。

### 架构基线

当前代码结构以职责分层为主：

- `App/`
  - 应用入口、菜单栏、Settings 窗口、热键录制控件
- `Services/`
  - 业务编排与系统能力适配层
- `Features/`
  - 具体功能 UI 与交互视图
- `Shared/`
  - 共享枚举、属性模型、文案与配置模型
- `TYScreenShotToolTests/`
  - 单元测试与测试辅助

最关键的编排核心是 `CaptureSessionService`：

- 负责普通截图与长截图的主流程编排
- 串联 Overlay、截图、OCR、AI、Pin、复制、保存等动作
- 连接多个预览窗与结果窗 service

---

## 当前主链路

### 普通截图流程

全局快捷键

↓

`CaptureOverlayService`

↓

用户悬停窗口确认或自由框选

↓

`CaptureSessionService`

↓

进入编辑态

↓

复制 / 保存 / OCR / 翻译 / AI / Pin / 长截图 / 取消

### 长截图流程

全局快捷键

↓

`CaptureSessionService`

↓

普通截图选区进入长截图模式

↓

`ScrollingCaptureService`

↓

长截图结果态

↓

复制 / 保存 / OCR / 翻译 / AI / 取消

---

## 当前已交付能力

基于现有 `README`、`ROADMAP`、`SPRINTS` 与专项文档，当前仓库对应的产品能力可概括为：

- 菜单栏常驻应用
- 全局截图热键触发
- 悬停窗口后点击确认截图
- 自由拖拽框选截图
- 截图开始即冻结屏幕内容
- 截图完成后进入编辑态，而不是立刻结束
- 编辑态支持复制、保存、取消
- 编辑态支持 OCR、翻译、AI、Pin、长截图入口
- 支持截图区域拖动与缩放微调
- 支持圆角、阴影等预览样式
- 支持矩形、圆形、直线、箭头、画笔、文字、马赛克标注
- 多类标注支持属性面板、选中回显、控制节点和继续修改
- 文字标注支持悬停、选中移动、编辑输入与动态边框
- 标注预览与最终复制/保存导出结果保持一致
- 支持 OCR 结果预览
- 支持本地翻译结果预览，支持复制原文与译文
- 支持 AI 结果预览
- 支持 Pin 悬浮截图窗口
- 支持滚动长截图，以及长截图后的复制、保存、OCR、翻译、AI
- 普通截图与长截图工具栏已使用图标按钮与 Hover Tooltip
- 长截图预览窗口会同时避让选区与工具栏区域
- 支持多语言本地化
- 支持应用外观切换
- 已建立最小 `XCTest` 单元测试基座

---

## 产品边界与注意事项

### 1. AI 能力属于开发者隐藏配置能力

当前 `AI` 入口默认隐藏。Debug Settings 中的开发者 AI 开关只能表达本地调试意图，最终仍由区域策略决定是否显示和是否允许请求。

AI 请求配置仍然不提供完整的公开设置页入口。

它依赖本地 `defaults write` 写入隐藏配置：

- `local.aiAnalysis.baseURL`
- `local.aiAnalysis.openAIAPIKey`
- `local.aiAnalysis.model`

默认面向兼容 OpenAI `Responses API` 的服务，具体配置方式见 `README.md`。

因此后续涉及 AI 的改动时，需要默认理解为：

- AI 不是“开箱即用”的公开设置项
- AI 行为依赖本地开发/使用者自行配置
- `local.aiAnalysis.*` 不能绕过 `AIAvailabilityService` 与区域策略
- 中国大陆模式与 unknown / nil storefront 下，即使写入本地 API Key，也不能发起商业 AI 请求
- AI 链路要特别注意失败回退、无结果语义和人工验证

Sprint 53 起，AI 商业化方向采用区域化策略：

- 中国大陆区保持纯本地截图工具定位
- 中国大陆区不显示 AI 商业入口、登录入口、订阅入口
- 中国大陆区不请求海外后端，不上传截图内容
- 中国大陆区不依赖远程配置打开 AI 商业能力
- 中国大陆以外地区可以规划 AI Pro 订阅能力
- 海外 AI Pro 必须通过后端校验登录、订阅、地区、额度和风控
- 现有本地隐藏 AI 配置后续应收口为开发者 / Debug / 内部验证能力，不能作为正式商业化路径

### 2. 本地翻译不属于 AI 链路

当前「翻译」按钮是独立工具栏入口，默认显示。

本地翻译链路：

- 复用已有 OCR 服务识别截图文字
- 使用 Apple `Translation` 框架执行本地翻译
- 使用独立翻译结果面板展示原文与译文
- 支持复制原文和复制译文
- 不调用 AI 服务，不依赖隐藏 AI 配置

### 3. 命名历史存在 `TShot / SmartShot` 并存记录

历史文档中，Sprint 19 曾将面向用户名称调整为 `SmartShot`。
但当前工程配置、Scheme、`PRODUCT_NAME`、`CFBundleDisplayName`、`PRODUCT_BUNDLE_IDENTIFIER`、`Localizable.xcstrings`、README 和 App Store 文案都仍以 `TShot` / `com.sheldon.TShot` 为当前事实。

因此后续协作时应以“当前工程实际配置”为准，而不是只参考单个 Sprint 历史记录。

### 4. 隐私文档、AI 能力与本地翻译要分开理解

`docs/privacy-policy.md` 主要描述当前上架与默认能力下的隐私声明。
而 `README.md` 同时记录了实验性隐藏 AI 配置与本地翻译能力。

如果后续继续增强 AI 能力，必须同步重新审视：

- 隐私声明
- App Store 文案
- 用户可见设置入口
- 错误提示与用户预期

---

## 关键模块速览

以下模块是后续改动时最常碰到的核心入口：

- `TYScreenShotTool/App/AppDelegate.swift`
  - 应用装配根入口，负责组装 service 和连接回调
- `TYScreenShotTool/Services/CaptureSessionService.swift`
  - 截图业务主编排器
- `TYScreenShotTool/Services/CaptureOverlayService.swift`
  - Overlay 生命周期与视图承载
- `TYScreenShotTool/Features/CaptureOverlay/`
  - 编辑态视图、标注画布、属性面板
- `TYScreenShotTool/Services/ScrollingCaptureService.swift`
  - 长截图抓取核心逻辑
- `TYScreenShotTool/Services/ScrollingCapturePanelService.swift`
  - 长截图控制面板
- `TYScreenShotTool/Services/OCRService.swift`
  - OCR 链路
- `TYScreenShotTool/Services/LocalTranslationService.swift`
  - 本地翻译辅助能力，包括语言兜底判断与错误提示映射
- `TYScreenShotTool/Services/TranslationResultPanelService.swift`
  - 本地翻译结果窗口，使用 AppKit 面板承载 SwiftUI 翻译视图
- `TYScreenShotTool/Services/AIAnalysisService.swift`
  - AI 文本分析链路
- `TYScreenShotTool/Services/AIImageTextExtractionService.swift`
  - AI 视觉取字链路
- `TYScreenShotTool/Features/CaptureOverlay/ToolbarHoverButton.swift`
  - 普通截图与长截图工具栏 hover 反馈按钮
- `TYScreenShotTool/Shared/AppLocalization.swift`
  - 当前语言解析与本地化入口
- `TYScreenShotTool/Shared/AppThemeCoordinator.swift`
  - 外观切换协调器

---

## 测试与验证边界

### 构建、测试、归档脚本

项目要求优先使用仓库脚本，而不是直接手写底层 `xcodebuild`：

- 构建：`./scripts/build.sh`
- 测试：`./scripts/test.sh`
- 归档：`./scripts/archive.sh`

### 当前自动测试定位

当前自动测试主要覆盖：

- 热键模型
- 键名映射
- 本地化语言解析
- 设置常量
- 外观模型
- 本地翻译辅助逻辑与错误提示映射
- 部分共享模型与纯逻辑视图行为

当前自动测试不应被误解为已经覆盖完整产品主链路。
以下内容仍然强依赖人工验证：

- ScreenCaptureKit 截图链路
- OCR 真识别结果
- Apple Translation 框架真实翻译结果与语言包下载行为
- AI 请求与错误语义
- 菜单栏交互
- Settings AppKit 控件交互
- Overlay 与标注画布交互
- OCR / AI 结果窗口 UI
- 长截图完整链路

---

## 开发规范入口

项目开发规范：

- `AGENTS.md`

Git 工作流：

- `GIT_WORKFLOW.md`

---

## 文档地图

项目文档较多，但职责是分层的。

### 当前最重要的权威文档

- `AGENTS.md`
  - 协作规则、工作模式、文档策略、脚本优先原则
- `PROJECT_CONTEXT.md`
  - 项目当前阶段、有效能力、技术基线、协作入口与文档地图
- `README.md`
  - 产品定位、功能概览、技术栈、脚本使用、隐藏 AI 配置
- `docs/ROADMAP.md`
  - 当前阶段、Sprint 状态、已完成能力与后续规划
- `docs/SPRINTS/Sprint-XX.md`
  - 单个 Sprint 的目标、范围、实现、验证与结果

当前 Sprint 文档：

- `docs/SPRINTS/Sprint-53.md`
  - AI 订阅服务区域化底座，包括中国大陆纯本地模式、海外 AI Pro 订阅模式、技术方案、Feature 拆分和验收口径

### 辅助决策文档

- `docs/testing/automated-testing.md`
  - 自动测试范围、边界与推荐运行方式
- `GIT_WORKFLOW.md`
  - 分支模型、提交流程、合并方式、发布流程

### 专项资料文档

- `docs/AppStore/`
  - 上架文案与预览图素材
- `docs/privacy-policy.md`
  - 隐私政策

### 历史过程文档

- `docs/superpowers/specs/`
  - 历史设计文档沉淀
- `docs/superpowers/plans/`
  - 历史实施计划沉淀

这些 `superpowers` 文档很有参考价值，但它们不是所有场景下的当前唯一事实来源。
如果与工程现状冲突，应优先以代码、`AGENTS.md`、`README.md`、`ROADMAP.md` 和当前 Sprint 文档为准。
