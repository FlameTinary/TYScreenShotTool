# TYScreenShotTool

Version: V0.5

Current Sprint: Sprint 19 Completed

---

## 当前目标

补齐 `SmartShot` 的命名一致性，
修复 macOS 系统权限授权页面中仍显示旧工程名 `TYScreenShotTool` 的问题。


---

## 本次范围

1. 检查影响系统权限授权页面显示名称的项目配置

2. 修复权限授权页面中仍显示 `TYScreenShotTool` 的问题

3. 保持应用对外显示名称继续统一为 `SmartShot`

4. 不进行工程目录重命名

5. 不调整截图、保存、复制、OCR、标注等功能逻辑

6. 遵循 MVP / KISS / YAGNI

---

## 验收标准

菜单栏、设置页、构建产物与系统权限授权页面中，应用名称都应显示为 `SmartShot`。

macOS 屏幕录制权限页面中不应再出现 `TYScreenShotTool`。

截图、设置、保存、复制、OCR、标注等现有主链路应保持正常。

当前状态：

本次任务已完成并通过人工验证。
权限验证以 `Archive` 导出的 app 为准。

---

遵循：

MVP

KISS

YAGNI
