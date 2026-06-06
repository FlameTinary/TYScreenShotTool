# TYScreenShotTool

Version: V0.4

Current Sprint: Sprint 13 Planned

---

## 目标

在 Sprint 12 已完成 `保存目录配置` 的基础上，
开始实现最小 AI 分析能力。

流程：

Screenshot

↓

OCR

↓

AI Analyze

↓

Minimal Result


---

## 必须完成

1. 增加最小 AI 分析入口

2. 能基于当前截图结果发起一次最小 AI 请求

3. 成功返回最小分析结果

4. 保持截图、PNG、剪贴板、OCR、Settings 链路正常

5. 保持实现范围最小，不引入复杂 AI 架构

---

## 不做

历史记录

多轮对话

复杂 Prompt 管理

多模型配置

---

## 验收标准

用户完成一次截图后，
可以触发最小 AI 分析流程。

AI 请求可以成功返回结果。

同时截图、PNG、剪贴板、OCR、Settings 链路仍正常可用。

说明 Sprint 13 的 AI 最小主链路已打通。

---

遵循：

MVP

KISS

YAGNI
