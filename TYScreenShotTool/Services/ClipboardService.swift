//
//  ClipboardService.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/6.
//

import AppKit
import CoreGraphics
import Foundation

final class ClipboardService {
    func copyImage(_ image: CGImage) throws {
        let pasteboard = NSPasteboard.general
        let nsImage = NSImage(cgImage: image, size: .zero)

        pasteboard.clearContents()

        guard pasteboard.writeObjects([nsImage]) else {
            throw ClipboardError.writeFailed
        }
    }

    func copyText(_ text: String) throws {
        let pasteboard = NSPasteboard.general

        pasteboard.clearContents()

        guard pasteboard.setString(text, forType: .string) else {
            throw ClipboardError.writeFailed
        }
    }
}

enum ClipboardError: LocalizedError {
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .writeFailed:
            return "Failed to write image to clipboard."
        }
    }
}
