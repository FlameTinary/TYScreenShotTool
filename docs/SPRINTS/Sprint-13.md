# Sprint 13 - AI 分析

## Status

Planned

## Goal

在 Sprint 12 已完成 `保存目录配置` 的基础上，
开始进入 V0.4 的第一步能力：

Screenshot
→ OCR
→ AI 分析

本次目标不是完整 AI 助手，
而是先打通最小 AI 分析主链路。

---

## Scope

### Included

- 增加最小 AI 分析入口
- 将当前截图结果组织为可发送给 AI 的输入
- 发起一次最小 AI 请求
- 输出最小分析结果
- 保持现有截图主链路正常

### Out of Scope

- 多轮对话
- 历史记录
- 复杂 Prompt 管理
- 多模型配置
- 结果富文本渲染
- 云同步

---

## Implementation

### 方向

优先采用最小实现：

1. 明确 AI 分析入口位置
2. 基于现有截图/OCR 结果组织输入
3. 发起最小 AI 请求
4. 输出最小结果

---

### 约束

- 遵循 MVP
- 遵循 KISS
- 遵循 YAGNI
- 不引入复杂 AI 工作流层
- 不提前实现未来 AI 能力

---

## Validation

### 场景 1

用户完成一次截图后，
可以触发最小 AI 分析流程。

### 场景 2

AI 请求可以成功返回结果。

### 场景 3

现有截图、PNG、Clipboard、OCR、Settings 链路仍正常。

---

## Result

Pending
