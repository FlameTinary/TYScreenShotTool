# Sprint 32 Long Capture OCR / AI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在长截图模式中增加 `OCR` 与 `AI` 入口，让用户可以基于当前已拼接出的长图结果执行识别与分析，同时保持长截图会话可继续滚动追加。

**Architecture:** 继续复用现有 `OCRPreviewWindowService`、`AIAnalysisPreviewWindowService` 与长截图结果缓存，不新增长截图专用结果窗。长截图控制面板负责暴露新入口，`CaptureSessionService` 负责串联长图结果、单窗互斥规则与 AI 异步失效保护，预览窗服务只补充“当前位于左侧还是右侧”的定位信息供结果窗反向摆放。

**Tech Stack:** Swift 6, AppKit, SwiftUI app shell, ScreenCaptureKit, Vision, 现有 AIAnalysisService / OCRService

---

## File Structure

- Create: `TYScreenShotTool/Shared/Models/PreviewPlacementSide.swift`
  - 提供 `left / right` 及 `opposite` 能力，供长截图预览窗与 `OCR` / `AI` 结果窗共享
- Modify: `TYScreenShotTool/Services/ScrollingCapturePanelService.swift`
  - 扩展长截图底部操作面板按钮与回调，从 `取消 / 保存 / 复制` 扩成 `取消 / OCR / AI / 保存 / 复制`
- Modify: `TYScreenShotTool/Services/ScrollingCapturePreviewWindowService.swift`
  - 暴露当前预览窗是位于选区左侧还是右侧，供 `OCR` / `AI` 结果窗反向摆放
- Modify: `TYScreenShotTool/Services/OCRPreviewWindowService.swift`
  - 在保留普通截图调用方式的前提下，增加一个可选的“优先摆放侧”参数
- Modify: `TYScreenShotTool/Services/AIAnalysisPreviewWindowService.swift`
  - 在保留普通截图调用方式的前提下，增加一个可选的“优先摆放侧”参数
- Modify: `TYScreenShotTool/Services/CaptureSessionService.swift`
  - 增加长截图模式下的 `OCR` / `AI` 入口、单窗互斥逻辑、AI 异步失效保护
- Modify: `TYScreenShotTool/App/TYScreenShotToolApp.swift`
  - 连接长截图控制面板新增的 `OCR` / `AI` 回调
- Modify: `TASK.md`
  - 计划完成后按结果更新当前任务状态
- Modify: `docs/ROADMAP.md`
  - 计划完成后按结果更新 Sprint 32 状态
- Modify: `docs/SPRINTS/Sprint-32.md`
  - 计划完成后补充实际结果
- Modify: `docs/DEVLOG.md`
  - 计划完成后记录 Sprint 32 实现与验证结果

说明：
- 当前项目没有独立 test target，本轮不新建测试工程，验证以 `./scripts/build.sh` 构建通过与人工场景验证为主。
- 本轮不改普通编辑模式的 `OCR` / `AI` 行为，也不扩展长截图标注能力。

---

### Task 1: 扩展长截图控制面板入口

**Files:**
- Modify: `TYScreenShotTool/Services/ScrollingCapturePanelService.swift`

- [ ] **Step 1: 先阅读长截图控制面板当前实现，确认按钮数量、宽度和回调接线方式**

Read:

```swift
final class ScrollingCapturePanelService {
    var onCopyRequested: (() -> Void)?
    var onSaveRequested: (() -> Void)?
    var onCancelRequested: (() -> Void)?
}
```

Expected: 当前只有 `取消 / 保存 / 复制` 三个入口。

- [ ] **Step 2: 在面板 service 中增加 `OCR` / `AI` 回调属性**

Add:

```swift
var onOCRRequested: (() -> Void)?
var onAIRequested: (() -> Void)?
```

Expected: service 层能把新动作向上抛出，而不在视图层直接依赖 `CaptureSessionService`。

- [ ] **Step 3: 扩展长截图面板视图，增加 `OCR` / `AI` 按钮**

Update the panel view structure to include:

