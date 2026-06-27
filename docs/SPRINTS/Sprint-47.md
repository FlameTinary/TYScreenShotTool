# Sprint 47 - 箭头端点与曲线控制节点

## Status

✅ Done

## Goal

增强箭头标注的选中与编辑体验，让直线箭头和曲线箭头都能通过控制节点进行精细调整。

---

## Scope

### Included

- 箭头标注选中后取消青色虚线边框
- 直线箭头选中后显示 2 个端点控制节点
- 曲线箭头选中后显示 4 个控制节点
- 曲线控制节点支持拖拽调节曲线弧度方向和大小
- 箭头主体区域支持整体拖动，控制点同步跟随
- 导出渲染同步使用箭头存储控制点

### Out of Scope

- 不重构完整标注系统
- 不新增新的箭头样式集合
- 不修改 OCR / AI / Pin / 复制 / 保存主链路

---

## Implementation

### 实现

- 箭头绘制使用 `ArrowProperties` 中的存储控制点替代硬编码默认曲线
- `ArrowProperties` 新增 `curveControl1` / `curveControl2` 可选字段
- 新增 `arrowControlPoints`、`arrowInteractionTarget`、`arrowInteraction` 等交互方法
- 新增 `AnnotationResizeTarget` 的 `.resizeArrowControl1` / `.resizeArrowControl2` 枚举值
- 新增 `updateSelectedArrow`、`updatedArrowFromResize`、`updateArrowHover` 交互方法
- `CaptureSessionService` 的箭头导出渲染同步使用存储控制点
- `hitTestEditableAnnotation` 支持通过控制节点选中箭头
- 属性面板切换 `isCurved` 时自动维护控制点数据一致性
- 选中后移动箭头时，曲线控制点同步跟随移动

---

## Validation

1. 直线箭头选中后显示 2 个端点控制节点
2. 曲线箭头选中后显示 4 个控制节点
3. 拖拽直线箭头端点可调整起止位置
4. 拖拽曲线控制点可调整弧度方向和大小
5. 拖拽箭头主体可整体移动，控制点同步跟随
6. 保存 / 复制导出的箭头结果与编辑态一致
7. 自动化测试通过，历史记录为 `142` 个测试通过

---

## Result

Sprint 47 完成后，箭头标注从“选中后只能整体移动”的基础编辑能力，升级为支持端点和曲线控制点精细调整的编辑体验。
