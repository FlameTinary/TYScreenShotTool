# Sprint 19 - 应用命名调整

## Status

Completed

## Goal

将截图应用面向用户展示的名称统一从 `TShot` 调整为 `SmartShot`。

补充修复：

在 macOS 系统权限授权页面中，
应用名称仍显示为旧工程名 `TYScreenShotTool`，
未与 `SmartShot` 保持一致。

本次目标是：

补齐系统权限授权页面相关的命名一致性，
让用户在屏幕录制等系统权限界面中看到的应用名称也统一为 `SmartShot`。

---

## Scope

### Included

- 更新 App 构建产物名称为 `SmartShot`
- 更新菜单栏文案中的应用名称为 `SmartShot`
- 更新菜单栏图标的可访问名称为 `SmartShot`
- 更新其他当前已存在的用户可见名称文本，使其与 `SmartShot` 一致
- 修复系统权限授权页面中仍显示旧工程名的问题

### Out of Scope

- 修改工程目录名 `TYScreenShotTool`
- 修改 Target 名称
- 修改截图文件命名规则
- 修改应用图标视觉设计
- 调整功能逻辑

---

## Implementation

### 方向

优先采用最小改动方案：

1. 优先保持 `SmartShot` 作为统一用户可见名称
2. 在最小范围内补齐权限页命名一致性
3. 优先检查并修正会影响系统权限页显示的应用身份配置
4. 不为了命名问题扩散到无关功能改动

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

### 场景 5

在 macOS 屏幕录制等系统权限页面中，
应用名称应显示为 `SmartShot`，
不应再显示 `TYScreenShotTool`。

### 场景 6

使用 `Archive` 导出的 app 安装并运行后，
系统权限授权与截图主链路应正常工作。

---

## Result

已完成。

本次最终结果：

- 构建产物名称统一为 `SmartShot`
- Bundle 显示名称统一为 `SmartShot`
- 菜单栏文案统一为 `SmartShot`
- 菜单栏图标可访问名称统一为 `SmartShot`
- `Bundle Identifier` 调整为 `com.sheldon.SmartShot`
- 系统权限授权页面中的应用名称已统一为 `SmartShot`

补充说明：

- 通过 `Archive` 导出的 app 安装后，权限授权与截图主链路验证通过
- Xcode 直接运行的调试版在屏幕录制授权复用上存在环境差异，不作为本次 Sprint 通过依据