```swift
private let ocrButton = NSButton(title: "OCR", target: nil, action: nil)
private let aiButton = NSButton(title: "AI", target: nil, action: nil)
```

and callbacks:

```swift
var onOCRRequested: (() -> Void)?
var onAIRequested: (() -> Void)?
```

Expected: 面板视图具备五个动作入口，命名与普通编辑态保持一致。

- [ ] **Step 4: 调整面板布局，从 3 等分改为 5 等分**

Update layout logic to compute:

```swift
let buttonWidth = (bounds.width - paddingX * 2 - buttonSpacing * 4) / 5
```

and place buttons in this order:

```swift
cancelButton
ocrButton
aiButton
saveButton
copyButton
```

Expected: 按钮顺序与 spec 一致，面板宽度相应增加，按钮不会重叠。

- [ ] **Step 5: 给 `presentCapturePanel` 调整初始面板尺寸**

Update frame size from:

```swift
CGRect(x: 0, y: 0, width: 280, height: 56)
```

to a width that fits five actions, for example:

```swift
CGRect(x: 0, y: 0, width: 440, height: 56)
```

Expected: 新按钮加入后仍保留可读间距，不出现挤压或截断。

- [ ] **Step 6: 运行构建确认面板层改动独立可编译**

Run: `./scripts/build.sh`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 7: 提交这一任务的结构性改动**

```bash
git add TYScreenShotTool/Services/ScrollingCapturePanelService.swift
git commit -m "feat(sprint-32): 扩展长截图底部操作面板"
```

Expected: 长截图面板入口层改动独立成一个小提交。

---

### Task 2: 提供共享的侧边类型并让长截图预览窗记录当前所在侧

**Files:**
- Create: `TYScreenShotTool/Shared/Models/PreviewPlacementSide.swift`
- Modify: `TYScreenShotTool/Services/ScrollingCapturePreviewWindowService.swift`

- [ ] **Step 1: 新增共享侧边类型文件**

Create:

```swift
enum PreviewPlacementSide {
    case left
    case right

    var opposite: PreviewPlacementSide {
        switch self {
        case .left:
            return .right
        case .right:
            return .left
        }
    }
}
```

Expected: 后续长截图预览窗、`OCR` 结果窗和 `AI` 结果窗都能复用同一个侧边类型。

- [ ] **Step 2: 在长截图预览窗 service 中记录当前预览窗相对选区所在侧**

Add property:

```swift
private(set) var attachmentSide: PreviewPlacementSide?
```

Expected: 外部只读，避免其他服务随意写入。

- [ ] **Step 3: 在 `presentOrUpdatePreview` 中根据现有 `placeOnLeft` 逻辑更新侧边状态**

When `placeOnLeft == true`, set:

```swift
attachmentSide = .left
```

otherwise:

```swift
attachmentSide = .right
```

Expected: 不改现有预览窗摆放结果，只把已有判断结果保存下来。

- [ ] **Step 4: 在 `dismissPreview()` 中清理侧边状态**

Add:

```swift
attachmentSide = nil
```

Expected: 长截图预览关闭后不会残留旧布局方向。

- [ ] **Step 5: 运行构建验证这一层没有引入语法问题**

Run: `./scripts/build.sh`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: 提交这一任务**

```bash
git add TYScreenShotTool/Shared/Models/PreviewPlacementSide.swift TYScreenShotTool/Services/ScrollingCapturePreviewWindowService.swift
git commit -m "feat(sprint-32): 暴露长截图预览窗口摆放侧边"
```

Expected: 侧边定位信息独立成一个小提交。

---

### Task 3: 让 OCR 结果窗支持“优先侧”定位

**Files:**
- Modify: `TYScreenShotTool/Services/OCRPreviewWindowService.swift`

- [ ] **Step 1: 在 OCR 结果窗 service 内定义可选优先侧参数，保持现有调用兼容**

Update `present` signature to:

```swift
func present(
    text: String,
    selectionRect: CGRect,
    preferredSide: PreviewPlacementSide? = nil,
    onCopy: @escaping () -> Void,
    onCancel: @escaping () -> Void
)
```

