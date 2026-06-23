# Sprint 44 - 标注工具属性面板扩展

## Status

✅ Done

## Goal

为普通截图编辑态补齐圆形、直线、箭头、画笔、马赛克的属性面板与属性回显链路，并新增直线工具按钮。

## Scope

### Included

- 新增 `直线` 工具
- 新增 5 类工具属性面板能力
- 支持选中已有标注后回显并继续修改
- 画笔支持 `单一颜色` / `高斯模糊` / `马赛克`
- 马赛克支持 `马赛克` / `毛玻璃`

### Data Model

- `ShapeStrokeProperties` — 圆形/直线共用描边属性（粗细、透明度、颜色）
- `ArrowProperties` — 箭头属性（粗细、透明度、颜色、曲线开关）
- `PenProperties` — 画笔属性（粗细、透明度、颜色、模式）
- `MosaicProperties` — 马赛克属性（大小、样式）
- `AnnotationEditableProperties` — 通用选中回显载体

### Property Panels

- `RectanglePropertyPanelView` — 矩形面板 SnapKit 迁移完成
- `StrokePropertyPanelView` — 圆形/直线共用面板
- `ArrowPropertyPanelView` — 箭头面板（含曲线箭头开关）
- `PenPropertyPanelView` — 画笔面板（含模式选择）
- `MosaicPropertyPanelView` — 马赛克面板（含双样式单选）

### Canvas

- 所有标注工具支持点击选中与属性回显
- 直线、折线、线段命中检测辅助方法
- 箭头支持曲线贝塞尔路径
- 画笔效果：高斯模糊与马赛克
- 马赛克样式：CIPixellate / CIGaussianBlur
- 预览与复制/保存导出链路的标注属性语义保持一致

## Key files

- `TYScreenShotTool/Shared/AnnotationTool.swift` — 新增 `.line` 工具定义
- `TYScreenShotTool/Shared/ShapeStrokeProperties.swift` — 新增
- `TYScreenShotTool/Shared/ArrowProperties.swift` — 新增
- `TYScreenShotTool/Shared/PenProperties.swift` — 新增
- `TYScreenShotTool/Shared/MosaicProperties.swift` — 新增
- `TYScreenShotTool/Shared/AnnotationEditableProperties.swift` — 新增
- `TYScreenShotTool/Features/CaptureOverlay/StrokePropertyPanelView.swift` — 新增
- `TYScreenShotTool/Features/CaptureOverlay/ArrowPropertyPanelView.swift` — 新增
- `TYScreenShotTool/Features/CaptureOverlay/PenPropertyPanelView.swift` — 新增
- `TYScreenShotTool/Features/CaptureOverlay/MosaicPropertyPanelView.swift` — 新增
- `TYScreenShotTool/Features/CaptureOverlay/CaptureOverlayView.swift` — 多面板接入
- `TYScreenShotTool/Features/CaptureOverlay/CaptureAnnotationCanvasView.swift` — 扩展创建、选中、回显、渲染
- `TYScreenShotTool/Features/CaptureOverlay/RectanglePropertyPanelView.swift` — 迁至 SnapKit

## Manual verification checklist

1. 工具栏新增 `直线` 按钮
2. `圆形` 面板显示大小/不透明度/颜色
3. 圆形绘制后面板修改即时生效
4. 点击已有圆形回显属性，修改后图形更新
5. `直线` 面板与圆形一致，绘制和回显可用
6. `箭头` 支持曲线箭头开关
7. `画笔` 三种模式分别验证
8. 画笔笔迹可回显修改
9. `马赛克` 双样式切换
10. 马赛克区域可回显修改
11. 矩形面板回归验证
12. 文字/OCR/AI/Pin/复制/保存/取消主链路未受影响

## Fixups

- 修复 `直线` 工具仅有临时预览、鼠标抬起后未真正写入 `annotations` 的问题
- 修复新建马赛克区域未继承当前属性面板默认值的问题
- 修复曲线箭头按曲线绘制但仍按直线命中检测，导致点击箭身难以选中的问题
- 修复 `ellipse / line / arrow / pen / mosaic` 在导出侧仍沿用旧渲染语义，造成预览与复制/保存结果不一致的问题

## Final verification

- `./scripts/build.sh` 构建通过
- 人工验证通过：
  - `直线` 可绘制、可回显、可进入最终结果
  - 曲线箭头可稳定选中并继续修改
  - 马赛克默认值与新建区域行为一致
  - 预览、复制、保存结果一致

## Architecture note

保留现有 `CaptureOverlayView + CaptureAnnotationCanvasView` 的 AppKit 结构。
属性面板继续使用 AppKit，布局统一使用 SnapKit。
截图编辑态局部不在此轮切 SwiftUI。
