//
//  CaptureOverlayService.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/5.
//

import AppKit
import CoreGraphics

/// 截图覆盖层服务
///
/// 管理截图时的全屏覆盖层窗口，处理用户选区交互和回调。
@MainActor
final class CaptureOverlayService {
    /// 取消截图时的回调
    var onCancel: (() -> Void)?
    /// 开始拖拽选区时的回调
    var onDragStarted: (() -> Void)?
    /// 选区完成时的回调，传递选区的屏幕坐标
    var onSelectionCompleted: ((CGRect) -> Void)?
    /// 窗口选择确认时的回调
    var onWindowSelectionConfirmed: ((WindowSelectionCandidate) -> Void)?
    /// 预览选区变化时的回调
    var onPreviewSelectionChanged: ((CGRect) -> Void)?
    /// 请求复制截图时的回调
    var onCopyRequested: ((CapturePreviewStyle, [CaptureAnnotation]) -> Void)?
    /// 请求保存截图时的回调
    var onSaveRequested: ((CapturePreviewStyle, [CaptureAnnotation]) -> Void)?
    /// 请求 OCR 识别时的回调
    var onOCRRequested: ((CapturePreviewStyle, [CaptureAnnotation]) -> Void)?
    /// 请求 AI 分析时的回调
    var onAIRequested: ((AIAnalysisMode, CapturePreviewStyle, [CaptureAnnotation]) -> Void)?
    /// 请求固定截图时的回调
    var onPinRequested: ((CapturePreviewStyle, [CaptureAnnotation]) -> Void)?
    /// 请求进入长截图模式时的回调
    var onLongCaptureRequested: (([CaptureAnnotation]) -> Void)?
    /// 窗口候选提供者，用于智能窗口选择
    var windowCandidateProvider: ((CGPoint) -> WindowSelectionCandidate?)?

    private var overlayWindows: [CaptureOverlayWindow] = []
    private weak var activeOverlayView: CaptureOverlayView?
    private weak var activeOverlayWindow: CaptureOverlayWindow?

    /// 显示截图覆盖层
    ///
    /// 为每个屏幕创建一个覆盖层窗口，用于用户框选截图区域。
    ///
    /// - Parameter screenImages: 各屏幕的冻结图像，用于选区预览
    func presentOverlay(screenImages: [CGDirectDisplayID: CGImage]) {
        guard overlayWindows.isEmpty else {
            return
        }

        AppThemeCoordinator.shared.registerRefreshHandler(for: self) { [weak self] in
            guard let self else {
                return
            }

            for window in self.overlayWindows {
                AppThemeCoordinator.shared.applyCurrentAppearance(to: window)
                (window.contentView as? CaptureOverlayView)?.applyAppearanceStyling()
            }
        }

        for screen in NSScreen.screens {
            let overlayView = CaptureOverlayView(frame: screen.frame)
            if let displayID = try? displayID(for: screen) {
                overlayView.selectionSourceScreenImage = screenImages[displayID]
            }
            overlayView.onCancel = { [weak self] in
                self?.onCancel?()
            }
            overlayView.onDragStarted = { [weak self] in
                self?.onDragStarted?()
            }
            overlayView.onSelection = { [weak self] rect in
                guard let self, let window = overlayView.window else {
                    return
                }

                self.onSelectionCompleted?(window.convertToScreen(rect))
            }
            overlayView.windowCandidateProvider = { [weak self] localPoint in
                guard let self, let window = overlayView.window else {
                    return nil
                }

                let screenPoint = window.convertToScreen(CGRect(origin: localPoint, size: .zero)).origin
                guard let candidate = self.windowCandidateProvider?(screenPoint) else {
                    return nil
                }

                return WindowSelectionCandidate(
                    frame: window.convertFromScreen(candidate.frame),
                    ownerName: candidate.ownerName,
                    windowID: candidate.windowID
                )
            }
            overlayView.onWindowSelectionConfirmed = { [weak self] candidate in
                guard let self, let window = overlayView.window else {
                    return
                }

                self.onWindowSelectionConfirmed?(
                    WindowSelectionCandidate(
                        frame: window.convertToScreen(candidate.frame),
                        ownerName: candidate.ownerName,
                        windowID: candidate.windowID
                    )
                )
            }
            overlayView.onPreviewSelectionChanged = { [weak self] rect in
                guard let self, let window = overlayView.window else {
                    return
                }

                self.onPreviewSelectionChanged?(window.convertToScreen(rect))
            }
            overlayView.onCopyRequested = { [weak self] in
                self?.onCopyRequested?($0, $1)
            }
            overlayView.onSaveRequested = { [weak self] in
                self?.onSaveRequested?($0, $1)
            }
            overlayView.onOCRRequested = { [weak self] in
                self?.onOCRRequested?($0, $1)
            }
            overlayView.onAIRequested = { [weak self] mode, style, annotations in
                self?.onAIRequested?(mode, style, annotations)
            }
            overlayView.onPinRequested = { [weak self] in
                self?.onPinRequested?($0, $1)
            }
            overlayView.onLongCaptureRequested = { [weak self] annotations in
                self?.onLongCaptureRequested?(annotations)
            }

            let window = CaptureOverlayWindow(screen: screen, contentView: overlayView)
            overlayWindows.append(window)
        }

        overlayWindows.forEach { $0.showOverlay() }
    }