Expected: 普通截图旧调用不需要改参数，也能继续工作。

- [ ] **Step 2: 把 `frame(for:on:)` 改为接受 `preferredSide`**

Update helper signature to:

```swift
private func frame(
    for selectionRect: CGRect,
    on screen: NSScreen,
    preferredSide: PreviewPlacementSide?
) -> CGRect
```

Expected: 布局逻辑可以优先用指定侧，但仍保留原有 fallback。

- [ ] **Step 3: 在布局逻辑中加入“优先侧 + 空间不足回退”规则**

Recommended logic:

```swift
let defaultPlaceOnLeft = leftAvailableWidth >= rightAvailableWidth
let preferredPlaceOnLeft: Bool?
switch preferredSide {
case .left:
    preferredPlaceOnLeft = true
case .right:
    preferredPlaceOnLeft = false
case nil:
    preferredPlaceOnLeft = nil
}

let placeOnLeft: Bool
if let preferredPlaceOnLeft {
    let preferredWidth = preferredPlaceOnLeft ? leftAvailableWidth : rightAvailableWidth
    let oppositeWidth = preferredPlaceOnLeft ? rightAvailableWidth : leftAvailableWidth
    placeOnLeft = preferredWidth >= minWidth || preferredWidth >= oppositeWidth
} else {
    placeOnLeft = defaultPlaceOnLeft
}
```

Expected: 长截图模式能指定方向，普通模式维持“哪边空间大去哪边”。

- [ ] **Step 4: 更新 `present(...)` 调用新布局函数**

Use:

```swift
let panelFrame = frame(for: selectionRect, on: screen, preferredSide: preferredSide)
```

Expected: OCR 结果窗具备方向可配置能力。

- [ ] **Step 5: 运行构建**

Run: `./scripts/build.sh`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: 提交这一任务**

```bash
git add TYScreenShotTool/Services/OCRPreviewWindowService.swift
git commit -m "feat(sprint-32): 支持 OCR 结果窗口优先侧摆放"
```

Expected: OCR 结果窗定位改动独立可追踪。

---

### Task 4: 让 AI 结果窗支持“优先侧”定位

**Files:**
- Modify: `TYScreenShotTool/Services/AIAnalysisPreviewWindowService.swift`

- [ ] **Step 1: 为 AI 结果窗的三个入口统一增加可选优先侧参数**

Update signatures:

```swift
func presentLoading(
    selectionRect: CGRect,
    preferredSide: PreviewPlacementSide? = nil,
    message: String = "AI 正在分析...",
    onClose: @escaping () -> Void
)

func presentResult(
    result: AIAnalysisResult,
    selectionRect: CGRect,
    preferredSide: PreviewPlacementSide? = nil,
    onCopyAll: @escaping () -> Void,
    onCopyNextSteps: @escaping () -> Void,
    onRetry: @escaping () -> Void,
    onClose: @escaping () -> Void
)

func presentError(
    message: String,
    selectionRect: CGRect,
    preferredSide: PreviewPlacementSide? = nil,
    onRetry: @escaping () -> Void,
    onClose: @escaping () -> Void
)
```

Expected: 普通截图现有调用不受影响，长截图调用可显式指定摆放方向。

- [ ] **Step 2: 把 `presentPanel` 和 `frame(for:on:)` 都扩成接收优先侧**

Update:

```swift
private func presentPanel(selectionRect: CGRect, preferredSide: PreviewPlacementSide?)
private func frame(
    for selectionRect: CGRect,
    on screen: NSScreen,
    preferredSide: PreviewPlacementSide?
) -> CGRect
```

Expected: AI loading、结果、错误三态共用同一套摆放逻辑。

- [ ] **Step 3: 复制 OCR 结果窗相同的“优先侧 + 空间不足回退”逻辑**

Use the same place-on-left decision rule as Task 3.

Expected: OCR / AI 在长截图模式下的布局策略保持一致。

- [ ] **Step 4: 让三个 `present...` 入口都把 `preferredSide` 透传到 `presentPanel`**

