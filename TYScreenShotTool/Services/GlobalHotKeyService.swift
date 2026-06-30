//
//  GlobalHotKeyService.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/5.
//

import Carbon
import Foundation

/// 全局快捷键服务
///
/// 使用 Carbon API 注册和管理全局快捷键，支持动态更新快捷键配置。
final class GlobalHotKeyService {
    /// 当前注册的快捷键
    private var hotKey: ScreenshotHotKey
    /// 快捷键按下时的回调
    var onHotKeyPressed: () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    /// 初始化全局快捷键服务
    ///
    /// - Parameters:
    ///   - hotKey: 要注册的快捷键配置
    ///   - onHotKeyPressed: 快捷键按下时的回调
    init(hotKey: ScreenshotHotKey, onHotKeyPressed: @escaping () -> Void) {
        self.hotKey = hotKey
        self.onHotKeyPressed = onHotKeyPressed
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }

        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    /// 注册快捷键
    ///
    /// 安装事件处理器并注册当前快捷键。如果已注册则跳过。
    ///
    /// - Returns: 注册是否成功
    @discardableResult
    func register() -> Bool {
        guard installEventHandlerIfNeeded() else {
            return false
        }

        return registerCurrentHotKey()
    }

    /// 更新快捷键配置
    ///
    /// 注销旧快捷键并注册新快捷键。如果注册失败则恢复原配置。
    ///
    /// - Parameter newHotKey: 新的快捷键配置
    /// - Returns: 更新是否成功
    @discardableResult
    func updateHotKey(_ newHotKey: ScreenshotHotKey) -> Bool {
        guard newHotKey != hotKey else {
            return true
        }

        guard installEventHandlerIfNeeded() else {
            return false
        }

        let previousHotKey = hotKey
        unregisterCurrentHotKey()
        hotKey = newHotKey

        guard registerCurrentHotKey() else {
            hotKey = previousHotKey
            _ = registerCurrentHotKey()
            TYLogger.warn("Failed to update global hot key. Restored previous value: \(previousHotKey.displayName)", tag: "GlobalHotKey")
            return false
        }

        TYLogger.info("HotKey Update Success", tag: "GlobalHotKey")
        TYLogger.debug("value: \(newHotKey.displayName)", tag: "GlobalHotKey")
        return true
    }

    private func installEventHandlerIfNeeded() -> Bool {
        guard eventHandlerRef == nil else {
            return true
        }

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
            TYLogger.error("Failed to install hot key event handler: \(handlerStatus)", tag: "GlobalHotKey")
            return false
        }

        return true
    }

    private func registerCurrentHotKey() -> Bool {
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
            TYLogger.error("Failed to register global hot key: \(registerStatus)", tag: "GlobalHotKey")
            return false
        }

        return true
    }

    private func unregisterCurrentHotKey() {
        guard let hotKeyRef else {
            return
        }

        UnregisterEventHotKey(hotKeyRef)
        self.hotKeyRef = nil
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
            TYLogger.error("Failed to read hot key event: \(status)", tag: "GlobalHotKey")
            return status
        }

        guard hotKeyID.id == hotKey.id else {
            return OSStatus(eventNotHandledErr)
        }

        onHotKeyPressed()
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
