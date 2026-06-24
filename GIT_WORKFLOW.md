# GIT_WORKFLOW.md

# Git 工作流

本文档定义项目 Git 分支管理、开发流程、提交规范和发布流程。

所有开发任务均需遵守本规范。

---

# 工作流目标

目标：

* 保持 main 分支稳定
* 支持功能并行开发
* 保持提交历史清晰
* 降低回滚成本
* 保持代码可发布状态

原则：

* 稳定优先
* 简单优先
* 可回滚优先

---

# 分支模型

项目采用双主线开发模式：

```text
main
 ↑
 │
dev
 ↑
 │
feature/*
```

| 分支        | 用途      |
| --------- | ------- |
| main      | 已上线稳定版本 |
| dev       | 当前开发主线  |
| feature/* | 功能开发分支  |

---

# main 分支

main 代表：

* 已上线版本
* 已验证版本
* 可随时发布版本

规则：

* 保持稳定
* 禁止直接开发
* 禁止直接提交
* 禁止直接修复功能

允许：

* 从 dev 合并
* 创建版本 Tag

---

# dev 分支

dev 代表：

* 下一版本开发主线
* 当前集成环境

规则：

* 所有功能最终合并到 dev
* 所有功能在 dev 完成集成验证
* dev 验证通过后再发布到 main

允许：

* Feature 合并
* Bug 修复
* 集成测试

---

# Feature 分支

命名规范：

```text
feature/功能名称
```

示例：

```text
feature/screenshot-save

feature/ocr

feature/settings

feature/upload-image
```

规则：

* 必须从 dev 创建
* 一个分支只负责一个功能
* 开发完成后合并回 dev
* 功能完成后删除分支

禁止：

* 一个分支开发多个功能
* 长期不合并

---

# 标准开发流程

## 1. 创建功能分支

基于最新 dev 创建：

```bash
git checkout dev

git pull origin dev

git checkout -b feature/xxx
```

---

## 2. 功能开发

开发过程中：

* 小步提交
* 保持代码可编译
* 保持功能可运行

推荐频繁提交：

```bash
git add .

git commit
```

---

## 3. 同步最新 dev

如果开发周期较长：

推荐：

```bash
git fetch origin

git rebase origin/dev
```

避免：

```bash
git merge dev
```

产生无意义 Merge Commit。

---

## 4. 功能验证

功能完成后必须验证：

* 编译通过
* 自动测试通过（如存在）
* 功能符合需求
* 无明显回归问题

---

## 5. 合并到 dev

推荐：

```bash
git checkout dev

git pull origin dev

git merge --squash feature/xxx
```

然后：

```bash
git commit
```

项目默认采用：

```text
Squash Merge
```

目的：

* 保持提交历史整洁
* 降低提交噪音
* 提高可读性

---

## 6. 删除功能分支

合并完成后：

```bash
git branch -d feature/xxx

git push origin --delete feature/xxx
```

---

# 发布流程

发布流程：

```text
feature/*
    ↓
dev
    ↓
集成验证
    ↓
main
    ↓
Tag
    ↓
发布
```

---

## 发布步骤

切换 main：

```bash
git checkout main

git pull origin main
```

合并 dev：

```bash
git merge dev
```

推送：

```bash
git push origin main
```

---

# 版本 Tag

每次正式发布必须创建版本 Tag。

示例：

```bash
git tag v1.0.0

git push origin v1.0.0
```

后续：

```bash
git tag v1.1.0

git tag v1.1.1

git tag v2.0.0
```

---

# Tag 规范

格式：

```text
v主版本.次版本.修订版本
```

示例：

```text
v1.0.0

v1.1.0

v1.1.1

v2.0.0
```

---

# Commit 规范

Commit Message 使用中文。

格式：

```text
type(scope): 中文描述
```

示例：

```text
feat(capture): 支持截图保存

feat(ocr): 新增 OCR 识别功能

feat(settings): 新增快捷键配置界面

fix(hotkey): 修复快捷键注册失效问题

fix(capture): 修复多显示器截图偏移问题

refactor(storage): 抽离图片保存服务

docs(readme): 更新使用说明
```

---

# Commit 类型

| 类型       | 说明     |
| -------- | ------ |
| feat     | 新功能    |
| fix      | Bug 修复 |
| refactor | 重构     |
| docs     | 文档     |
| test     | 测试     |
| chore    | 工程维护   |

---

# Commit 原则

要求：

* 小步提交
* 保持可运行
* 一个 Commit 一个目的

禁止：

一个 Commit 同时包含：

* 新功能
* Bug 修复
* 重构

错误示例：

```text
feat: 新增 OCR 并修复快捷键问题同时重构截图模块
```

正确示例：

```text
feat(ocr): 新增 OCR 识别功能

fix(hotkey): 修复快捷键注册问题

refactor(capture): 简化截图流程
```

---

# Rebase 规则

允许：

* Feature 分支同步最新 dev
* 整理个人提交历史

示例：

```bash
git rebase origin/dev
```

禁止：

* 对 main 执行 rebase
* 对 dev 执行 rebase
* 对公共分支执行 rebase

原则：

仅在个人 Feature 分支使用 Rebase。

---

# 回滚策略

出现问题时：

优先回滚 Feature。

推荐：

```bash
git revert commit-id
```

避免：

```bash
git reset --hard
```

除非明确需要重置本地历史。

---

# AI 开发规则

开发前：

必须确认当前分支。

禁止：

在 main 分支直接开发。

默认流程：

```text
确认当前分支

↓

创建 Feature 分支

↓

开发

↓

验证

↓

合并 dev

↓

集成验证

↓

合并 main

↓

创建 Tag

↓

发布
```

---

# 最终原则

main：

永远稳定。

dev：

持续开发。

feature：

独立功能。

核心目标：

保持代码可发布、可回滚、可维护。