Expected: 不会出现 loading 在一边、结果切到另一边的跳窗感。

- [ ] **Step 5: 运行构建**

Run: `./scripts/build.sh`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: 提交这一任务**

```bash
git add TYScreenShotTool/Services/AIAnalysisPreviewWindowService.swift
git commit -m "feat(sprint-32): 支持 AI 结果窗口优先侧摆放"
```

Expected: AI 结果窗定位能力独立可回溯。

---

### Task 5: 在 CaptureSessionService 中增加长截图 OCR

**Files:**
- Modify: `TYScreenShotTool/Services/CaptureSessionService.swift`
- Modify: `TYScreenShotTool/App/TYScreenShotToolApp.swift`

- [ ] **Step 1: 在 session service 里添加长截图模式下的 OCR 入口函数骨架**

Add:

```swift
func ocrScrollingCaptureResult() {
    guard isInScrollingCaptureMode, let image = scrollingCaptureResultImage else {
        return
    }
}
```

Expected: App 层和面板层新增入口开始有落点。

- [ ] **Step 2: 增加一个把预览窗所在侧映射到结果窗优先侧的小工具方法**

Add helper:

```swift
private func preferredResultSideForScrollingPreview() -> PreviewPlacementSide? {
    scrollingCapturePreviewWindowService.attachmentSide?.opposite
}
```

Expected: “预览在左，结果去右；预览在右，结果去左” 规则集中在一处。

- [ ] **Step 3: 在长截图 OCR 入口里加入单窗互斥和实际 OCR 处理**

Implement:

```swift
func ocrScrollingCaptureResult() {
    guard isInScrollingCaptureMode,
          let image = scrollingCaptureResultImage,
          let selectionRect = pendingCaptureSource?.selectionRect else {
        return
    }

    aiAnalysisPreviewWindowService.dismiss()

    Task {
        do {
            let text = try ocrService.recognizeText(in: image)
            let preferredSide = await MainActor.run { self.preferredResultSideForScrollingPreview() }
            await MainActor.run {
                ocrPreviewWindowService.present(
                    text: text,
                    selectionRect: selectionRect,
                    preferredSide: preferredSide,
                    onCopy: { [weak self] in
                        self?.copyScrollingOCRPreviewText(text)
                    },
                    onCancel: { [weak self] in
                        self?.ocrPreviewWindowService.dismiss()
                    }
                )
            }
        } catch {
            await MainActor.run {
                toastService.showToast(message: "OCR 识别失败")
            }
        }
    }
}
```

Expected: 长截图模式可以直接对当前长图做 OCR，并自动关闭已有 AI 窗口。

- [ ] **Step 4: 增加长截图模式专用的 OCR 复制处理，不结束长截图会话**

Add:

```swift
@MainActor
private func copyScrollingOCRPreviewText(_ text: String) {
    do {
        try clipboardService.copyText(text)
        toastService.showToast(message: "OCR 已复制到剪贴板")
        ocrPreviewWindowService.dismiss()
    } catch {
        toastService.showToast(message: "OCR 复制失败")
    }
}
```

Expected: 复制 OCR 结果只关闭结果窗，不退出长截图模式。

- [ ] **Step 5: 先只在 `TYScreenShotToolApp` 中接上长截图面板新增的 `OCR` 回调**

Add:

```swift
scrollingCapturePanelService.onOCRRequested = {
    sessionService.ocrScrollingCaptureResult()
}
```

Expected: OCR 新入口先独立接通，避免在 AI 入口落地前引入不可构建引用。

- [ ] **Step 6: 运行构建**

Run: `./scripts/build.sh`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 7: 提交这一任务**

```bash
git add TYScreenShotTool/Services/CaptureSessionService.swift TYScreenShotTool/App/TYScreenShotToolApp.swift
git commit -m "feat(sprint-32): 增加长截图 OCR 入口"
```

Expected: 长截图 OCR 链路独立落地，且保持中间状态可构建。

---

### Task 6: 在 CaptureSessionService 中增加长截图 AI 与异步失效保护

