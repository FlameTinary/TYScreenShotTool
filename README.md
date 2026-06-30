# TShot

一个用于学习 macOS 原生开发和 AI 辅助开发流程的个人项目。

---

## 项目目标

TShot 不是为了替代现有截图软件。

项目主要用于：

* 学习 macOS 开发
* 实践 macOS AppKit 开发（AppKit + SnapKit）
* 熟悉 ScreenCaptureKit
* 探索 AI 编程工作流
* 构建个人效率工具

未来将逐步扩展为：

AI Screenshot Assistant

即：

截图 → 编辑工具栏 → 标注 / OCR / AI分析 → 输出结果

---

## 开发路线图

说明：

- 下面这一节描述的是能力演进里程碑，不等同于真实发布版本号
- 真实版本号以 git tag 为准
- 当前仓库中已存在的正式 tag：
  - `v0.1.0`
  - `v0.2.0`
  - `v1.0.0`

### 里程碑 1

基础截图功能

功能：

* 菜单栏应用
* 全局快捷键
* 框选截图
* 保存 PNG
* 保存到桌面
* 自动复制到剪贴板

---

### 里程碑 2

OCR

功能：

* 图片文字识别

---

### 里程碑 3

设置增强

功能：

* HotKey 配置
* 保存目录配置

---

### 里程碑 4

截图编辑工作流

功能：

* 框选完成后进入截图编辑态
* 底部工具栏
* 手动复制或保存
* 顶部悬浮设置栏

---

### 里程碑 5

标注能力

功能：

* 矩形
* 圆形
* 直线
* 箭头
* 画笔
* 文字
* 马赛克
* 截图区域微调

---

### 里程碑 6

截图动作与反馈体验

功能：

* OCR 入口迁移到工具栏
* Pin 固定截图
* OCR / 复制 / 保存提示反馈
* Pin 浮动窗口增强

---

### 里程碑 7

滚动长截图

功能：

* 支持滚动区域捕获
* 生成长图结果

---

### 里程碑 8

AI 分析

功能：

* 基于截图区域 OCR 文本发起 AI 分析
* 面向开发报错场景输出简要解释
* 在编辑态侧边面板中展示结果
* 支持复制、重试、关闭

---

### v1.0.0

首个正式版本 tag

说明：

- `v1.0.0` 已经在 git tag 中存在
- 因此上面的 `里程碑 1 ~ 8` 应理解为功能演进顺序，而不是发布版本号

### V1.x

AI Screenshot Assistant

目标：

截图不仅是保存图片。

而是成为工作流入口。

例如：

截图代码

↓

AI解释错误

↓

提供修复方案

或者：

截图设计稿

↓

生成 macOS 原生界面代码

---

## 技术栈

* Swift 6
* AppKit
* SnapKit
* SwiftUI
* ScreenCaptureKit
* Vision
* Translation
* UserNotifications
* Cloudflare Workers
* Supabase
* TypeScript

---

## 构建

在受限沙箱环境里，`xcodebuild` 默认会把 `DerivedData` 写到系统目录，
这可能导致先看到权限错误，而不是实际编译结果。

项目内提供了统一构建脚本：

```bash
./scripts/build.sh
```

这个脚本会：

* 将 `DerivedData` 固定到仓库内的 `./DerivedData`
* 默认构建 `TYScreenShotTool` 的 `Debug` 配置
* 关闭签名要求，便于本地和自动化环境验证编译结果

如需切换配置，可使用：

```bash
CONFIGURATION=Release ./scripts/build.sh
```

归档也使用项目内统一脚本：

```bash
./scripts/archive.sh
```

这个脚本会：

* 将 `DerivedData` 固定到仓库内的 `./DerivedData`
* 默认执行 `Release` 配置归档
* 将归档结果输出到仓库内的 `./archived`

如需自定义归档输出路径，可使用：

```bash
ARCHIVE_PATH=/your/path/TShot.xcarchive ./scripts/archive.sh
```

约定：

