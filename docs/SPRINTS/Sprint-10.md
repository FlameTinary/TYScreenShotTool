# Sprint 10 - OCR 开关

## Status

Completed ✅

## Goal

在 Sprint 09 已完成设置页面入口与最小设置骨架的基础上，
先实现第一个真实可用的设置项：

Settings
→ OCR 开关
→ 控制截图后是否执行 OCR

本次目标是让设置项不再只是占位，
并且让开关状态真实影响当前截图主链路。

---

## Scope

### Included

- 在设置页面中提供可操作的 OCR 开关
- 开关状态可被应用读取
- 截图完成后根据开关状态决定是否执行 OCR
- 保持 PNG 保存与剪贴板复制流程正常
- 保持现有设置页面入口与截图流程正常

### Out of Scope

- HotKey 配置
- 保存目录配置
- OCR 语言配置
- OCR 结果展示页面
- AI 分析
- 通知能力
- 历史记录

---

## Implementation

### 方向

优先采用最小实现：

1. 在设置页面中将 `OCR 开关` 从占位项改为真实控件
2. 保存用户当前选择
3. 在截图流程中读取该配置
4. 开启时执行 OCR，关闭时跳过 OCR

---

### 约束

- 遵循 MVP
- 遵循 KISS
- 遵循 YAGNI
- 不为未来设置系统增加额外抽象层
- 不提前实现其他设置项

---

## Validation

### 场景 1

打开设置页面后，
用户可以看到并切换 OCR 开关。

### 场景 2

当 OCR 开关为开启时，
截图后仍会执行 OCR，
控制台输出 OCR 成功日志与识别文本。

### 场景 3

当 OCR 开关为关闭时，
截图后不执行 OCR，
控制台不再输出 OCR 成功日志与识别文本。

### 场景 4

无论 OCR 开关开启或关闭，
PNG 保存与剪贴板复制流程都保持正常。

---

## Result

验证通过。

本次 Sprint 已完成：

- `Settings` 页面中的 `OCR 开关` 从占位项变为真实可操作控件
- 开关状态可持久化保存
- 截图完成后会根据开关状态决定是否执行 OCR
- OCR 关闭时会明确输出 `OCR skipped: disabled in settings`
- PNG 保存与剪贴板复制链路保持正常

已完成人工验证：

- 可以打开 `Settings` 页面并切换 `OCR 开关`
- OCR 开启时，控制台输出 `OCR Success`
- OCR 关闭时，控制台输出 `OCR skipped: disabled in settings`
- 两种场景下 PNG 保存与剪贴板复制均正常
