# Sprint 31 窗口悬停选择 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为现有截图起手阶段增加“悬停整个应用窗口并点击确认”的最小交互，同时保持当前自由拖拽框选流程可用。

**Architecture:** 保持 `CaptureSessionService` 主状态机不扩张，把窗口候选预览作为 `CaptureOverlayView` 的选择阶段内部交互。新增一个聚焦的窗口查询服务负责基于鼠标位置命中整个应用窗口，并且不直接手写复杂跨屏坐标换算：优先返回与当前 `NSScreen.frame` 对齐的单屏窗口矩形，只让完全落在当前鼠标所在屏幕内的窗口进入候选。`CaptureOverlayService` 负责把查询结果接到 Overlay 视图上；点击确认窗口时，新增一个专门的“窗口确认选区”入口，让会话层在不依赖 `dragging` 状态的前提下进入当前编辑态。

**Tech Stack:** Swift 6、AppKit、CoreGraphics、现有 `CaptureOverlayService` / `CaptureSessionService` 架构、`./scripts/build.sh`

---

## 规划说明

- 当前仓库没有 XCTest target。
- 因此本计划以 `./scripts/build.sh` 和人工验证作为主要验收手段。
- 但实现时仍应把“窗口命中逻辑”和“Overlay 交互逻辑”分开，避免把窗口查询细节直接塞进 `CaptureOverlayView`。

## 文件结构

### 新增文件

- `TYScreenShotTool/Services/WindowSelectionService.swift`
  负责读取当前屏幕窗口列表、过滤无效项、根据鼠标屏幕坐标命中当前整个应用窗口，并只返回完全落在当前鼠标所在屏幕内、可直接与该 `NSScreen.frame` 对齐使用的单屏窗口矩形。

### 修改文件

- `TYScreenShotTool/Features/CaptureOverlay/CaptureOverlayView.swift`
  增加选择阶段下的窗口候选预览、点击确认、按下后拖拽切回自由框选逻辑。

- `TYScreenShotTool/Services/CaptureOverlayService.swift`
  注入窗口查询闭包，负责把当前鼠标位置对应的屏幕坐标窗口矩形传给 Overlay 视图，并转发“点击确认的最终窗口矩形”。

- `TYScreenShotTool/Services/CaptureSessionService.swift`
  增加专门的窗口确认入口，使“点击候选窗口”不依赖当前 `dragging` 状态也能进入现有编辑态。

- `TYScreenShotTool/App/TYScreenShotToolApp.swift`
  在应用入口处装配 `WindowSelectionService`，并把查询能力连接到 `CaptureOverlayService`。

- `README.md`
  当前状态与截图流程已对齐到 `Sprint 31`，无需额外调整，除非实现阶段发现交互描述需要补充。

- `TASK.md`
  当前已对齐到 `Sprint 31`，实现完成后再按结果更新。

- `docs/SPRINTS/Sprint-31.md`
  当前已创建为 `Planned`，实现完成后再更新结果。

---

### Task 1: 新增窗口命中服务

**Files:**
- Create: `TYScreenShotTool/Services/WindowSelectionService.swift`

- [ ] **Step 1: 新增窗口查询结果类型与服务骨架**

```swift
import AppKit
import CoreGraphics

struct WindowSelectionCandidate {
    let frame: CGRect
    let ownerName: String
}

final class WindowSelectionService {
    func candidateWindow(at screenPoint: CGPoint) -> WindowSelectionCandidate? {
        guard let screen = screenContaining(screenPoint) else {
            return nil
        }

        guard let windowInfos = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        for windowInfo in windowInfos {
            guard let candidate = candidate(from: windowInfo, on: screen), candidate.frame.contains(screenPoint) else {
                continue
            }

            return candidate
        }

        return nil
    }
}
```

- [ ] **Step 2: 实现窗口过滤与矩形解析**

```swift
private extension WindowSelectionService {
    func candidate(from windowInfo: [String: Any], on screen: NSScreen) -> WindowSelectionCandidate? {
        guard let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
              ownerPID != ProcessInfo.processInfo.processIdentifier else {
            return nil
        }

        guard let cgBounds = windowInfo[kCGWindowBounds as String] as? [String: Any],
              let cgFrame = CGRect(dictionaryRepresentation: cgBounds as CFDictionary),
              cgFrame.width > 40,
              cgFrame.height > 40 else {
            return nil
        }

        let ownerName = (windowInfo[kCGWindowOwnerName as String] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard ownerName.isEmpty == false else {
            return nil
        }

        let layer = windowInfo[kCGWindowLayer as String] as? Int ?? 0
        guard layer == 0 else {
            return nil
        }

        let alpha = windowInfo[kCGWindowAlpha as String] as? Double ?? 1
        guard alpha > 0 else {
            return nil
        }

        guard let frame = appKitScreenFrame(from: cgFrame, on: screen),
              frameContainedInScreen(frame, screen: screen) else {
            return nil
        }

        return WindowSelectionCandidate(frame: frame, ownerName: ownerName)
    }
}
```

