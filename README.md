# SmartShot

一个用于学习 macOS 原生开发和 AI 辅助开发流程的个人项目。

---

## 项目目标

SmartShot 不是为了替代现有截图软件。

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

### V0.1

基础截图功能

功能：

* 菜单栏应用
* 全局快捷键
* 框选截图
* 保存 PNG
* 保存到桌面
* 自动复制到剪贴板

---

### V0.2

OCR

功能：

* 图片文字识别

---

### V0.3

设置增强

功能：

* OCR 开关
* HotKey 配置
* 保存目录配置

---

### V0.4

截图编辑工作流

功能：

* 框选完成后进入截图编辑态
* 底部工具栏
* 手动复制或保存
* 顶部悬浮设置栏

---

### V0.5

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

### V0.6

截图动作与反馈体验

功能：

* OCR 入口迁移到工具栏
* Pin 固定截图
* OCR / 复制 / 保存提示反馈
* Pin 浮动窗口增强

---

### V0.7

滚动长截图

功能：

* 支持滚动区域捕获
* 生成长图结果

---

### V0.8

AI分析

功能：

* 截图发送给 AI
* 分析代码报错
* 分析 UI 界面
* 分析文档内容

---

### V1.0

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
ARCHIVE_PATH=/your/path/SmartShot.xcarchive ./scripts/archive.sh
```

约定：

* 后续 `build` 默认使用 `./scripts/build.sh`
* 后续 `archive` 默认使用 `./scripts/archive.sh`
* 非必要不直接手写 `xcodebuild`

---

## 项目结构

SmartShot/

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

V0.6 进行中

当前目标：

在已完成工具栏 `OCR` 与 `Pin` 最小动作链路的基础上，
继续补齐截图反馈体验，
并增强 `Pin` 浮动窗口的默认展示与基础缩放能力。

流程：

⌘⇧2

↓

框选区域

↓

进入截图编辑态

↓

显示底部工具栏与顶部悬浮设置栏

↓

用户添加基础标注

↓

用户可在无标注时微调截图区域

↓

用户主动选择复制 / 保存 / 取消

↓

后续逐步扩展标注、OCR、Pin、长截图、AI

---

说明：

* 当前精确迭代阶段以 `docs/ROADMAP.md` 为准
* 当前唯一任务范围以 `TASK.md` 为准

---

## 长期愿景

打造一个真正服务于开发者自己的 AI 工作助手。

从截图开始，但不止于截图。
