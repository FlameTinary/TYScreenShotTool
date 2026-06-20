//
//  HotKeyRecorderField.swift
//  TYScreenShotTool
//
//  Created by Codex on 2026/6/20.
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
        textField.isBordered = true
        textField.drawsBackground = true
        textField.backgroundColor = .textBackgroundColor
        textField.alignment = .left
        textField.font = .systemFont(ofSize: 13)
        textField.focusRingType = .default
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
        }
    }
}

final class HotKeyRecorderTextField: NSTextField {
    weak var recorderDelegate: HotKeyRecorderField.Coordinator?
    var isRecording = false

    override var acceptsFirstResponder: Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        recorderDelegate?.didRequestRecordingFromClick()
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted {
            recorderDelegate?.didBeginRecording()
        }
        return accepted
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

        func didBeginRecording() {
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
