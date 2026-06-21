//
//  RectanglePropertyPanelView.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/21.
//

import AppKit

/// 矩形属性面板 — 在工具栏下方显示，支持调整粗细/透明度/圆角/实心空心/颜色
final class RectanglePropertyPanelView: NSVisualEffectView {
    /// 属性变更回调
    var onPropertyChanged: ((RectangleProperties) -> Void)?

    /// 防止 updateDisplay 触发重复回调的标志
    private var isUpdatingDisplay = false

    private var currentProperties = RectangleProperties.default {
        didSet {
            guard !isUpdatingDisplay else { return }
            onPropertyChanged?(currentProperties)
        }
    }

    // MARK: - 控件

    private let lineWidthPopUp = NSPopUpButton()
    private let opacitySlider = NSSlider()
    private let opacityLabel = NSTextField(labelWithString: "100%")
    private let cornerRadiusSlider = NSSlider()
    private let cornerRadiusLabel = NSTextField(labelWithString: "0px")
    private let styleSegmented = NSSegmentedControl()
    private var colorButtons: [NSButton] = []

    // MARK: - 初始化

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
        setupControls()
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
        layer?.cornerRadius = 10
    }

    private func setupControls() {
        // 粗细下拉选 1-12px
        for i in 1...12 {
            lineWidthPopUp.addItem(withTitle: "\(i)px")
        }
        lineWidthPopUp.selectItem(at: 2) // 默认 3px
        lineWidthPopUp.target = self
        lineWidthPopUp.action = #selector(lineWidthChanged)
        lineWidthPopUp.font = .systemFont(ofSize: 11)
        lineWidthPopUp.bezelStyle = .texturedRounded

        // 透明度滑块 0-100%
        opacitySlider.minValue = 0
        opacitySlider.maxValue = 100
        opacitySlider.doubleValue = 100
        opacitySlider.isContinuous = true
        opacitySlider.target = self
        opacitySlider.action = #selector(opacityChanged)
        opacitySlider.controlSize = .small

        opacityLabel.font = .monospacedDigitSystemFont(ofSize: 10, weight: .medium)
        opacityLabel.textColor = .secondaryLabelColor
        opacityLabel.alignment = .right

        // 圆角滑块 0-100
        cornerRadiusSlider.minValue = 0
        cornerRadiusSlider.maxValue = 100
        cornerRadiusSlider.doubleValue = 0
        cornerRadiusSlider.isContinuous = true
        cornerRadiusSlider.target = self
        cornerRadiusSlider.action = #selector(cornerRadiusChanged)
        cornerRadiusSlider.controlSize = .small

        cornerRadiusLabel.font = .monospacedDigitSystemFont(ofSize: 10, weight: .medium)
        cornerRadiusLabel.textColor = .secondaryLabelColor
        cornerRadiusLabel.alignment = .right

        // 样式分段按钮
        styleSegmented.segmentCount = 2
        styleSegmented.setLabel("■ 实心", forSegment: 0)
        styleSegmented.setLabel("□ 空心", forSegment: 1)
        styleSegmented.selectedSegment = 1 // 默认空心
        styleSegmented.segmentStyle = .texturedRounded
        styleSegmented.target = self
        styleSegmented.action = #selector(styleChanged)
        styleSegmented.font = .systemFont(ofSize: 10)

        // 颜色圆点按钮
        for (index, preset) in RGBColor.presetColors.enumerated() {
            let button = NSButton(frame: .zero)
            button.wantsLayer = true
            button.isBordered = false
            button.layer?.backgroundColor = preset.toNSColor().cgColor
            button.layer?.cornerRadius = 10
            button.tag = index
            button.target = self
            button.action = #selector(colorChanged(_:))
            button.toolTip = colorName(at: index)
            colorButtons.append(button)
            addSubview(button)
        }
        updateColorSelection(selectedIndex: 0) // 默认红色选中
    }

    override func layout() {
        super.layout()

        let paddingX: CGFloat = 12
        let paddingY: CGFloat = 10
        let spacing: CGFloat = 20
        let controlHeight: CGFloat = 22
        let rowCenterY1 = bounds.height - paddingY - controlHeight / 2
        let rowCenterY2 = paddingY + controlHeight / 2

        // 第一排：粗细 + 透明度 + 圆角
        let lineWidthWidth: CGFloat = 60
        let sliderWidth: CGFloat = 80
        let labelWidth: CGFloat = 32
        let firstRowX = paddingX

        // 粗细
        lineWidthPopUp.frame = CGRect(x: firstRowX, y: rowCenterY1 - controlHeight / 2,
                                       width: lineWidthWidth, height: controlHeight)

        // 透明度
        let opacityX = firstRowX + lineWidthWidth + spacing
        opacitySlider.frame = CGRect(x: opacityX, y: rowCenterY1 - 14,
                                      width: sliderWidth, height: 28)
        opacityLabel.frame = CGRect(x: opacityX + sliderWidth + 4, y: rowCenterY1 - 8,
                                     width: labelWidth, height: 16)

        // 圆角
        let cornerX = opacityX + sliderWidth + labelWidth + spacing
        cornerRadiusSlider.frame = CGRect(x: cornerX, y: rowCenterY1 - 14,
                                           width: sliderWidth, height: 28)
        cornerRadiusLabel.frame = CGRect(x: cornerX + sliderWidth + 4, y: rowCenterY1 - 8,
                                          width: labelWidth, height: 16)

        // 第二排：样式 + 颜色
        let styleWidth: CGFloat = 120
        styleSegmented.frame = CGRect(x: paddingX, y: rowCenterY2 - controlHeight / 2,
                                       width: styleWidth, height: controlHeight)

        // 颜色圆点
        let colorSize: CGFloat = 20
        let colorSpacing: CGFloat = 6
        let colorStartX = styleSegmented.frame.maxX + spacing
        for (i, button) in colorButtons.enumerated() {
            button.frame = CGRect(
                x: colorStartX + CGFloat(i) * (colorSize + colorSpacing),
                y: rowCenterY2 - colorSize / 2,
                width: colorSize,
                height: colorSize
            )
        }
    }

    // MARK: - Actions

    @objc private func lineWidthChanged() {
        let selectedIndex = lineWidthPopUp.indexOfSelectedItem
        currentProperties.lineWidth = CGFloat(selectedIndex + 1)
    }

    @objc private func opacityChanged() {
        let value = opacitySlider.doubleValue
        opacityLabel.stringValue = "\(Int(value))%"
        currentProperties.opacity = CGFloat(value) / 100.0
    }

    @objc private func cornerRadiusChanged() {
        let value = cornerRadiusSlider.doubleValue
        cornerRadiusLabel.stringValue = "\(Int(value))px"
        currentProperties.cornerRadius = CGFloat(value)
    }

    @objc private func styleChanged() {
        currentProperties.isFilled = (styleSegmented.selectedSegment == 0)
    }

    @objc private func colorChanged(_ sender: NSButton) {
        let index = sender.tag
        guard index >= 0, index < RGBColor.presetColors.count else { return }
        currentProperties.color = RGBColor.presetColors[index]
        updateColorSelection(selectedIndex: index)
    }

    // MARK: - 更新面板显示

    /// 外部调用：将面板值同步到指定属性（用于选中矩形后同步）
    func updateDisplay(with properties: RectangleProperties) {
        isUpdatingDisplay = true
        currentProperties = properties

        // 粗细
        let lineWidthIndex = max(0, min(Int(properties.lineWidth) - 1, 11))
        lineWidthPopUp.selectItem(at: lineWidthIndex)

        // 透明度
        opacitySlider.doubleValue = Double(properties.opacity * 100)
        opacityLabel.stringValue = "\(Int(properties.opacity * 100))%"

        // 圆角
        cornerRadiusSlider.doubleValue = Double(properties.cornerRadius)
        cornerRadiusLabel.stringValue = "\(Int(properties.cornerRadius))px"

        // 样式
        styleSegmented.selectedSegment = properties.isFilled ? 0 : 1

        // 颜色
        if let colorIndex = RGBColor.presetColors.firstIndex(of: properties.color) {
            updateColorSelection(selectedIndex: colorIndex)
        }

        isUpdatingDisplay = false
    }

    private func updateColorSelection(selectedIndex: Int) {
        for (i, button) in colorButtons.enumerated() {
            button.layer?.borderWidth = (i == selectedIndex) ? 2 : 0
            button.layer?.borderColor = (i == selectedIndex) ?
                NSColor.systemCyan.cgColor : nil
        }
    }

    private func colorName(at index: Int) -> String {
        ["红", "橙", "黄", "绿", "蓝", "紫", "白", "黑"][safe: index] ?? ""
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
