//
//  OCRPreviewContentView.swift
//  TYScreenShotTool
//
//  Created by Codex on 2026/6/22.
//

import AppKit
import SnapKit

@MainActor
final class OCRPreviewContentView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let scrollView = NSScrollView()
    private let textView = NSTextView()
    private let copyButton = NSButton(title: "", target: nil, action: nil)
    private let cancelButton = NSButton(title: "", target: nil, action: nil)

    var onCopy: (() -> Void)?
    var onCancel: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        buildLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        copyButton.target = self
        copyButton.action = #selector(handleCopy)
        cancelButton.target = self
        cancelButton.action = #selector(handleCancel)
    }

    func configure(
        title: String,
        text: String,
        isCopyEnabled: Bool,
        copyTitle: String,
        cancelTitle: String
    ) {
        titleLabel.stringValue = title
        textView.string = text
        copyButton.title = copyTitle
        cancelButton.title = cancelTitle
        copyButton.isEnabled = isCopyEnabled
    }

    @objc private func handleCopy() { onCopy?() }
    @objc private func handleCancel() { onCancel?() }
}

// MARK: - Layout

private extension OCRPreviewContentView {
    func buildLayout() {
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)

        textView.isEditable = false
        textView.drawsBackground = false
        textView.font = .systemFont(ofSize: 13)

        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.documentView = textView

        let buttonRow = NSStackView(views: [copyButton, cancelButton])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 10
        buttonRow.alignment = .centerY

        addSubview(titleLabel)
        addSubview(scrollView)
        addSubview(buttonRow)

        titleLabel.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(16)
        }
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(16)
        }
        buttonRow.snp.makeConstraints { make in
            make.top.equalTo(scrollView.snp.bottom).offset(10)
            make.trailing.bottom.equalToSuperview().inset(16)
        }
    }
}