    /// 显示选区预览
    ///
    /// 在用户完成选区后，显示预览界面并隐藏其他屏幕的覆盖层。
    ///
    /// - Parameters:
    ///   - selectionRect: 选区的屏幕坐标
    ///   - screenImages: 各屏幕的冻结图像
    func showSelectionPreview(selectionRect: CGRect, screenImages: [CGDirectDisplayID: CGImage]) {
        guard let activeScreen = screen(containing: selectionRect) else {
            return
        }

        for window in overlayWindows where window.screen != activeScreen {
            window.orderOut(nil)
        }

        overlayWindows.removeAll { $0.screen != activeScreen }

        guard let window = overlayWindows.first,
              let overlayView = window.contentView as? CaptureOverlayView else {
            return
        }

        activeOverlayWindow = window
        activeOverlayView = overlayView
        let displayID = try? displayID(for: activeScreen)
        overlayView.showSelectionPreview(
            selectionRect: window.convertFromScreen(selectionRect),
            sourceScreenImage: displayID.flatMap { screenImages[$0] },
            screenFrame: activeScreen.frame
        )
        window.showOverlay()
    }

    /// 隐藏当前活动的覆盖层
    ///
    /// 用于在执行截图操作前隐藏覆盖层，避免覆盖层出现在截图中。
    func hideActiveOverlay() {
        activeOverlayWindow?.orderOut(nil)
    }

    /// 恢复当前活动的覆盖层
    ///
    /// 在截图操作失败时恢复覆盖层，允许用户重新操作。
    func restoreActiveOverlay() {
        activeOverlayWindow?.showOverlay()
    }

    /// 设置 AI 按钮的启用状态
    ///
    /// - Parameter isEnabled: 是否启用 AI 按钮
    func setAIButtonEnabled(_ isEnabled: Bool) {
        activeOverlayView?.setAIButtonEnabled(isEnabled)
    }

    /// 进入长截图引导模式
    ///
    /// 启用鼠标穿透，允许用户在长截图模式下滚动目标窗口。
    func enterLongCaptureGuideMode() {
        activeOverlayView?.enterLongCaptureGuideMode()
        activeOverlayWindow?.setMousePassthrough(true)
        activeOverlayWindow?.orderFrontRegardless()
    }

    /// 退出长截图引导模式
    ///
    /// 禁用鼠标穿透，恢复正常截图模式。
    func exitLongCaptureGuideMode() {
        activeOverlayWindow?.setMousePassthrough(false)
        activeOverlayView?.exitLongCaptureGuideMode()
        activeOverlayWindow?.showOverlay()
    }

    /// 关闭所有覆盖层窗口
    ///
    /// 清理所有覆盖层窗口和相关状态。
    func dismissOverlay() {
        AppThemeCoordinator.shared.unregisterRefreshHandler(for: self)
        overlayWindows.forEach { window in
            window.setMousePassthrough(false)
            window.orderOut(nil)
        }
        overlayWindows.removeAll()
        activeOverlayView = nil
        activeOverlayWindow = nil
    }

    private func screen(containing rect: CGRect) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(CGPoint(x: rect.midX, y: rect.midY)) }
    }

    private func displayID(for screen: NSScreen) throws -> CGDirectDisplayID {
        guard
            let value = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        else {
            throw ScreenCaptureError.displayNotFound
        }

        return CGDirectDisplayID(value.uint32Value)
    }
}
