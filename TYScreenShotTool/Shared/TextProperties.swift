//
//  TextProperties.swift
//  TYScreenShotTool
//
//  Created by Codex on 2026/6/24.
//

import AppKit

/// 文字标注的样式属性
struct TextProperties: Equatable {
    var fontSize: CGFloat
    var opacity: CGFloat
    var color: RGBColor

    static let `default` = TextProperties(
        fontSize: 22,
        opacity: 1.0,
        color: RGBColor(red: 0.93, green: 0.24, blue: 0.21)
    )
}

extension TextProperties {
    var font: NSFont {
        .systemFont(ofSize: fontSize, weight: .semibold)
    }

    var textColor: NSColor {
        color.toNSColor().withAlphaComponent(opacity)
    }

    var textAttributes: [NSAttributedString.Key: Any] {
        [
            .font: font,
            .foregroundColor: textColor
        ]
    }

    var editorHeight: CGFloat {
        max(30, ceil(fontSize * 1.45))
    }

    func estimatedBounds(for text: String, origin: CGPoint) -> CGRect {
        let attributedString = NSAttributedString(string: text, attributes: textAttributes)
        let size = attributedString.size()
        return CGRect(
            x: origin.x,
            y: origin.y,
            width: size.width,
            height: size.height
        )
    }
}
