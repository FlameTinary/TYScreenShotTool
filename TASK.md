# TShot

Version: v1.0.0+

Current Sprint: Sprint 38 Planned

---

## 当前状态

Sprint 37 已完成实现、构建验证与人工验证。
Sprint 38 已完成本地化设计对齐，准备进入 implementation plan 阶段。

## 当前目标

为 TShot 建立统一的 App 本地化能力，
支持 UI 文案、AI prompt 与 AI 输出语言协同切换。

---

## 本次范围

1. 建立统一的本地化资源基础设施

2. 支持以下语言：
   - 简体中文
   - English
   - 日本語
   - 한국어
   - Deutsch
   - Français

3. Settings 中新增语言设置项，
   支持：
   - 跟随系统
   - 手动覆盖语言

4. 菜单栏、Settings、截图编辑态、OCR 窗口、AI 窗口的用户可见文案本地化

5. AI prompt、AI 固定输出标题与 AI 输出语言跟随当前有效语言切换

6. OCR 识别语言改为“当前语言优先 + 中英兜底”

---

## 验收标准

1. App 支持以下语言：
   - 简体中文
   - English
   - 日本語
   - 한국어
   - Deutsch
   - Français

2. Settings 中存在语言设置项，支持“跟随系统 + 6 种语言手动覆盖”

3. 菜单栏、Settings、截图编辑态、OCR 窗口、AI 窗口的用户可见文案都完成本地化

4. 用户切换语言后，新打开的窗口和新触发流程使用新语言

5. 已打开窗口不要求强制即时刷新

6. AI prompt 与 AI 固定输出标题会跟随当前有效语言切换

7. 翻译功能的目标语言不受 UI 语言影响

8. OCR 识别语言采用“当前语言优先 + 中英兜底”

9. 不因为本地化引入新的截图主链路回归

10. 项目构建通过，且每种语言至少完成核心人工验证

---

遵循：

MVP

KISS

YAGNI