* 后续 `build` 默认使用 `./scripts/build.sh`
* 后续 `archive` 默认使用 `./scripts/archive.sh`
* 非必要不直接手写 `xcodebuild`

自动测试：

```bash
./scripts/test.sh
```

AI Pro 上线前静态预检：

```bash
./scripts/preflight_ai_pro.sh
```

该脚本会检查 Release 网络与签名配置、Sign in with Apple entitlement、Worker 默认视觉模型、Apple StoreKit / 通知验签依赖和关键部署说明。

测试说明见：

* `docs/testing/automated-testing.md`

---

## 项目结构

TShot/

├── App/
├── Features/
├── Services/
├── Shared/
├── Resources/
├── TYScreenShotToolTests/
└── backend/

---

## 开发原则

* MVP优先
* 原生优先
* 小步迭代
* 可读性优先
* 尽量减少第三方依赖

---

## 当前状态

当前开发阶段：

v1.0.0 后续迭代中，当前 Sprint 为 Sprint 53「AI 订阅服务区域化底座」

当前目标：

- 先完成中国大陆纯本地模式与海外 AI Pro 订阅模式的 App 端区域策略、壳层入口、订阅壳层和后端 MVP 边界
- Sprint 46「测试补齐」已完成，项目已具备最小 `XCTest` 单元测试基座

当前截图主流程已支持：

- 悬停窗口 -> 点击确认
- 或直接拖拽自由框选
- 进入截图编辑态后执行复制 / 保存 / OCR / 翻译 / AI / Pin / 长截图 / 取消
- 普通截图与长截图共用 OCR / AI 结果窗口能力
- 普通截图与长截图都支持独立「翻译」入口，使用本地 OCR + Apple Translation 框架，不调用 AI 服务
- AI 入口在区域策略允许时默认显示；中国大陆和 unknown storefront 下隐藏，Debug Settings 中的开发者 AI 开关与 Debug 区域覆盖仍受区域策略约束
- 当前主要业务 UI 现状以 AppKit 实现，布局常用 SnapKit
- 后续开发默认推荐 AppKit + SnapKit，但不限制只能使用这一组合；若评估 SwiftUI 或手动 frame 更合适，也可按场景选用
- 普通截图编辑态已支持矩形、圆形、直线、箭头、画笔、文字、马赛克
- 圆形、直线、箭头、画笔、马赛克已支持属性面板、选中回显、控制节点与继续修改
- 文字标注支持悬停、选中移动、编辑输入与动态边框
- 普通截图与长截图工具栏已切换为图标按钮并支持 Hover Tooltip
- 长截图预览窗口会同时避让截图选区与工具栏区域
- 标注预览与复制 / 保存结果保持一致
- 项目已具备 `XCTest` 单元测试基座，并已接入本地翻译等纯逻辑测试

流程：

⌘⇧2

↓

悬停窗口或拖拽框选

↓

进入截图编辑态

↓

显示底部工具栏与顶部悬浮设置栏

↓

用户添加标注并按需调整属性

↓

用户可在无标注时微调截图区域

↓

用户主动选择复制 / 保存 / OCR / 翻译 / AI / Pin / 长截图 / 取消

↓

后续逐步扩展 AI 工作流深度

---

## AI Pro 与隐藏 AI 配置

当前版本的 `AI` 入口在区域策略允许时默认显示，并接入 Apple 登录、订阅状态和后端 AI 请求校验；中国大陆和 unknown storefront 下仍会隐藏。Debug Settings 中仍可关闭开发者 AI 入口，并可用 Debug 区域策略覆盖值模拟 `USA` / `CHN` / unknown，但最终是否展示仍以区域策略为准。

旧的本地 `AI 分析` 请求参数仍通过隐藏配置读取 `API Key`、`Base URL` 与模型名，仅用于开发者 / Debug / 内部验证。

注意：

