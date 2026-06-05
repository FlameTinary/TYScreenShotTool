# TYScreenShotTool

## 当前阶段

V0.1 - Sprint 2

状态：进行中

---

# Sprint 目标

实现全局快捷键监听能力。

用户在任何应用中按下指定快捷键后，TYScreenShotTool 能收到事件。

本次只验证快捷键链路，不进入截图流程。

---

# 用户故事

作为用户，

我希望在任何应用中按下快捷键，

让截图工具立即响应，

以便后续进入截图模式。

---

# 本次实现范围

## 必须实现

- 注册全局快捷键
- 默认快捷键为：

⌘⇧2

- 应用在后台运行时仍然能够响应
- 收到快捷键后输出日志：

Screenshot shortcut triggered

---

## 本次不实现

- 截图
- Overlay
- ScreenCaptureKit
- OCR
- AI分析
- 保存图片
- 设置页面
- 自定义快捷键

---

# 技术要求

请先分析 macOS 15+ 下实现全局快捷键的方案。

候选方案包括但不限于：

- Carbon RegisterEventHotKey
- NSEvent
- 其他系统原生方案

要求：

1. 不引入第三方依赖
2. 优先选择 Apple 官方 API
3. 适用于菜单栏应用
4. 能够在应用不处于前台时工作
5. 说明选择原因
6. 保持实现简单

---

# 建议目录

如果需要新增代码：

TYScreenShotTool/

Features/
└── Hotkey/

Services/

---

# 验收标准

启动应用

↓

菜单栏应用正常运行

↓

切换到任意其他应用

例如：

- Safari
- Chrome
- Xcode
- Finder

↓

按下：

⌘⇧2

↓

Xcode Console 输出：

Screenshot shortcut triggered

---

# 完成后输出

请输出：

## 技术方案分析

说明为什么选择当前方案。

## 修改文件

列出新增和修改的文件。

## 验证方法

说明如何验证功能。

## 下一步建议

为 Sprint 3 提供建议。

---

# 开发原则

- KISS
- YAGNI
- 小步迭代
- 不提前实现未来功能
- 优先可运行
- 优先可验证