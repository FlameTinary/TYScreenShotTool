# TShot

一个用于学习 macOS 原生开发和 AI 辅助开发流程的个人项目。

---

## 项目目标

TShot 不是为了替代现有截图软件。

项目主要用于：

* 学习 macOS 开发
* 实践 SwiftUI
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

生成 SwiftUI 代码

---

## 技术栈

* Swift 6
* SwiftUI
* AppKit
* ScreenCaptureKit
* Vision
* UserNotifications

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

---

## 项目结构

TShot/

├── App/
├── Features/
├── Services/
├── Shared/
└── Resources/

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

v1.0.0 后续迭代中

当前目标：

已完成 `Sprint 31` 的最小窗口悬停选择，
当前截图主流程已支持：

- 悬停窗口 -> 点击确认
- 或直接拖拽自由框选

流程：

⌘⇧2

↓

悬停窗口或拖拽框选

↓

进入截图编辑态

↓

显示底部工具栏与顶部悬浮设置栏

↓

用户添加基础标注

↓

用户可在无标注时微调截图区域

↓

用户主动选择复制 / 保存 / OCR / AI / Pin / 长截图 / 取消

↓

后续逐步扩展 AI 工作流深度

---

## 隐藏 AI 配置

当前版本的 `AI 分析` 不提供设置页入口，
而是通过本地隐藏配置读取 `API Key`、`Base URL` 与模型名。

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
* 当前唯一任务范围以 `TASK.md` 为准

---

## 长期愿景

打造一个真正服务于开发者自己的 AI 工作助手。

从截图开始，但不止于截图。
