//
//  MosaicPropertyPanelView.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/23.
//

import AppKit
import SnapKit

/// 马赛克属性面板
///
/// 在工具栏下方显示，提供马赛克大小和样式（马赛克/毛玻璃）的调整。
/// 面板采用内容驱动尺寸策略，通过 `onPropertyChanged` 回调向上传递。
final class MosaicPropertyPanelView: NSVisualEffectView {

    static let minimumPanelSize = CGSize(width: 220, height: 88)
    static let maximumPanelWidth: CGFloat = 300

    var onPropertyChanged: ((MosaicProperties) -> Void)?

    private var isUpdatingDisplay = false
    private var currentProperties = MosaicProperties.default {
        didSet {
            guard !isUpdatingDisplay else { return }
            onPropertyChanged?(currentProperties)
        }
    }

    private let contentContainer = NSView()
    private let sizeSlider = NSSlider()
    private let sizeValueLabel = NSTextField(labelWithString: "2")
    private let disabledOpacitySlider = NSSlider(value: 100, minValue: 0, maxValue: 100, target: nil, action: nil)
    private let mosaicRadio = NSButton(radioButtonWithTitle: AppText.mosaicStyleMosaic, target: nil, action: nil)
    private let glassRadio = NSButton(radioButtonWithTitle: AppText.mosaicStyleGlass, target: nil, action: nil)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
        setupControls()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        material = .popover
        blendingMode = .withinWindow
        state = .active
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.cornerCurve = .continuous

        frame = CGRect(x: 0, y: 0, width: 220, height: 88)
    }

    private func setupControls() {
        addSubview(contentContainer)

        sizeSlider.minValue = 1
        sizeSlider.maxValue = 10
        sizeSlider.doubleValue = 2
        sizeSlider.isContinuous = true
        sizeSlider.target = self
        sizeSlider.action = #selector(sizeChanged)
        sizeSlider.controlSize = .small

        disabledOpacitySlider.isEnabled = false
        disabledOpacitySlider.controlSize = .small

        mosaicRadio.font = .systemFont(ofSize: 11, weight: .medium)
        mosaicRadio.target = self
        mosaicRadio.action = #selector(styleChanged)

        glassRadio.font = .systemFont(ofSize: 11, weight: .medium)
        glassRadio.target = self
        glassRadio.action = #selector(styleChanged)
    }

    private func setupLayout() {
        contentContainer.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(14)
            make.trailing.equalToSuperview().inset(14)
            make.top.equalToSuperview().offset(14)
            make.bottom.equalToSuperview().inset(12)
        }

        let sizeLabel = NSTextField(labelWithString: AppText.annotationPanelLineWidth)
        sizeLabel.font = .systemFont(ofSize: 10, weight: .medium)
        sizeLabel.textColor = .secondaryLabelColor
        sizeValueLabel.font = .monospacedDigitSystemFont(ofSize: 10, weight: .medium)
        sizeValueLabel.textColor = .secondaryLabelColor
        sizeValueLabel.alignment = .right

        let sizeRow = NSStackView(views: [sizeLabel, sizeSlider, sizeValueLabel])
        sizeRow.orientation = .horizontal
        sizeRow.alignment = .centerY
        sizeRow.spacing = 4

        sizeLabel.snp.makeConstraints { make in
            make.width.equalTo(44)
        }
        sizeValueLabel.snp.makeConstraints { make in
            make.width.equalTo(36)
        }
        sizeSlider.snp.makeConstraints { make in
            make.height.equalTo(20)
        }
        sizeRow.snp.makeConstraints { make in
            make.height.equalTo(24)
        }

        let styleStack = NSStackView(views: [mosaicRadio, glassRadio])
        styleStack.orientation = .horizontal
        styleStack.spacing = 12

        contentContainer.addSubview(sizeRow)
        contentContainer.addSubview(styleStack)

        sizeRow.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
        }

        styleStack.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.top.equalTo(sizeRow.snp.bottom).offset(8)
            make.trailing.bottom.lessThanOrEqualToSuperview()
        }
    }

    // MARK: - Actions

    @objc private func sizeChanged() {
        let value = sizeSlider.doubleValue
        sizeValueLabel.stringValue = "\(Int(value))"
        currentProperties.size = CGFloat(value)
    }

    @objc private func styleChanged() {
        currentProperties.style = mosaicRadio.state == .on ? .mosaic : .glass
    }

    // MARK: - Public

    func updateDisplay(with properties: MosaicProperties) {
        isUpdatingDisplay = true
        currentProperties = properties
        sizeSlider.doubleValue = properties.size
        sizeValueLabel.stringValue = "\(Int(properties.size))"
        mosaicRadio.state = properties.style == .mosaic ? .on : .off
        glassRadio.state = properties.style == .glass ? .on : .off
        isUpdatingDisplay = false
    }
}
