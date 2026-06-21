//
//  CaptureState.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/5.
//

import Foundation

/// 截图会话状态
///
/// 定义截图会话的生命周期状态，用于状态机管理。
enum CaptureState {
    /// 空闲状态，未开始截图
    case idle
    /// 覆盖层已显示，等待用户操作
    case overlayPresented
    /// 用户正在拖拽选区
    case dragging
    /// 选区已完成，进入编辑态
    case selectionCompleted

    /// 状态的显示名称
    ///
    /// 用于日志输出和调试。
    var displayName: String {
        switch self {
        case .idle:
            return "Idle"
        case .overlayPresented:
            return "OverlayPresented"
        case .dragging:
            return "Dragging"
        case .selectionCompleted:
            return "SelectionCompleted"
        }
    }
}