**Files:**
- Modify: `TYScreenShotTool/Services/CaptureSessionService.swift`

- [ ] **Step 1: 增加一个用于长截图 AI 请求失效保护的 token**

Add property:

```swift
private var scrollingAIRequestID = UUID()
```

Expected: 用户在 loading 中切到 OCR 或再次触发 AI 时，旧请求结果可以作废。

- [ ] **Step 2: 增加长截图 AI 入口函数骨架**

Add:

```swift
func analyzeScrollingCaptureResult() {
    guard isInScrollingCaptureMode,
          let image = scrollingCaptureResultImage,
          let selectionRect = pendingCaptureSource?.selectionRect else {
        return
    }
}
```

Expected: 面板新增的 AI 入口开始有处理函数。

- [ ] **Step 2.5: 在 `TYScreenShotToolApp` 中补上长截图面板的 `AI` 回调**

Add:

```swift
scrollingCapturePanelService.onAIRequested = {
    sessionService.analyzeScrollingCaptureResult()
}
```

Expected: AI 按钮在入口函数存在后再接线，避免中间状态不可编译。

- [ ] **Step 3: 在长截图 AI 入口中实现单窗互斥、loading 展示和请求 token 刷新**

Implement:

```swift
func analyzeScrollingCaptureResult() {
    guard isInScrollingCaptureMode,
          let image = scrollingCaptureResultImage,
          let selectionRect = pendingCaptureSource?.selectionRect else {
        return
    }

    ocrPreviewWindowService.dismiss()
    let requestID = UUID()
    scrollingAIRequestID = requestID
    let preferredSide = preferredResultSideForScrollingPreview()

    aiAnalysisPreviewWindowService.presentLoading(
        selectionRect: selectionRect,
        preferredSide: preferredSide,
        onClose: { [weak self] in
            self?.scrollingAIRequestID = UUID()
            self?.aiAnalysisPreviewWindowService.dismiss()
        }
    )

    Task { [weak self] in
        await self?.performScrollingAIAnalysis(
            image: image,
            selectionRect: selectionRect,
            preferredSide: preferredSide,
            requestID: requestID
        )
    }
}
```

Expected: 长截图 AI loading 能弹出，且关闭 loading 会让旧请求失效。

- [ ] **Step 4: 增加长截图专用 AI 分析执行函数**

Add:

```swift
@MainActor
private func performScrollingAIAnalysis(
    image: CGImage,
    selectionRect: CGRect,
    preferredSide: PreviewPlacementSide?,
    requestID: UUID
) async {
    do {
        let text = try ocrService.recognizeText(in: image)
        let result = try await aiAnalysisService.analyzeDeveloperError(text: text)
        guard requestID == scrollingAIRequestID, isInScrollingCaptureMode else {
            return
        }

        aiAnalysisPreviewWindowService.presentResult(
            result: result,
            selectionRect: selectionRect,
            preferredSide: preferredSide,
            onCopyAll: { [weak self] in
                self?.copyAIAnalysisResult(result.formattedText)
            },
            onCopyNextSteps: { [weak self] in
                self?.copyAIAnalysisNextSteps(result.nextSteps)
            },
            onRetry: { [weak self] in
                self?.retryScrollingAIAnalysis()
            },
            onClose: { [weak self] in
                self?.aiAnalysisPreviewWindowService.dismiss()
            }
        )
    } catch let error as OCRError {
        guard requestID == scrollingAIRequestID, isInScrollingCaptureMode else {
            return
        }
        toastService.showToast(message: "OCR 未识别到有效文本")
        aiAnalysisPreviewWindowService.presentError(
            message: error.localizedDescription,
            selectionRect: selectionRect,
            preferredSide: preferredSide,
            onRetry: { [weak self] in
                self?.retryScrollingAIAnalysis()
            },
            onClose: { [weak self] in
                self?.aiAnalysisPreviewWindowService.dismiss()
            }
        )
    } catch let error as AIAnalysisError {
        guard requestID == scrollingAIRequestID, isInScrollingCaptureMode else {
            return
        }
        toastService.showToast(message: "AI 分析失败")
        aiAnalysisPreviewWindowService.presentError(
            message: error.localizedDescription,
            selectionRect: selectionRect,
            preferredSide: preferredSide,
            onRetry: { [weak self] in
                self?.retryScrollingAIAnalysis()
            },
            onClose: { [weak self] in
                self?.aiAnalysisPreviewWindowService.dismiss()
            }
        )
    } catch {
        guard requestID == scrollingAIRequestID, isInScrollingCaptureMode else {
            return
        }
        toastService.showToast(message: "AI 分析失败")
        aiAnalysisPreviewWindowService.presentError(
            message: error.localizedDescription,
            selectionRect: selectionRect,
            preferredSide: preferredSide,
            onRetry: { [weak self] in
                self?.retryScrollingAIAnalysis()
            },
            onClose: { [weak self] in
                self?.aiAnalysisPreviewWindowService.dismiss()
            }
        )
    }
}
```

