//
//  GlobalHotKeyService.swift
//  TYScreenShotTool
//
//  Created by Codex on 2026/6/5.
//

import Carbon
import Foundation

final class GlobalHotKeyService {
    private let hotKey: ScreenshotHotKey
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    init(hotKey: ScreenshotHotKey) {
        self.hotKey = hotKey
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }

        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    @discardableResult
    func register() -> Bool {
        let eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            GlobalHotKeyService.eventHandler,
            1,
            [eventType],
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            &eventHandlerRef
        )

        guard handlerStatus == noErr else {
            print("Failed to install hot key event handler: \(handlerStatus)")
            return false
        }

        let hotKeyID = EventHotKeyID(
            signature: OSType(0x54595353),
            id: hotKey.id
        )

        let registerStatus = RegisterEventHotKey(
            hotKey.keyCode,
            hotKey.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard registerStatus == noErr else {
            print("Failed to register global hot key: \(registerStatus)")

            if let eventHandlerRef {
                RemoveEventHandler(eventHandlerRef)
                self.eventHandlerRef = nil
            }

            return false
        }

        return true
    }

    private func handleHotKeyPressed(_ event: EventRef?) -> OSStatus {
        guard let event else {
            return OSStatus(eventNotHandledErr)
        }

        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        guard status == noErr else {
            print("Failed to read hot key event: \(status)")
            return status
        }

        guard hotKeyID.id == hotKey.id else {
            return OSStatus(eventNotHandledErr)
        }

        print("Screenshot shortcut triggered")
        return noErr
    }

    private static let eventHandler: EventHandlerUPP = { _, event, userData in
        guard let userData else {
            return OSStatus(eventNotHandledErr)
        }

        let service = Unmanaged<GlobalHotKeyService>
            .fromOpaque(userData)
            .takeUnretainedValue()

        return service.handleHotKeyPressed(event)
    }
}