- [ ] **Step 3: 补充单屏过滤辅助方法，并明确只接受与当前屏幕对齐的候选窗口**

```swift
private extension WindowSelectionService {
    func frameContainedInScreen(_ frame: CGRect, screen: NSScreen) -> Bool {
        return screen.frame.minX <= frame.minX &&
            screen.frame.maxX >= frame.maxX &&
            screen.frame.minY <= frame.minY &&
            screen.frame.maxY >= frame.maxY
    }

    func screenContaining(_ point: CGPoint) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(point) }
    }
}
```

- [ ] **Step 4: 运行构建验证新增文件未破坏工程**

Run: `./scripts/build.sh`
Expected: `** BUILD SUCCEEDED **`

---

### Task 2: 在 Overlay 选择阶段增加窗口候选预览

**Files:**
- Modify: `TYScreenShotTool/Features/CaptureOverlay/CaptureOverlayView.swift`

- [ ] **Step 1: 增加窗口候选回调与选择阶段状态字段**

```swift
var windowCandidateProvider: ((CGPoint) -> CGRect?)?
var onWindowSelectionConfirmed: ((CGRect) -> Void)?

private var hoveredWindowRect: CGRect?
private var mouseDownPoint: CGPoint?
private var mouseDownWindowRect: CGRect?
private var isPendingWindowClickConfirmation = false
private static let dragActivationDistance: CGFloat = 4
```

- [ ] **Step 2: 调整 `draw(_:)`，在选择阶段优先显示候选窗口高亮**

```swift
override func draw(_ dirtyRect: NSRect) {
    if selectionSourceScreenImage != nil, suppressFrozenBackground == false {
        drawSelectionBackground(in: dirtyRect)
    }

    let activeRect: CGRect?
    switch mode {
    case .selection:
        activeRect = selectionRect ?? hoveredWindowRect
    case .preview:
        activeRect = previewSelectionRect
    }

    if isLongCaptureGuideMode == false {
        if let activeRect {
            let overlayPath = NSBezierPath(rect: bounds)
            let cutoutPath = cutoutPath(for: activeRect)
            overlayPath.append(cutoutPath)
            overlayPath.windingRule = .evenOdd
            NSColor.black.withAlphaComponent(0.35).setFill()
            overlayPath.fill()
        } else {
            NSColor.black.withAlphaComponent(0.35).setFill()
            bounds.fill()
        }
    }

    switch mode {
    case .selection:
        guard let rect = selectionRect ?? hoveredWindowRect else {
            return
        }

        NSColor.white.setStroke()
        let path = NSBezierPath(rect: rect)
        path.lineWidth = 2
        path.stroke()
    case .preview:
        guard let previewSelectionRect else {
            return
        }

        NSColor.white.setStroke()
        let path = NSBezierPath(rect: previewSelectionRect)
        path.lineWidth = 2
        path.stroke()
    }
}
```

- [ ] **Step 3: 增加候选窗口更新方法**

```swift
private func refreshHoveredWindowCandidate(at point: CGPoint) {
    guard mode == .selection, isDragging == false else {
        return
    }

    hoveredWindowRect = windowCandidateProvider?(point)
    needsDisplay = true
}
```

- [ ] **Step 4: 在 `mouseMoved` 和 `cursorUpdate` 中接入候选窗口刷新**

```swift
override func mouseMoved(with event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)
    refreshHoveredWindowCandidate(at: point)
    updateCursor(for: point)
}

override func cursorUpdate(with event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)
    refreshHoveredWindowCandidate(at: point)
    updateCursor(for: point)
}
```

- [ ] **Step 5: 运行构建验证**

Run: `./scripts/build.sh`
Expected: `** BUILD SUCCEEDED **`

---

### Task 3: 实现点击确认与拖拽分叉

**Files:**
- Modify: `TYScreenShotTool/Features/CaptureOverlay/CaptureOverlayView.swift`

- [ ] **Step 1: 重写选择阶段的 `mouseDown`，先刷新候选窗口，再记录点击候选态**

```swift
override func mouseDown(with event: NSEvent) {
    if mode == .preview {
        handlePreviewMouseDown(with: event)
        return
    }

    guard mode == .selection else {
        super.mouseDown(with: event)
        return
    }

    window?.makeFirstResponder(self)
    let point = convert(event.locationInWindow, from: nil)
    refreshHoveredWindowCandidate(at: point)
    mouseDownPoint = point
    mouseDownWindowRect = hoveredWindowRect
    isPendingWindowClickConfirmation = hoveredWindowRect != nil
    updateCursor(for: point)
}
```