Expected: 结果、错误和 loading 都能复用现有 AI 结果窗，同时旧请求结果不会晚到覆盖当前状态。

- [ ] **Step 5: 增加长截图 AI 的重试入口**

Add:

```swift
@MainActor
private func retryScrollingAIAnalysis() {
    guard isInScrollingCaptureMode else {
        return
    }

    analyzeScrollingCaptureResult()
}
```

Expected: 长截图 AI 错误态和结果态都能重试。

- [ ] **Step 6: 在取消/结束长截图会话时让旧 AI 请求失效**

In `cancelScrollingCapture()`, `finishScrollingCaptureSession()`, and `failScrollingCapture(...)`, add:

```swift
scrollingAIRequestID = UUID()
```

Expected: 会话结束后异步结果不会重新弹窗。

- [ ] **Step 7: 运行完整构建**

Run: `./scripts/build.sh`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 8: 提交这一任务**

```bash
git add TYScreenShotTool/Services/CaptureSessionService.swift
git commit -m "feat(sprint-32): 增加长截图 AI 分析入口"
```

Expected: 长截图 AI 与异步失效保护独立收口。

---

### Task 7: 人工验证长截图 OCR / AI 主链路

**Files:**
- Modify: none

- [ ] **Step 1: 构建最新工程**

Run: `./scripts/build.sh`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 2: 验证长截图面板按钮已扩展**

Manual check:

```text
1. 触发截图
2. 进入编辑态
3. 点击“长截图”
4. 确认底部面板出现：取消 / OCR / AI / 保存 / 复制
```

Expected: 五个按钮可见，顺序正确，无重叠。

- [ ] **Step 3: 验证首帧即可 OCR**

Manual check:

```text
1. 进入长截图模式后先不要滚动
2. 直接点击 OCR
3. 确认 OCR 窗口出现
4. 关闭 OCR 窗口
5. 继续滚动，确认长截图仍可继续追加
```

Expected: OCR 可用，关闭后长截图不中断。

- [ ] **Step 4: 验证首帧即可 AI**

Manual check:

```text
1. 进入长截图模式后先不要滚动
2. 直接点击 AI
3. 确认出现 loading，随后出现结果或明确错误
4. 关闭窗口后继续滚动，确认长截图仍可继续追加
```

Expected: AI 分析可用，关闭后长截图不中断。

- [ ] **Step 5: 验证结果窗与长截图预览窗反向摆放**

Manual check:

```text
1. 在一个布局下让长截图预览窗出现在左侧，触发 OCR 或 AI
2. 确认结果窗优先出现在右侧
3. 在另一个布局下让长截图预览窗出现在右侧，重复操作
4. 确认结果窗优先出现在左侧
```

Expected: 结果窗与预览窗分居两侧，空间不足时仍保持可见。

- [ ] **Step 6: 验证单窗互斥与 AI 异步失效**

Manual check:

