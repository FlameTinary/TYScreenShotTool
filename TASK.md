# TYScreenShotTool

Version: V0.5

Current Sprint: Sprint 19 Completed

---

## 当前目标

将截图应用面向用户展示的名称统一从 `TShot` 调整为 `SmartShot`。


---

## 本次范围

1. 更新 App 构建产物名称为 `SmartShot`

2. 更新菜单栏文案中的应用名称为 `SmartShot`

3. 更新菜单栏图标的可访问名称为 `SmartShot`

4. 更新其他当前已存在的用户可见名称文本，使其与 `SmartShot` 一致

5. 不修改工程目录名、Target 名称与 Bundle Identifier

6. 不破坏现有截图、设置、复制、保存主链路

---

## 验收标准

运行应用后，
菜单栏项目名称应显示为 `SmartShot`。

通过 Xcode 构建或 Archive 后，
生成的 `.app` 名称应为 `SmartShot.app`。

应用当前已存在的用户可见名称文本中，
不应再出现旧名称 `TShot`。

截图、设置、复制、保存等现有主链路应保持正常。

---

遵循：

MVP

KISS

YAGNI