- [ ] **Step 2: 在选择阶段的 `mouseDragged` 中超过阈值后切到现有自由框选**

```swift
override func mouseDragged(with event: NSEvent) {
    if mode == .preview {
        handlePreviewMouseDragged(with: event)
        return
    }

    guard mode == .selection else {
        super.mouseDragged(with: event)
        return
    }

    let point = constrainedPoint(for: event)

    if isDragging == false, let startPoint = mouseDownPoint {
        let deltaX = point.x - startPoint.x
        let deltaY = point.y - startPoint.y
        let distance = hypot(deltaX, deltaY)

        guard distance >= Self.dragActivationDistance else {
            updateCursor(for: point)
            return
        }

        dragStartPoint = startPoint
        currentPoint = point
        isDragging = true
        isPendingWindowClickConfirmation = false
        hoveredWindowRect = nil
        onDragStarted?()
        needsDisplay = true
        updateCursor(for: point)
        return
    }

    guard isDragging else {
        updateCursor(for: point)
        return
    }

    currentPoint = point
    needsDisplay = true
    updateCursor(for: point)
}
```

- [ ] **Step 3: 在选择阶段的 `mouseUp` 中区分点击确认与自由框选完成**

```swift
override func mouseUp(with event: NSEvent) {
    if mode == .preview {
        handlePreviewMouseUp(with: event)
        return
    }

    guard mode == .selection else {
        super.mouseUp(with: event)
        return
    }

    let point = constrainedPoint(for: event)

    defer {
        mouseDownPoint = nil
        mouseDownWindowRect = nil
        isPendingWindowClickConfirmation = false
    }

    if isDragging {
        currentPoint = point
        isDragging = false
        needsDisplay = true

        if let selectionRect {
            onSelection?(selectionRect)
        }

        updateCursor(for: point)
        return
    }

    if isPendingWindowClickConfirmation, let windowRect = mouseDownWindowRect {
        onWindowSelectionConfirmed?(windowRect)
        return
    }

    refreshHoveredWindowCandidate(at: point)
    updateCursor(for: point)
}
```

- [ ] **Step 4: 在 `resetToSelectionMode()` 中清理新增交互状态**

```swift
func resetToSelectionMode() {
    mode = .selection
    isLongCaptureGuideMode = false
    suppressFrozenBackground = false
    dragStartPoint = nil
    currentPoint = nil
    isDragging = false
    mouseDownPoint = nil
    mouseDownWindowRect = nil
    hoveredWindowRect = nil
    isPendingWindowClickConfirmation = false
    hoverInteractionTarget = .none
    activeInteractionTarget = .none
    interactionStartMousePoint = nil
    interactionStartSelectionRect = nil
    previewSelectionLocked = false
    previewSelectionRect = nil
    selectionSourceScreenImage = nil
    previewSourceScreenImage = nil
    previewSourceScreenFrame = nil
    previewImageView.image = nil
    currentAnnotationTool = nil
    annotationCanvasView.resetAnnotations()
    annotationCanvasView.sourceImage = nil
    previewContainerView.isHidden = true
    topBarContainerView.isHidden = true
    toolbarContainerView.isHidden = true
    aiButton.isEnabled = true
    needsDisplay = true
    NSCursor.crosshair.set()
}
```

- [ ] **Step 5: 运行构建验证**

Run: `./scripts/build.sh`
Expected: `** BUILD SUCCEEDED **`

---

### Task 4: 连接 Overlay 服务与窗口查询服务

**Files:**
- Modify: `TYScreenShotTool/Services/CaptureOverlayService.swift`
- Modify: `TYScreenShotTool/Services/CaptureSessionService.swift`
- Modify: `TYScreenShotTool/App/TYScreenShotToolApp.swift`

- [ ] **Step 1: 在 `CaptureOverlayService` 中增加窗口查询依赖和窗口确认回调声明**

```swift。dj f kd ls j f ie o ri df kf j
final class CaptureOverlayService {
    var onCancel: (() -> Void)?
    var onDragStarted: (() -> Void)?
    var onSelectionCompleted: ((CGRect) -> Void)?
    var onWindowSelectionConfirmed: ((CGRect) -> Void)?
    var onPreviewSelectionChanged: ((CGRect) -> Void)?
    var windowCandidateProvider: ((CGPoint) -> CGRect?)?
```

- [ ] **Step 2: 在 `presentOverlay` 中把窗口查询闭包和确认回调接到视图上**

```swift
overlayView.windowCandidateProvider = { [weak self] localPoint in
    guard let self, let window = overlayView.window else {
        return nil
    }

    let screenPoint = window.convertToScreen(CGRect(origin: localPoint, size: .zero)).origin
    guard let rect = self.windowCandidateProvider?(screenPoint) else {
        return nil
    }

    return window.convertFromScreen(rect)
}

overlayView.onWindowSelectionConfirmed = { [weak self] rect in
    guard let self, let window = overlayView.window else {
        return
    }

    self.onWindowSelectionConfirmed?(window.convertToScreen(rect))
}
```

