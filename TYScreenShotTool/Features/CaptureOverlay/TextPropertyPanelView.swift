//
//  TextPropertyPanelView.swift
//  TYScreenShotTool
//
//  Created by Codex on 2026/6/24.
//

import AppKit
import SnapKit

/// 文字属性面板
final class TextPropertyPanelView: NSVisualEffectView {

    static let minimumPanelSize = CGSize(width: 330, height: 86)
    static let maximumPanelWidth: CGFloat = 400

    var onPropertyChanged: ((TextProperties) -> Void)?

    private var isUpdatingDisplay = false
    private var currentProperties = TextProperties.default {
        didSet {
            guard !isUpdatingDisplay else { return }
            onPropertyChanged?(currentProperties)
        }
    }

    private let contentContainer = NSView()
    private let fontSizeSlider = NSSlider()
    private let fontSizeValueLabel = NSTextField(labelWithString: "22")
    private let opacitySlider = NSSlider()
    private let opacityValueLabel = NSTextField(labelWithString: "100%")
    private var colorButtons: [NSButton] = []

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
        frame = CGRect(x: 0, y: 0, width: 330, height: 86)
    }

    private func setupControls() {
        addSubview(contentContainer)

        fontSizeSlider.minValue = 12
        fontSizeSlider.maxValue = 72
        fontSizeSlider.doubleValue = Double(currentProperties.fontSize)
        fontSizeSlider.isContinuous = true
        fontSizeSlider.target = self
        fontSizeSlider.action = #selector(fontSizeChanged)
        fontSizeSlider.controlSize = .small

        opacitySlider.minValue = 0
        opacitySlider.maxValue = 100
        opacitySlider.doubleValue = 100
        opacitySlider.isContinuous = true
        opacitySlider.target = self
        opacitySlider.action = #selector(opacityChanged)
        opacitySlider.controlSize = .small

        for (index, preset) in RGBColor.presetColors.enumerated() {
            let button = NSButton(frame: .zero)
            button.title = ""
            button.wantsLayer = true
            button.isBordered = false
            button.layer?.backgroundColor = preset.toNSColor().cgColor
            button.layer?.cornerRadius = 9
            button.layer?.borderWidth = 0
            button.tag = index
            button.target = self
            button.action = #selector(colorChanged(_:))
            button.toolTip = colorName(at: index)
            colorButtons.append(button)
        }

        updateColorSelection(color: currentProperties.color)
    }

    private func setupLayout() {
        contentContainer.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(14)
            make.trailing.equalToSuperview().inset(14)
            make.top.equalToSuperview().offset(14)
            make.bottom.equalToSuperview().inset(12)
        }

        let fontSizeRow = makeSliderRow(
            label: NSTextField(labelWithString: AppText.annotationPanelLineWidth),
            slider: fontSizeSlider,
            valueLabel: fontSizeValueLabel
        )
        let opacityRow = makeSliderRow(
            label: NSTextField(labelWithString: AppText.annotationPanelOpacity),
            slider: opacitySlider,
            valueLabel: opacityValueLabel
        )

        let colorLabel = NSTextField(labelWithString: AppText.annotationPanelColor)
        let colorGrid = NSGridView(views: [
            Array(colorButtons.prefix(4)),
            Array(colorButtons.suffix(4))
        ])
        colorGrid.rowSpacing = 4
        colorGrid.columnSpacing = 4

        let leftStack = NSStackView(views: [fontSizeRow, opacityRow])
        leftStack.orientation = .vertical
        leftStack.spacing = 8

        contentContainer.addSubview(leftStack)
        contentContainer.addSubview(colorLabel)
        contentContainer.addSubview(colorGrid)

        leftStack.snp.makeConstraints { make in
            make.leading.top.equalToSuperview()
            make.bottom.lessThanOrEqualToSuperview()
        }

        colorLabel.snp.makeConstraints { make in
            make.leading.equalTo(leftStack.snp.trailing).offset(12)
            make.top.equalToSuperview().offset(2)
            make.width.equalTo(22)
        }

        colorGrid.snp.makeConstraints { make in
            make.leading.equalTo(colorLabel.snp.trailing).offset(8)
            make.top.equalTo(colorLabel.snp.top).offset(-3)
            make.trailing.bottom.lessThanOrEqualToSuperview()
        }

        for button in colorButtons {
            button.snp.makeConstraints { make in
                make.width.height.equalTo(18)
            }
        }
    }

    @objc private func fontSizeChanged() {
        let value = Int(fontSizeSlider.doubleValue.rounded())
        fontSizeSlider.doubleValue = Double(value)
        fontSizeValueLabel.stringValue = "\(value)"
        currentProperties.fontSize = CGFloat(value)
    }

    @objc private func opacityChanged() {
        let value = Int(opacitySlider.doubleValue.rounded())
        opacitySlider.doubleValue = Double(value)
        opacityValueLabel.stringValue = "\(value)%"
        currentProperties.opacity = CGFloat(value) / 100.0
    }

    @objc private func colorChanged(_ sender: NSButton) {
        let index = sender.tag
        guard RGBColor.presetColors.indices.contains(index) else { return }
        currentProperties.color = RGBColor.presetColors[index]
        updateColorSelection(color: currentProperties.color)
    }

    func updateDisplay(with properties: TextProperties) {
        isUpdatingDisplay = true
        currentProperties = properties
        fontSizeSlider.doubleValue = Double(properties.fontSize)
        fontSizeValueLabel.stringValue = "\(Int(properties.fontSize.rounded()))"
        opacitySlider.doubleValue = Double(properties.opacity * 100)
        opacityValueLabel.stringValue = "\(Int((properties.opacity * 100).rounded()))%"
        updateColorSelection(color: properties.color)
        isUpdatingDisplay = false
    }

    private func updateColorSelection(color: RGBColor) {
        for (index, button) in colorButtons.enumerated() {
            let isSelected = RGBColor.presetColors.indices.contains(index) && RGBColor.presetColors[index] == color
            button.layer?.borderWidth = isSelected ? 2 : 0
            button.layer?.borderColor = isSelected ? NSColor.systemCyan.cgColor : nil
        }
    }

    private func makeSliderRow(label: NSTextField, slider: NSSlider, valueLabel: NSTextField) -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 4

        label.font = .systemFont(ofSize: 10, weight: .medium)
        label.textColor = .secondaryLabelColor
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 10, weight: .medium)
        valueLabel.textColor = .secondaryLabelColor
        valueLabel.alignment = .right

        row.addArrangedSubview(label)
        row.addArrangedSubview(slider)
        row.addArrangedSubview(valueLabel)

        label.snp.makeConstraints { make in
            make.width.equalTo(44)
        }
        valueLabel.snp.makeConstraints { make in
            make.width.equalTo(40)
        }
        slider.snp.makeConstraints { make in
            make.height.equalTo(20)
            make.width.greaterThanOrEqualTo(80)
        }
        row.snp.makeConstraints { make in
            make.height.equalTo(24)
        }

        return row
    }

    private func colorName(at index: Int) -> String {
        guard RGBColor.presetColors.indices.contains(index) else { return "" }
        return ["红", "橙", "黄", "绿", "蓝", "紫", "白", "黑"][index]
    }
}
