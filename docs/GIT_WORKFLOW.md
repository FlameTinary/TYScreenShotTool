# Git Workflow

## 目的

统一本项目的 Git 提交习惯，减少提交顺序错误、范围混乱和历史改写问题。

---

## 基本原则

### 4. 只提交本轮相关内容

执行提交时，只暂存当前 Sprint 或当前任务直接相关的文件。

如果工作区中存在以下内容，不应默认混入本轮提交：

* 用户自行创建但未纳入本轮范围的文档
* 与当前 Sprint 无关的实验文件
* 未完成的后续规划文档
* 与当前任务无关的临时改动

---

## 提交顺序

执行提交与推送时，必须遵循以下顺序，不能跳步，也不要并行执行：

### 1. 先检查是否已经 `git add`

在执行 `git commit` 前，先确认本轮要提交的文件已经正确暂存。

推荐检查：

```bash
git status --short
git diff --cached --stat
```

要求：

* 先确认 staged 区中确实存在本轮要提交的文件
* 先确认没有把无关文件误加入 staged 区
* 如果还没有 `git add`，先完成 `git add`，再进入下一步

### 2. 再检查是否已经 `git commit`

在执行 `git push` 前，先确认本轮改动已经成功生成 commit。

推荐检查：

```bash
git status --short
git log -1 --oneline
```

要求：

* 如果 `git status --short` 仍显示 staged 但未提交内容，说明 `git commit` 尚未完成
* 只有确认 commit 已成功创建后，才能进入 `git push`

### 3. 最后执行 `git push`

只有在确认：

* 本轮文件已经正确 `git add`
* 本轮 commit 已成功创建

之后，才能执行 `git push`。

推荐执行：

```bash
git push origin <branch>
```

补充要求：

* 不要把 `git add`、`git commit`、`git push` 并行执行
* 每一步完成后先检查结果，再执行下一步
* 如果某一步失败，先处理失败原因，不要直接继续下一步

---

## Commit Message 规则

默认格式：

```bash
feat(sprint-xx): 中文描述
```

示例：

```bash
feat(sprint-28): 新增 OCR 结果预览
```

补充要求：

* `commit message` 使用中文描述
* `sprint-xx` 与当前 Sprint 保持一致
* 描述聚焦本轮用户可感知的结果，不写过程性措辞

