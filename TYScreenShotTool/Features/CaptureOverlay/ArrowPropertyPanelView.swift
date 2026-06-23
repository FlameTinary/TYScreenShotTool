//
//  ArrowPropertyPanelView.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/23.
//

import AppKit
import SnapKit

/// 箭头属性面板
///
/// 在工具栏下方显示，提供大小、不透明度、颜色和曲线箭头开关的调整。
/// 面板采用内容驱动尺寸策略，通过 `onPropertyChanged` 回调向上传递。
final class ArrowPropertyPanelView: NSVisualEffectView {

    static let minimumPanelSize = CGSize(width: 300, height: 86)
    static let maximumPanelWidth: CGFloat = 360

    var onPropertyChanged: ((ArrowProperties) -> Void)?

    private var isUpdatingDisplay = false
    private var currentProperties = ArrowProperties.default {
        didSet {
            guard !isUpdatingDisplay else { return }
            onPropertyChanged?(currentProperties)
        }
    }

    private let contentContainer = NSView()
    private let lineWidthSlider = NSSlider()
    private let lineWidthValueLabel = NSTextField(labelWithString: "4")
    private let opacitySlider = NSSlider()
    private let opacityValueLabel = NSTextField(labelWithString: "100%")
    private let curvedArrowCheckbox = NSButton(
        checkboxWithTitle: AppText.annotationPanelCurvedArrow,
        target: nil,
        action: nil
    )
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
    }

    private func setupControls() {
        addSubview(contentContainer)

        lineWidthSlider.minValue = 1
        lineWidthSlider.maxValue = 20
        lineWidthSlider.doubleValue = 4
        lineWidthSlider.isContinuous = true
        lineWidthSlider.target = self
        lineWidthSlider.action = #selector(lineWidthChanged)
        lineWidthSlider.controlSize = .small

        opacitySlider.minValue = 0
        opacitySlider.maxValue = 100
        opacitySlider.doubleValue = 100
        opacitySlider.isContinuous = true
        opacitySlider.target = self
        opacitySlider.action = #selector(opacityChanged)
        opacitySlider.controlSize = .small

        curvedArrowCheckbox.font = .systemFont(ofSize: 10, weight: .medium)
        curvedArrowCheckbox.target = self
        curvedArrowCheckbox.action = #selector(curvedChanged)

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

        let lineWidthRow = makeSliderRow(
            label: NSTextField(labelWithString: AppText.annotationPanelLineWidth),
            slider: lineWidthSlider,
            valueLabel: lineWidthValueLabel
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

        let leftStack = NSStackView(views: [lineWidthRow, opacityRow])
        leftStack.orientation = .vertical
        leftStack.spacing = 8

        contentContainer.addSubview(leftStack)
        contentContainer.addSubview(colorLabel)
        contentContainer.addSubview(colorGrid)
        contentContainer.addSubview(curvedArrowCheckbox)

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

        curvedArrowCheckbox.snp.makeConstraints { make in
            make.leading.equalTo(leftStack.snp.trailing).offset(12)
            make.top.equalTo(colorGrid.snp.bottom).offset(8)
            make.trailing.lessThanOrEqualToSuperview()
            make.bottom.lessThanOrEqualToSuperview()
        }

        for button in colorButtons {
            button.snp.makeConstraints { make in
                make.width.height.equalTo(18)
            }
        }
    }

    // MARK: - Actions

    @objc private func lineWidthChanged() {
        let value = lineWidthSlider.doubleValue
        lineWidthValueLabel.stringValue = "\(Int(value))"
        currentProperties.lineWidth = CGFloat(value)
    }

    @objc private func opacityChanged() {
        let value = opacitySlider.doubleValue
        opacityValueLabel.stringValue = "\(Int(value))%"
        currentProperties.opacity = CGFloat(value) / 100.0
    }

    @objc private func curvedChanged() {
        currentProperties.isCurved = (curvedArrowCheckbox.state == .on)
    }

    @objc private func colorChanged(_ sender: NSButton) {
        let index = sender.tag
        guard index >= 0, index < RGBColor.presetColors.count else { return }
        currentProperties.color = RGBColor.presetColors[index]
        updateColorSelection(color: currentProperties.color)
    }

    // MARK: - Public

    func updateDisplay(with properties: ArrowProperties) {
        isUpdatingDisplay = true
        currentProperties = properties
        lineWidthSlider.doubleValue = properties.lineWidth
        lineWidthValueLabel.stringValue = "\(Int(properties.lineWidth))"
        opacitySlider.doubleValue = properties.opacity * 100
        opacityValueLabel.stringValue = "\(Int(properties.opacity * 100))%"
        curvedArrowCheckbox.state = properties.isCurved ? .on : .off
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
            make.width.equalTo(36)
        }
        slider.snp.makeConstraints { make in
            make.height.equalTo(20)
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
