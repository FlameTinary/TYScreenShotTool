# TYScreenShotTool Roadmap

## 已完成

### Sprint 01

项目初始化

状态：
✅ Done

---

### Sprint 02

全局热键

状态：
✅ Done

---

### Sprint 03

Overlay 选区

状态：
✅ Done

---

### Sprint 04

Capture Session State Machine

状态：
✅ Done

---

### Sprint 05

ScreenCaptureKit 集成

状态：
✅ Done

成果：

- 获取 CGImage
- 多显示器支持
- Retina 支持
- 权限检查

---

### Sprint 06

PNG 自动保存

状态：
✅ Done

成果：

- `CGImage` 保存为 PNG
- 自动生成毫秒级文件名
- 保存到真实桌面
- Console 输出保存路径
- 修复坐标转换偏移问题

---

### Sprint 07

Clipboard 支持

状态：
✅ Done

成果：

- 截图后自动复制到剪贴板
- 成功后桌面最终生成 PNG
- 控制台输出保存路径与复制成功日志
- 引入临时 PNG 流程以满足失败回滚语义

---

## 当前进行中

### Sprint 08

OCR

目标：

截图结果进入文字识别链路。

---

## Backlog

### Sprint 09

AI 分析

OpenAI API

---

### Sprint 10

设置页面

- HotKey 配置
- 保存目录配置
- OCR 开关
