//
//  CaptureState.swift
//  TYScreenShotTool
//
//  Created by Codex on 2026/6/5.
//

import Foundation

enum CaptureState {
    case idle
    case overlayPresented
    case dragging
    case selectionCompleted

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
