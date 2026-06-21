//
//  HotKeyRecorderField.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/20.
//

import AppKit
import Carbon
import SwiftUI

/// 快捷键录制字段
///
/// SwiftUI 包装的 NSTextField，用于录制用户按下的快捷键组合。
struct HotKeyRecorderField: NSViewRepresentable {
    /// 显示的快捷键文本
    @Binding var displayedValue: String
    /// 是否正在录制
    @Binding var isRecording: Bool
    /// 开始录制时的回调
    var onBeginRecording: () -> Void
    /// 快捷键候选变化时的回调
    var onCandidateChanged: (ScreenshotHotKey?) -> Void
    /// 确认录制时的回调
    var onCommit: () -> Void
    /// 取消录制时的回调
    var onCancel: () -> Void

    /// 创建协调器
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    /// 创建 NSTextField 视图
    func makeNSView(context: Context) -> HotKeyRecorderTextField {
        let textField = HotKeyRecorderTextField(frame: .zero)
        textField.isEditable = false
        textField.isBordered = false
        textField.drawsBackground = true
        textField.alignment = .left
        textField.font = .systemFont(ofSize: 13)
        textField.focusRingType = .none
        textField.recorderDelegate = context.coordinator
        textField.placeholderString = "点击后录制热键"
        return textField
    }

    /// 更新 NSTextField 视图状态
    func updateNSView(_ nsView: HotKeyRecorderTextField, context _: Context) {
        if nsView.stringValue != displayedValue {
            nsView.stringValue = displayedValue
        }

        nsView.isRecording = isRecording

        if isRecording, nsView.window?.firstResponder !== nsView {
            nsView.window?.makeFirstResponder(nsView)
        } else if isRecording == false, nsView.window?.firstResponder === nsView {
            nsView.window?.makeFirstResponder(nil)
        }
    }
}

/// 快捷键录制文本框
///
/// 处理键盘事件捕获和录制状态的 NSTextField。
final class HotKeyRecorderTextField: NSTextField {
    weak var recorderDelegate: HotKeyRecorderField.Coordinator?
    private var outsideClickMonitor: Any?
    var isRecording = false {
        didSet {
            updateAppearance()
            updateOutsideClickMonitor()
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureAppearance()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        recorderDelegate?.didRequestRecordingFromClick()
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned {
            recorderDelegate?.didLoseFocus()
        }
        return resigned
    }

    override func keyDown(with event: NSEvent) {
        recorderDelegate?.handleKeyDown(event)
    }

    override func flagsChanged(with event: NSEvent) {
        recorderDelegate?.handleFlagsChanged(event)
    }

    private func configureAppearance() {
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1
        updateAppearance()
    }

    private func updateAppearance() {
        let borderColor = isRecording
            ? NSColor.systemBlue.withAlphaComponent(0.55)
            : NSColor.separatorColor.withAlphaComponent(0.9)
        let fillColor = isRecording
            ? NSColor.systemBlue.withAlphaComponent(0.08)
            : NSColor.textBackgroundColor

        layer?.borderColor = borderColor.cgColor
        layer?.backgroundColor = fillColor.cgColor
        backgroundColor = fillColor
    }

    private func updateOutsideClickMonitor() {
        if isRecording {
            guard outsideClickMonitor == nil else {
                return
            }

            outsideClickMonitor = NSEvent.addLocalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown]
            ) { [weak self] event in
                guard let self, let window = self.window, event.window === window else {
                    return event
                }

                let point = self.convert(event.locationInWindow, from: nil)
                guard self.bounds.contains(point) == false else {
                    return event
                }

                self.recorderDelegate?.didClickOutsideRecorder()
                return event
            }
        } else if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
            self.outsideClickMonitor = nil
        }
    }

    deinit {
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
        }
    }
}

extension HotKeyRecorderField {
    final class Coordinator: NSObject {
        private let parent: HotKeyRecorderField
        private var currentModifiers: UInt32 = 0
        private var currentCandidate: ScreenshotHotKey?
        private var suppressFocusLossCancel = false

        init(_ parent: HotKeyRecorderField) {
            self.parent = parent
        }

        func didRequestRecordingFromClick() {
            if parent.isRecording == false {
                parent.onBeginRecording()
            }
        }

        func didLoseFocus() {
            guard parent.isRecording, suppressFocusLossCancel == false else {
                suppressFocusLossCancel = false
                return
            }

            cancelRecording()
        }

        func didClickOutsideRecorder() {
            guard parent.isRecording else {
                return
            }

            cancelRecording()
        }

        func handleFlagsChanged(_ event: NSEvent) {
            guard parent.isRecording else {
                return
            }

            currentModifiers = carbonModifiers(from: event.modifierFlags)

            if currentCandidate == nil {
                parent.displayedValue = modifierDisplayName(for: currentModifiers)
                parent.onCandidateChanged(nil)
            }
        }

        func handleKeyDown(_ event: NSEvent) {
            guard parent.isRecording else {
                return
            }

            switch Int(event.keyCode) {
            case kVK_Return:
                suppressFocusLossCancel = true
                resetRecordingState()
                parent.onCommit()
            case kVK_Escape:
                cancelRecording()
            default:
                let modifiers = carbonModifiers(from: event.modifierFlags)
                currentModifiers = modifiers

                guard let candidate = ScreenshotHotKey.makeCandidate(
                    keyCode: UInt32(event.keyCode),
                    modifiers: modifiers
                ) else {
                    return
                }

                currentCandidate = candidate
                parent.displayedValue = candidate.displayName
                parent.onCandidateChanged(candidate)
            }
        }

        private func cancelRecording() {
            suppressFocusLossCancel = true
            resetRecordingState()
            parent.onCandidateChanged(nil)
            parent.onCancel()
        }

        private func resetRecordingState() {
            currentModifiers = 0
            currentCandidate = nil
        }

        private func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
            var value: UInt32 = 0

            if flags.contains(.command) {
                value |= UInt32(cmdKey)
            }
            if flags.contains(.shift) {
                value |= UInt32(shiftKey)
            }
            if flags.contains(.option) {
                value |= UInt32(optionKey)
            }
            if flags.contains(.control) {
                value |= UInt32(controlKey)
            }

            return value
        }

        private func modifierDisplayName(for modifiers: UInt32) -> String {
            var parts: [String] = []

            if modifiers & UInt32(cmdKey) != 0 {
                parts.append("⌘")
            }
            if modifiers & UInt32(shiftKey) != 0 {
                parts.append("⇧")
            }
            if modifiers & UInt32(optionKey) != 0 {
                parts.append("⌥")
            }
            if modifiers & UInt32(controlKey) != 0 {
                parts.append("⌃")
            }

            return parts.joined()
        }
    }
}
