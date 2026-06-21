# Sprint 38 - App 本地化

## Status

Done

## Goal

在 Sprint 35 ~ 37 持续扩展 `AI` 能力之后，
TShot 当前的用户可见文案已经覆盖菜单栏、Settings、截图编辑态、OCR / AI 结果窗与 AI 固定结构标题。

Sprint 38 的目标是：

- 为 App 建立统一的本地化能力
- 同时支持 UI 文案、AI prompt 与 AI 输出语言切换

本轮先支持以下语言：

- 简体中文
- English
- 日本語
- 한국어
- Deutsch
- Français

同时支持：

- 跟随系统
- Settings 手动覆盖语言

并保持：

- 新打开窗口与新触发流程使用新语言
- 已打开窗口不强制即时刷新
- OCR 与 AI 主链路不发生行为回归

---

## Scope

### Included

- 建立 `String Catalog (.xcstrings)` 本地化资源
- 支持以下语言：
  - 简体中文
  - English
  - 日本語
  - 한국어
  - Deutsch
  - Français
- 新增 App 语言模型与当前有效语言解析逻辑
- Settings 中新增语言设置项：
  - 跟随系统
  - 简体中文
  - English
  - 日本語
  - 한국어
  - Deutsch
  - Français
- 菜单栏菜单文案本地化
- Settings 页面文案本地化
- 截图编辑态工具栏与顶部浮层文案本地化
- OCR 结果窗文案本地化
- AI 结果窗文案本地化
- Toast / Alert / placeholder / 状态提示文案本地化
- `AIAnalysisMode` 与 `AITranslationLanguage` 的可见文案本地化
- AI prompt 与 AI 固定输出标题根据当前有效语言切换
- OCR 识别语言改为“当前语言优先 + 中英兜底”

### Out of Scope

- 切换语言后强制刷新已经打开的所有窗口
- 用户切换语言后要求立即重建当前截图编辑态 UI
- 为不同语言建立完全不同的产品流程
- 根据截图内容自动猜测 AI 输出语言
- 按地区进一步细分英语、法语、德语变体
- 新增云端翻译服务
- 把 README / 文档体系全部多语言化

---

## Implementation

### 方向

优先采用原生、轻量、可维护的本地化方案：

1. 使用 `String Catalog (.xcstrings)` 统一管理用户可见文案
2. 增加一个很薄的 App 语言模型
3. 增加一个很薄的本地化取值入口
4. Settings 支持“跟随系统 + 手动覆盖语言”
5. UI 文案、AI prompt、AI 固定输出标题统一按当前有效语言切换
6. OCR 识别语言采用“当前语言优先 + 中英兜底”

### 约束

- 遵循 MVP
- 遵循 KISS
- 遵循 YAGNI
- 不引入第三方本地化框架
- 不强制即时刷新所有已打开窗口
- 不影响保存、复制、`OCR`、`Pin`、长截图、AI 主链路

---

## Validation

### 场景 1

Settings 中存在语言设置项，
支持：

- 跟随系统
- 简体中文
- English
- 日本語
- 한국어
- Deutsch
- Français

### 场景 2

菜单栏、Settings、截图编辑态、OCR 窗口、AI 窗口的用户可见文案都完成本地化。

### 场景 3

用户切换语言后，
新打开的窗口和新触发流程使用新语言。

### 场景 4

已打开窗口不要求强制即时刷新。

### 场景 5

AI prompt 与 AI 固定输出标题会跟随当前有效语言切换。

### 场景 6

翻译功能的目标语言不受 UI 语言影响。

### 场景 7

OCR 识别语言采用“当前语言优先 + 中英兜底”。

### 场景 8

普通截图、长截图、OCR、AI 主链路没有因本地化出现功能回归。

---

## Result

Sprint 38 完成后，TShot 已建立一套原生、轻量的 App 本地化能力：

- 基于 `String Catalog + AppLanguage + AppLocalization + AppText` 收口用户可见文案与运行时动态文案
- 支持简体中文、English、日本語、한국어、Deutsch、Français 六种语言
- Settings 已支持“跟随系统 + 手动覆盖语言”
- 菜单栏、Settings、截图编辑态、OCR 窗口、AI 窗口的用户可见文案已完成本地化
- AI prompt、AI 固定输出标题与 AI 输出语言已跟随当前有效语言切换
- 翻译功能的目标语言继续独立于 UI 语言
- OCR 识别语言已调整为“当前语言优先 + 中英兜底”
- 新打开窗口与新触发流程会使用新语言，已打开窗口不强制即时刷新
- `./scripts/build.sh` 构建通过，人工验证通过
