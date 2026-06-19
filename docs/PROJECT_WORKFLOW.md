# PROJECT_WORKFLOW.md

## 目的

本文档用于说明项目内各类文档的职责、对齐关系和 Sprint 收尾规则。

它只描述项目文档协作方式，不定义 AI Agent 的通用执行流程。

---

# 文档职责

## README.md

用于说明项目整体情况，包括：

* 项目目标
* 解决的问题
* 技术栈
* 当前状态
* 长期方向

---

## docs/ROADMAP.md

用于描述产品路线图，包括：

* Done
* Current
* Backlog

不要在这里记录技术实现细节。

---

## docs/SPRINTS

每个 Sprint 使用一个独立文档。

推荐包含以下部分：

* Status
* Goal
* Scope
* Out of Scope
* Implementation
* Validation
* Result

---

## TASK.md

`TASK.md` 是当前唯一执行范围的简化表达。

它只保留当前 Sprint 中正在处理的那一个任务，并保持简洁、具体。

推荐包含：

* 当前目标
* 本次范围
* 验收标准

---

## docs/DEVLOG.md

用于记录有意义的开发结果，例如：

* Sprint 完成情况
* 重要问题
* 重要决策
* 关键解决方案

不要把它写成琐碎修改清单。

---

# 文档对齐规则

当进行规划或实现时，应按以下顺序对齐文档：

`ROADMAP -> 当前 Sprint 文档 -> TASK.md`

规则如下：

* 当前 Sprint 的工作必须与 `docs/ROADMAP.md` 保持一致
* `TASK.md` 必须与当前 Sprint 文档保持一致
* 如果这些文档之间存在冲突，应先修正文档不一致，再继续规划或实现
* 除非明确调整范围，否则不要超出当前 Sprint 的边界

---

# Sprint 收尾

只有在以下条件都满足后，当前 Sprint 才能视为完成：

* 当前范围内的功能已经实现
* 项目可以成功构建
* 已完成人工验证
* Sprint 文档已更新
* `TASK.md` 已更新
* 如果状态发生变化，`docs/ROADMAP.md` 已更新
* 如果本次迭代产生了值得记录的结果，`docs/DEVLOG.md` 已更新

---

# 使用建议

在汇报进展或整理收尾时，优先说明：

* 改了什么
* 如何验证
* 更新了哪些项目文档
* 是否还有风险或后续事项
