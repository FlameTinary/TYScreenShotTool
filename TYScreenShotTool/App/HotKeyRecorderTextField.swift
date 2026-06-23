//
//  HotKeyRecorderTextField.swift
//  TYScreenShotTool
//
//  Created by Codex on 2026/6/22.
//

import AppKit
import Carbon

@MainActor
final class HotKeyRecorderTextField: NSTextField {
    var onBeginRecording: (() -> Void)?
    var onCandidateChanged: ((ScreenshotHotKey?) -> Void)?
    var onCommit: (() -> Void)?
    var onCancel: (() -> Void)?

    private var currentModifiers: UInt32 = 0
    private var currentCandidate: ScreenshotHotKey?
    private var outsideClickMonitor: Any?

    var isRecordingHotKey = false {
        didSet {
            updateAppearance()
            updateOutsideClickMonitor()
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isEditable = false
        isBordered = false
        drawsBackground = true
        focusRingType = .none
        font = .systemFont(ofSize: 13)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1
        updateAppearance()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        if isRecordingHotKey == false {
            onBeginRecording?()
        }
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }

    override func keyDown(with event: NSEvent) {
        guard isRecordingHotKey else {
            return
        }

        if event.keyCode == UInt16(kVK_Return) {
            onCommit?()
            return
        }

        if event.keyCode == UInt16(kVK_Escape) {
            onCancel?()
            return
        }

        if let candidate = ScreenshotHotKey(event: event, modifiers: currentModifiers) {
            currentCandidate = candidate
            stringValue = candidate.displayName
            onCandidateChanged?(candidate)
        }
    }

    override func flagsChanged(with event: NSEvent) {
        guard isRecordingHotKey else {
            return
        }

        currentModifiers = event.carbonModifiers
        if currentCandidate == nil {
            stringValue = event.modifierDisplayName
            onCandidateChanged?(nil)
        }
    }

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned, isRecordingHotKey {
            onCancel?()
        }
        return resigned
    }

    func resetRecordingState(displayedValue: String) {
        currentModifiers = 0
        currentCandidate = nil
        stringValue = displayedValue
        isRecordingHotKey = false
    }

    private func updateAppearance() {
        let borderColor = isRecordingHotKey
            ? NSColor.systemBlue.withAlphaComponent(0.55)
            : NSColor.separatorColor.withAlphaComponent(0.9)
        let fillColor = isRecordingHotKey
            ? NSColor.systemBlue.withAlphaComponent(0.08)
            : NSColor.textBackgroundColor

        layer?.borderColor = borderColor.cgColor
        layer?.backgroundColor = fillColor.cgColor
        backgroundColor = fillColor
    }

    private func updateOutsideClickMonitor() {
        if isRecordingHotKey, outsideClickMonitor == nil {
            outsideClickMonitor = NSEvent.addLocalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown]
            ) { [weak self] event in
                guard let self, let window = self.window, event.window === window else {
                    return event
                }

                let point = self.convert(event.locationInWindow, from: nil)
                if self.bounds.contains(point) == false {
                    self.onCancel?()
                }
                return event
            }
        } else if isRecordingHotKey == false, let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
            self.outsideClickMonitor = nil
        }
    }
}

// MARK: - Private Helpers

private extension NSEvent {
    var carbonModifiers: UInt32 {
        var value: UInt32 = 0
        if modifierFlags.contains(.command) { value |= UInt32(cmdKey) }
        if modifierFlags.contains(.shift) { value |= UInt32(shiftKey) }
        if modifierFlags.contains(.option) { value |= UInt32(optionKey) }
        if modifierFlags.contains(.control) { value |= UInt32(controlKey) }
        return value
    }

    var modifierDisplayName: String {
        var parts: [String] = []
        if modifierFlags.contains(.command) { parts.append("Command") }
        if modifierFlags.contains(.shift) { parts.append("Shift") }
        if modifierFlags.contains(.option) { parts.append("Option") }
        if modifierFlags.contains(.control) { parts.append("Control") }
        return parts.joined(separator: " + ")
    }
}

private extension ScreenshotHotKey {
    init?(event: NSEvent, modifiers: UInt32) {
        guard let candidate = ScreenshotHotKey.makeCandidate(
            keyCode: UInt32(event.keyCode),
            modifiers: modifiers
        ) else {
            return nil
        }
        self = candidate
    }
}