- [ ] **Step 3: 在 `CaptureSessionService` 中增加窗口确认入口**

```swift
func confirmWindowSelection(_ rect: CGRect) {
    guard state == .overlayPresented else {
        return
    }

    guard rect.width > 1, rect.height > 1 else {
        return
    }

    transition(to: .selectionCompleted)
    logSelection(rect)
    pendingSelectionRect = rect
    overlayService.showSelectionPreview(selectionRect: rect, screenImages: pendingScreenImages)
}
```

- [ ] **Step 4: 在应用入口装配 `WindowSelectionService` 和窗口确认回调**

```swift
let windowSelectionService = WindowSelectionService()

overlayService.windowCandidateProvider = { screenPoint in
    windowSelectionService.candidateWindow(at: screenPoint)?.frame
}

overlayService.onWindowSelectionConfirmed = { rect in
    sessionService.confirmWindowSelection(rect)
}
```

- [ ] **Step 5: 运行构建验证**

Run: `./scripts/build.sh`
Expected: `** BUILD SUCCEEDED **`

---

### Task 5: 人工验证与文档收尾

**Files:**
- Modify: `TASK.md`
- Modify: `docs/SPRINTS/Sprint-31.md`
- Modify: `docs/ROADMAP.md`
- Modify: `docs/DEVLOG.md`

- [ ] **Step 1: 执行构建验证**

Run: `./scripts/build.sh`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 2: 执行人工验证**

Run these checks manually:

```text
1. 按热键后，把鼠标移动到普通应用窗口上，确认出现与窗口边界一致的高亮候选框。
2. 把鼠标移动到另一个窗口上，确认候选高亮随之切换。
3. 把鼠标移到桌面空白区域，确认不显示候选窗口高亮。
4. 当出现候选窗口时，轻点鼠标左键，确认直接进入现有编辑态。
5. 重新触发截图，按下鼠标并拖拽，确认走现有自由框选流程。
6. 通过窗口悬停进入编辑态后，验证复制、保存、OCR、AI、Pin、长截图主链路仍正常。
```

Expected: 所有场景通过，无崩溃、无错误进入编辑态、无自由框选退化。

- [ ] **Step 3: 更新 `TASK.md` 为完成状态**

```md
# TShot

Version: V0.8

Current Sprint: Sprint 31 Completed

---

## 当前状态

Sprint 31 已完成并通过人工验证。

## 当前目标

已完成最小 `窗口悬停选择` 起手体验，
用户可以通过：

`悬停窗口 -> 点击确认`

直接进入现有截图编辑态。
```

- [ ] **Step 4: 更新 `docs/SPRINTS/Sprint-31.md` 结果**

```md
## Status

Completed

## Result

Completed

- 已支持热键触发后的窗口悬停候选高亮
- 已支持点击候选窗口直接进入现有编辑态
- 已保持按下拖拽时继续走现有自由框选流程
- 已实现空白区域与无效窗口回退为普通待命状态
- `./scripts/build.sh` 构建通过
- 人工验证通过
```

- [ ] **Step 5: 更新 `docs/ROADMAP.md` 与 `docs/DEVLOG.md`**

```md
### Sprint 31

窗口悬停选择

状态：
✅ Done

成果：

- 热键触发后支持悬停命中整个应用窗口
- 点击候选窗口后直接进入现有编辑态
- 保持按下拖拽时继续走现有自由框选流程
- 空白区域或无效窗口时回退为普通待命状态
```

- [ ] **Step 6: 提交文档与代码**

```bash
git add TYScreenShotTool/Services/WindowSelectionService.swift \
  TYScreenShotTool/Features/CaptureOverlay/CaptureOverlayView.swift \
  TYScreenShotTool/Services/CaptureOverlayService.swift \
  TYScreenShotTool/App/TYScreenShotToolApp.swift \
  TASK.md \
  docs/SPRINTS/Sprint-31.md \
  docs/ROADMAP.md \
  docs/DEVLOG.md
git commit -m "feat(sprint-31): 新增窗口悬停选择"
```

---

## Self-Review

- Spec coverage：已覆盖窗口悬停预览、点击确认、拖拽切回自由框选、空白区域回退、主链路兼容与文档收尾。
- Placeholder scan：已避免 `TODO` / `TBD` / “后续补充” 之类占位写法。
- Type consistency：计划中统一使用 `WindowSelectionService`、`WindowSelectionCandidate`、`windowCandidateProvider`、`onWindowSelectionConfirmed` 这组命名。