* 当前隐藏 AI 配置仅适合作为开发者 / Debug / 内部验证能力。
* `local.aiAnalysis.*` 不能绕过区域策略；中国大陆模式和 unknown / nil storefront 下，即使写入本地 API Key，也不会发起商业 AI 请求。
* 海外模式下 AI Pro 会先经过首次使用同意、Apple 登录、订阅状态和区域策略判断；有效订阅用户点击 AI 后会调用后端 AI 分析接口。
* `backend/` 已提供 Cloudflare Workers + Supabase 后端 MVP，可在登录态、地区、订阅、额度、幂等和图片大小校验通过后转发 AI 请求，并记录 usage 与扣减月额度。
* 正式面向用户的 AI Pro 订阅能力按区域化策略接入：中国大陆区保持纯本地工具定位，海外区通过登录、Apple 订阅和后端校验提供 AI 服务。
* 商业 AI 请求不应依赖用户在本机写入 API Key，后续应统一走后端鉴权、订阅校验、地区校验、额度控制和风控。

普通「翻译」按钮不属于 AI 链路。它默认显示，复用 OCR 识别截图文字，并使用 Apple Translation 框架执行本地翻译。

Debug 区域策略覆盖示例：

```bash
defaults write com.sheldon.TShot debug.regionPolicy.storefrontCode -string "USA"
defaults write com.sheldon.TShot settings.showAIEntrances -bool true
```

清空覆盖后会回到 unknown 保守模式：

```bash
defaults delete com.sheldon.TShot debug.regionPolicy.storefrontCode
```

StoreKit 本地验证：

- 本地 StoreKit 配置文件为 `TYScreenShotTool/TShot.storekit`
- 当前只配置一个自动续期订阅商品：`tshot.pro.monthly`
- 默认与 Debug scheme 已关联该配置，默认测试 scheme 也已关联该配置
- 海外 Debug 策略下可从 AI Pro 壳层进入订阅 / 恢复入口
- App Store 沙盒账户只用于 StoreKit 订阅购买和恢复购买；Sign in with Apple 会使用当前 macOS 系统 Apple Account，不会使用 App Store 沙盒测试账号
- 端到端验证时应先用当前系统 Apple Account 完成 Sign in with Apple 登录，再在购买 / 恢复购买弹窗中使用 App Store 沙盒账户验证订阅交易
- 主 scheme / Debug scheme 关联了本地 `TShot.storekit`，购买弹窗显示 `[Environment: Xcode]` 时代表当前是 Xcode 本地 StoreKit 交易，不是 App Store Connect 沙盒交易。要重置这类本地订阅，应在 Xcode 的 StoreKit transaction manager 中清除交易，或通过 StoreKitTest `SKTestSession.clearTransactions()` 清理后重新安装 / 启动测试。
- 真实 App Store Connect 沙盒验证应使用未关联本地 StoreKit 配置的 `TYScreenShotTool_Release` scheme，或使用 TestFlight / App Store Connect 分发构建；购买弹窗不应显示 `[Environment: Xcode]`。
- 如需把 Xcode 本地 StoreKit 交易临时写回开发后端用于联调，可在开发 Worker 环境设置 `ALLOW_LOCAL_STOREKIT_TRANSACTIONS=true` 后点击「恢复订阅」。该开关只允许用于本地 / 开发环境，生产环境必须关闭。
- StoreKit 购买验证默认跳过；如需本机签名环境验证本地购买交易，可执行：

```bash
defaults write com.sheldon.TShot debug.runStoreKitSandboxTests -bool true
xcodebuild test \
  -project TYScreenShotTool.xcodeproj \
  -scheme TYScreenShotTool \
  -configuration Debug \
  -destination platform=macOS \
  -derivedDataPath DerivedDataStoreKit \
  -only-testing:TYScreenShotToolTests/AIProSubscriptionTests/test_storeKitConfigurationCanPurchaseMonthlyProduct
defaults delete com.sheldon.TShot debug.runStoreKitSandboxTests
```

- 项目脚本 `./scripts/test.sh` 会禁用签名，因此该购买验证只作为显式人工 / Sandbox 验证步骤，不作为默认测试门禁
- 本地订阅状态用于 App 端快速 gating 与设置页展示，最终 AI 请求权限仍由后端校验地区、登录、订阅和额度

