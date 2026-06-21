//
//  HotKeyRecorderField.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/20.
//

import AppKit
import Carbon
import SwiftUI

struct HotKeyRecorderField: NSViewRepresentable {
    @Binding var displayedValue: String
    @Binding var isRecording: Bool
    var onBeginRecording: () -> Void
    var onCandidateChanged: (ScreenshotHotKey?) -> Void
    var onCommit: () -> Void
    var onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

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