```text
1. 点击 AI，进入 loading
2. 在 loading 期间点击 OCR
3. 确认 AI 窗口消失，只出现 OCR 窗口
4. 等待原 AI 请求返回，确认旧 AI 结果不会重新弹出
5. 反向再验证：先打开 OCR，再点击 AI，确认 OCR 自动关闭
```

Expected: 同一时刻只保留一个结果窗，旧 AI 请求不会晚到覆盖当前界面。

- [ ] **Step 7: 验证长截图原有主链路未回归**

Manual check:

```text
1. 长截图过程中继续滚动，确认仍自动追加
2. 点击复制，确认复制成功并结束长截图会话
3. 重新进入长截图模式，点击保存，确认保存成功并结束会话
4. 再次进入长截图模式，点击取消，确认直接退出整个截图会话
```

Expected: 长截图复制、保存、取消、继续追加都保持正常。

---

### Task 8: 更新 Sprint 32 结果文档

**Files:**
- Modify: `TASK.md`
- Modify: `docs/SPRINTS/Sprint-32.md`
- Modify: `docs/ROADMAP.md`
- Modify: `docs/DEVLOG.md`

- [ ] **Step 1: 更新 `TASK.md` 当前状态**

Set:

```md
Current Sprint: Sprint 32 Completed

## 当前状态

Sprint 32 已完成并通过人工验证。
```

Expected: 当前任务状态从规划态切换到完成态。

- [ ] **Step 2: 更新 `docs/SPRINTS/Sprint-32.md`**

Change:

```md
## Status

Completed
```

and fill `## Result` with concrete outcomes:

```md
Completed

- 长截图面板已增加 `OCR` 与 `AI` 入口
- 长截图模式可基于当前长图结果执行 `OCR` 与 `AI`
- `OCR` / `AI` 不再结束长截图会话，关闭结果窗后可继续滚动追加
- 结果窗会优先出现在长截图预览窗对侧
- 长截图模式下同一时刻只保留一个结果窗
- `AI` loading 被切走后，旧结果不会重新弹出
- `./scripts/build.sh` 构建通过
- 人工验证通过
```

Expected: Sprint 文档完整闭环。

- [ ] **Step 3: 更新 `docs/ROADMAP.md`**

Replace `Sprint 32` section from planned to done:

```md
状态：
✅ Done
```

and convert goals to成果列表。

Expected: 路线图与实际实现状态一致。

- [ ] **Step 4: 更新 `docs/DEVLOG.md`**

Add a `2026-06-20 / Sprint 32 完成` entry covering:

```text
- 长截图面板增加 OCR / AI
- 长图结果可直接 OCR / AI
- 结果窗按长截图预览对侧摆放
- 单窗互斥与 AI 异步失效保护
- 构建通过
- 人工验证通过
```

Expected: 开发日志补齐本轮实现与验证结果。

- [ ] **Step 5: 提交文档收尾**

```bash
git add TASK.md docs/SPRINTS/Sprint-32.md docs/ROADMAP.md docs/DEVLOG.md
git commit -m "docs(sprint-32): 更新 Sprint 32 完成状态"
```

Expected: Sprint 32 收尾文档单独成一个提交。

---

## Self-Review

- Spec coverage：已覆盖长截图面板新增 `OCR` / `AI` 入口、基于当前长图执行分析、结果窗与预览窗对侧摆放、单窗互斥、AI 异步失效保护、主链路不回归与文档收尾。
- Placeholder scan：没有使用 `TODO`、`TBD`、"适当处理" 这类占位描述；每个代码步骤都给出了目标签名或核心实现片段。
- Type consistency：计划统一使用 `ocrScrollingCaptureResult()`、`analyzeScrollingCaptureResult()`、`preferredResultSideForScrollingPreview()`、`scrollingAIRequestID` 这些名称；`preferredSide` 在 OCR / AI 结果窗中保持同名透传。

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-06-20-sprint-32-long-capture-ocr-ai.md`. Two execution options:

1. Subagent-Driven (recommended) - I dispatch a fresh subagent per task, review between tasks, fast iteration

2. Inline Execution - Execute tasks in this session using executing-plans, batch execution with checkpoints

Which approach?