后端 MVP：

- Worker 目录：`backend/worker`
- Supabase migrations：`backend/supabase/migrations/202606280001_ai_backend_mvp.sql`、`backend/supabase/migrations/202606300001_allow_local_storekit_subscription_environment.sql`
- 当前 API 可校验 Bearer 登录态、地区 allowlist、订阅状态、日/月额度、`request_id` 幂等和图片大小
- `POST /v1/ai/analyze-screenshot` 在通过前置校验后会调用后端配置的 OpenAI Responses API，并写入 `usage_records`、扣减 `monthly_quotas`
- Sign in with Apple、StoreKit signed transaction 校验、Apple Server Notifications V2 和 App 端 AI Pro 接入已完成代码链路；正式上线前仍需用 Sandbox / TestFlight 和 App Store Connect 商品做真实端到端验证
- Debug 构建默认请求本地 Worker：`http://127.0.0.1:8787`
- Release 构建默认请求正式 Worker：`https://tshot-ai-backend.tshot.workers.dev`
- Worker dev 环境通过 `wrangler dev --env dev` 启动，并连接本地 Supabase：`http://127.0.0.1:54321`
- Worker 正式环境连接正式 Supabase 项目，`SUPABASE_URL` 与 `SUPABASE_SERVICE_ROLE_KEY` 通过 Cloudflare secrets 配置

后端本地验证：

推荐使用一键脚本：

```bash
./scripts/start_local_backend.sh

cd backend/worker
npm test
npm run typecheck
```

如果不使用一键脚本，手动启动顺序如下：

```bash
colima start

cd backend/supabase
supabase start

cd ../worker
cp .dev.vars.example .dev.vars # 首次需要，然后填入本地 SERVICE_ROLE_KEY
npm run dev
```

停止本地后端：

```bash
./scripts/stop_local_backend.sh
```

如果不使用一键脚本，手动停止顺序如下：

```bash
screen -S tshot-worker-dev -X quit # 如果 Worker 是通过一键脚本启动的
# 或在运行 npm run dev 的终端按 Ctrl+C

cd backend/supabase
supabase stop
```

可选配置 `Base URL`：

```bash
defaults write com.sheldon.TShot local.aiAnalysis.baseURL -string "https://api.openai.com"
```

配置 `API Key`：

```bash
defaults write com.sheldon.TShot local.aiAnalysis.openAIAPIKey -string "YOUR_OPENAI_API_KEY"
```

可选配置模型：

```bash
defaults write com.sheldon.TShot local.aiAnalysis.model -string "gpt-5.4-mini"
```

默认模型：

```text
gpt-5.4-mini
```

默认 `Base URL`：

```text
https://api.openai.com
```

兼容第三方 OpenAI 风格网关。

例如：

```bash
defaults write com.sheldon.TShot local.aiAnalysis.baseURL -string "https://www.micuapi.ai/v1"
defaults write com.sheldon.TShot local.aiAnalysis.openAIAPIKey -string "YOUR_THIRD_PARTY_API_KEY"
defaults write com.sheldon.TShot local.aiAnalysis.model -string "gpt-5.4"
```

说明：

* 如果 `Base URL` 不带 `/v1`，程序会自动补到 `/v1/responses`
* 如果 `Base URL` 已经带了 `/v1`，程序会直接拼到 `/v1/responses`
* 当前实现仍要求第三方接口兼容 OpenAI `Responses API`

删除本地 AI 配置：

```bash
defaults delete com.sheldon.TShot local.aiAnalysis.baseURL
defaults delete com.sheldon.TShot local.aiAnalysis.openAIAPIKey
defaults delete com.sheldon.TShot local.aiAnalysis.model
```

---

说明：

* 当前精确迭代阶段以 `docs/ROADMAP.md` 为准
* 当前执行范围以 `docs/ROADMAP.md` 与当前 Sprint 文档（`docs/SPRINTS/Sprint-XX.md`）为准

---

## 长期愿景

打造一个真正服务于开发者自己的 AI 工作助手。

从截图开始，但不止于截图。
