# Sprint 19 - 应用命名调整

## Status

Completed

## Goal

将截图应用面向用户展示的名称统一从 `TShot` 调整为 `SmartShot`。

本次目标仅限于用户可见命名统一，
不进行工程目录重命名、
不修改 Bundle Identifier、
不引入额外品牌系统或视觉改版。

---

## Scope

### Included

- 更新 App 构建产物名称为 `SmartShot`
- 更新菜单栏文案中的应用名称为 `SmartShot`
- 更新菜单栏图标的可访问名称为 `SmartShot`
- 更新其他当前已存在的用户可见名称文本，使其与 `SmartShot` 一致

### Out of Scope

- 修改工程目录名 `TYScreenShotTool`
- 修改 Target 名称
- 修改 Bundle Identifier
- 修改截图文件命名规则
- 修改应用图标视觉设计
- 调整功能逻辑

---

## Implementation

### 方向

优先采用最小改动方案：

1. 只调整用户可见名称
2. 保持工程结构与代码组织不变
3. 优先修改 Xcode Build Settings 中的 App 显示名称
4. 同步修正代码中的菜单栏与可访问名称文本

### 约束

- 遵循 MVP
- 遵循 KISS
- 遵循 YAGNI
- 不为品牌系统提前扩展额外配置层

---

## Validation

### 场景 1

运行应用后，
菜单栏项目名称应显示为 `SmartShot`。

### 场景 2

通过 Xcode 构建或 Archive 后，
生成的 `.app` 名称应为 `SmartShot.app`。

### 场景 3

应用其他当前已存在的用户可见名称文本中，
不应再出现旧名称 `TShot`。

### 场景 4

截图、设置、保存、复制等现有主链路不受影响。

---

## Result

已完成用户可见应用命名统一。

当前应用构建产物名称、
Bundle 显示名称、
菜单栏文案、
菜单栏图标可访问名称
均已统一调整为 `SmartShot`。

本次未修改工程目录名、
Target 名称、
Bundle Identifier，
保持了最小改动原则。
