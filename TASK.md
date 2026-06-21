# TShot

Version: v1.0.0+

Current Sprint: Sprint 41 In Progress

---

## 当前状态

Sprint 41 已进入设计阶段。
设计文档已完成并 commit。
实现计划已完成并 commit。

## 当前目标

为矩形工具新增属性面板，让用户可以在截图编辑态自由调整矩形的粗细、透明度、圆角、实心/空心和颜色。点击已画矩形可选中并调整属性，面板值作为新矩形默认值。

---

## 本次范围

1. 新增 RGBColor 与 RectangleProperties 数据模型
2. 新增 RectanglePropertyPanelView 属性面板（两排布局，粗细下拉选/透明度滑块/圆角滑块/实心空心分段按钮/颜色预设8色）
3. 修改 CaptureAnnotation.rectangle 携带 RectangleProperties 参数
4. 画布选中交互：点击已画矩形进入选中态（青色虚线高亮）
5. 基于 RectangleProperties 的矩形渲染（圆角/实心空心/透明度）
6. 导出渲染适配 RectangleProperties
7. 面板生命周期：点击矩形→显示；点击其他工具/取消→隐藏

---

## 验收标准

1. 点击矩形按钮，面板在工具栏下方显示
2. 面板两排布局规整，5 个控件均可正常操作
3. 新矩形使用面板当前值渲染
4. 点击已画矩形→青色高亮+面板同步
5. 面板调整→选中矩形实时更新
6. 点击其他工具/取消→面板隐藏
7. 其他工具（椭圆/箭头/画笔/马赛克/文字）不受影响
8. 导出图片中矩形正确渲染属性
9. `./scripts/build.sh` 构建通过
