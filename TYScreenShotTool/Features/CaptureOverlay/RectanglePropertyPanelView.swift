//
//  RectanglePropertyPanelView.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/21.
//

import AppKit
import SnapKit

/// 矩形工具属性面板。
///
/// 在工具栏下方显示，提供粗细、透明度、圆角、填充和颜色五项属性的调整。
/// 面板采用左右两列 Auto Layout 布局，用户操作通过 `onPropertyChanged` 回调向上传递。
/// 选中已画矩形时，由 `updateDisplay(with:)` 反向同步面板控件，`isUpdatingDisplay` 标志位阻止期间触发冗余回调。
final class RectanglePropertyPanelView: NSVisualEffectView {

    /// 面板首选逻辑尺寸。
    static let preferredSize = CGSize(width: 360, height: 100)
    static let minimumPanelSize = CGSize(width: 360, height: 100)
    static let maximumPanelWidth: CGFloat = 400

    // MARK: - 回调

    /// 面板属性变更时调用，由 CaptureOverlayView 设置。
    var onPropertyChanged: ((RectangleProperties) -> Void)?

    // MARK: - 内部状态

    /// 为 `true` 时暂停 `currentProperties.didSet` 中的回调触发，
    /// 避免 `updateDisplay(with:)` 同步面板显示时误判为用户操作。
    private var isUpdatingDisplay = false

    /// 面板当前的属性值，`didSet` 在用户操作时驱动 `onPropertyChanged`。
    private var currentProperties = RectangleProperties.default {
        didSet {
            guard !isUpdatingDisplay else { return }
            onPropertyChanged?(currentProperties)
        }
    }

    // MARK: - 布局容器

    private let contentContainer = NSView()

    /// 左列，固定宽度 156pt，垂直排布，间距 10pt。
    private let leftColumnStack = NSStackView()

    /// 右列，弹性宽度，等分填充，垂直排布，间距 8pt。
    private let rightColumnStack = NSStackView()

    // MARK: - 标题标签

    private let lineWidthTitleLabel = RectanglePanelLabel(text: AppText.rectanglePanelLineWidth)
    private let opacityTitleLabel = RectanglePanelLabel(text: AppText.rectanglePanelOpacity)
    private let cornerRadiusTitleLabel = RectanglePanelLabel(text: AppText.rectanglePanelCornerRadius)
    private let fillTitleLabel = RectanglePanelLabel(text: AppText.rectanglePanelFill)
    private let colorTitleLabel = RectanglePanelLabel(text: AppText.rectanglePanelColor)

    // MARK: - 交互控件

    /// 粗细下拉选，选项为 1px–12px。
    private let lineWidthPopUp = NSPopUpButton()

    /// 透明度滑块，范围 0–100，连续触发。
    private let opacitySlider = NSSlider()

    /// 透明度数值标签，等宽数字显示当前百分比。
    private let opacityValueLabel = RectanglePanelValueLabel(text: "100%")

    /// 圆角滑块，范围 0–100，连续触发。
    private let cornerRadiusSlider = NSSlider()

    /// 圆角数值标签，等宽数字显示当前 px 值。
    private let cornerRadiusValueLabel = RectanglePanelValueLabel(text: "0px")

    /// 实心/空心复选框，`.switch` 样式，默认关闭。
    private let fillCheckbox = NSButton(checkboxWithTitle: AppText.rectanglePanelFilled, target: nil, action: nil)

    /// 颜色圆点按钮，按 `RGBColor.presetColors` 顺序构建。
    private var colorButtons: [NSButton] = []

    // MARK: - 初始化

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

    // MARK: - 配置

    /// 配置毛玻璃基础样式。
    ///
    /// 材质 `.popover`、连续圆角 12pt，与工具栏外观保持一致。
    private func setupView() {
        material = .popover
        blendingMode = .withinWindow
        state = .active
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.cornerCurve = .continuous



    }

    /// 创建所有子控件并设置 target/action。
    private func setupControls() {
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentContainer)

        leftColumnStack.orientation = .vertical
        leftColumnStack.alignment = .leading
        leftColumnStack.distribution = .fill
        leftColumnStack.spacing = 10
        leftColumnStack.translatesAutoresizingMaskIntoConstraints = false

        rightColumnStack.orientation = .vertical
        rightColumnStack.alignment = .leading
        rightColumnStack.distribution = .fillEqually
        rightColumnStack.spacing = 2
        rightColumnStack.translatesAutoresizingMaskIntoConstraints = false

        for i in 1...12 {
            lineWidthPopUp.addItem(withTitle: "\(i)px")
        }
        lineWidthPopUp.selectItem(at: 2)
        lineWidthPopUp.target = self
        lineWidthPopUp.action = #selector(lineWidthChanged)
        lineWidthPopUp.font = .systemFont(ofSize: 12)
        lineWidthPopUp.bezelStyle = .rounded
        lineWidthPopUp.translatesAutoresizingMaskIntoConstraints = false

        opacitySlider.minValue = 0
        opacitySlider.maxValue = 100
        opacitySlider.doubleValue = 100
        opacitySlider.isContinuous = true
        opacitySlider.target = self
        opacitySlider.action = #selector(opacityChanged)
        opacitySlider.controlSize = .small
        opacitySlider.translatesAutoresizingMaskIntoConstraints = false

        cornerRadiusSlider.minValue = 0
        cornerRadiusSlider.maxValue = 100
        cornerRadiusSlider.doubleValue = 0
        cornerRadiusSlider.isContinuous = true
        cornerRadiusSlider.target = self
        cornerRadiusSlider.action = #selector(cornerRadiusChanged)
        cornerRadiusSlider.controlSize = .small
        cornerRadiusSlider.translatesAutoresizingMaskIntoConstraints = false

        fillCheckbox.setButtonType(.switch)
        fillCheckbox.font = .systemFont(ofSize: 8, weight: .medium)
        fillCheckbox.target = self
        fillCheckbox.action = #selector(fillChanged)
        fillCheckbox.state = .off
        fillCheckbox.translatesAutoresizingMaskIntoConstraints = false

        lineWidthTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        opacityTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        cornerRadiusTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        fillTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        colorTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        opacityValueLabel.translatesAutoresizingMaskIntoConstraints = false
        cornerRadiusValueLabel.translatesAutoresizingMaskIntoConstraints = false

        for (index, preset) in RGBColor.presetColors.enumerated() {
            let button = NSButton(frame: .zero)
            button.title = ""
            button.translatesAutoresizingMaskIntoConstraints = false
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

        updateColorSelection(selectedIndex: 0)
    }

    /// 使用 Auto Layout 构建左右两列并组装行。
    ///
    /// 左列为粗细行与颜色区域，右列为透明度行、圆角行与填充行。
    private func setupLayout() {
        contentContainer.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(14)
            make.trailing.equalToSuperview().inset(14)
            make.top.equalToSuperview().offset(14)
            make.bottom.equalToSuperview().inset(12)
        }

        contentContainer.addSubview(leftColumnStack)
        contentContainer.addSubview(rightColumnStack)

        leftColumnStack.snp.makeConstraints { make in
            make.leading.top.equalToSuperview()
            make.bottom.lessThanOrEqualToSuperview()
            make.width.equalTo(130)
        }

        rightColumnStack.snp.makeConstraints { make in
            make.leading.equalTo(leftColumnStack.snp.trailing).offset(4)
            make.trailing.top.equalToSuperview()
            make.bottom.lessThanOrEqualToSuperview()
        }

        let lineWidthRow = makeLabeledRow(
            label: lineWidthTitleLabel,
            content: lineWidthPopUp,
            labelWidth: 22
        )
        let colorRow = makeColorSection()

        leftColumnStack.addArrangedSubview(lineWidthRow)
        leftColumnStack.addArrangedSubview(colorRow)

        let opacityRow = makeSliderRow(
            label: opacityTitleLabel,
            slider: opacitySlider,
            valueLabel: opacityValueLabel
        )
        let cornerRadiusRow = makeSliderRow(
            label: cornerRadiusTitleLabel,
            slider: cornerRadiusSlider,
            valueLabel: cornerRadiusValueLabel
        )
        let fillRow = makeLabeledRow(
            label: fillTitleLabel,
            content: fillCheckbox,
            labelWidth: 22
        )

        rightColumnStack.addArrangedSubview(opacityRow)
        rightColumnStack.addArrangedSubview(cornerRadiusRow)
        rightColumnStack.addArrangedSubview(fillRow)
    }

    // MARK: - 行构建器

    /// 创建“标签 + 控件”水平行，标签宽度固定，基线对齐。
    ///
    /// - Parameters:
    ///   - label: 行标题标签，约束至指定宽度。
    ///   - content: 行内控件。
    ///   - labelWidth: 标题标签的宽度约束值。
    /// - Returns: 组装好的 NSStackView。
    private func makeLabeledRow(label: NSTextField, content: NSView, labelWidth: CGFloat) -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .firstBaseline
        row.distribution = .fill
        row.spacing = 4
        row.translatesAutoresizingMaskIntoConstraints = false

        row.addArrangedSubview(label)
        row.addArrangedSubview(content)

        label.snp.makeConstraints { make in
            make.width.equalTo(labelWidth)
        }
        content.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(8)
        }
        row.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(10)
        }

        return row
    }

    /// 创建“标签 + 滑块 + 数值标签”水平行，垂直居中。
    ///
    /// - Parameters:
    ///   - label: 行标题标签，约束至 44pt 宽。
    ///   - slider: NSSlider。
    ///   - valueLabel: 右侧数值标签，约束至 36pt 宽，右对齐。
    /// - Returns: 组装好的 NSStackView。
    private func makeSliderRow(label: NSTextField, slider: NSSlider, valueLabel: NSTextField) -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.distribution = .fill
        row.spacing = 4
        row.translatesAutoresizingMaskIntoConstraints = false

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

    /// 创建颜色选择区域：标题行 + 2×4 网格圆点。
    ///
    /// 网格上方为红/橙/黄/绿，下方为蓝/紫/白/黑，每个圆点 18×18pt。
    ///
    /// - Returns: 包含标题和 NSGridView 的容器。
    private func makeColorSection() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(colorTitleLabel)
//        let titleRow = NSStackView()
//        titleRow.orientation = .horizontal
//        titleRow.alignment = .firstBaseline
//        titleRow.spacing = 2
//        titleRow.translatesAutoresizingMaskIntoConstraints = false
//        titleRow.addArrangedSubview(colorTitleLabel)

        let colorGrid = NSGridView(views: [
            Array(colorButtons.prefix(4)),
            Array(colorButtons.suffix(4))
        ])
        colorGrid.translatesAutoresizingMaskIntoConstraints = false
        colorGrid.rowSpacing = 4
        colorGrid.columnSpacing = 4
        colorGrid.xPlacement = .leading
        colorGrid.yPlacement = .center
        container.addSubview(colorGrid)

        colorTitleLabel.snp.makeConstraints { make in
            make.width.equalTo(22)
            make.leading.top.equalToSuperview()
        }

        colorGrid.snp.makeConstraints { make in
            make.leading.equalTo(colorTitleLabel.snp.trailing).offset(10)
            make.top.equalTo(colorTitleLabel.snp.top).offset(-3)
            make.bottom.equalToSuperview()
        }

        for button in colorButtons {
            button.snp.makeConstraints { make in
                make.width.height.equalTo(18)
            }
        }

        return container
    }

    // MARK: - 控件事件

    /// 粗细变更，下拉选索引 +1 即 px 值。
    @objc private func lineWidthChanged() {
        let selectedIndex = lineWidthPopUp.indexOfSelectedItem
        currentProperties.lineWidth = CGFloat(selectedIndex + 1)
    }

    /// 透明度变更，0–100 映射到 0.0–1.0，同步百分比标签。
    @objc private func opacityChanged() {
        let value = opacitySlider.doubleValue
        opacityValueLabel.stringValue = "\(Int(value))%"
        currentProperties.opacity = CGFloat(value) / 100.0
    }

    /// 圆角变更，同步 px 标签。
    @objc private func cornerRadiusChanged() {
        let value = cornerRadiusSlider.doubleValue
        cornerRadiusValueLabel.stringValue = "\(Int(value))px"
        currentProperties.cornerRadius = CGFloat(value)
    }

    /// 填充变更，`.on` 为实心，`.off` 为空心。
    @objc private func fillChanged() {
        currentProperties.isFilled = (fillCheckbox.state == .on)
    }

    /// 颜色变更，更新 preset 并刷新选中边框。
    @objc private func colorChanged(_ sender: NSButton) {
        let index = sender.tag
        guard index >= 0, index < RGBColor.presetColors.count else { return }
        currentProperties.color = RGBColor.presetColors[index]
        updateColorSelection(selectedIndex: index)
    }

    // MARK: - 对外接口

    /// 将面板控件同步到指定的矩形属性值。
    ///
    /// 用于选中已画矩形后回填面板显示。期间 `isUpdatingDisplay` 为 `true`，
    /// 避免 `currentProperties.didSet` 误将“同步展示”当作“用户操作”触发回调。
    ///
    /// - Parameter properties: 要同步显示的 `RectangleProperties`。
    func updateDisplay(with properties: RectangleProperties) {
        isUpdatingDisplay = true
        currentProperties = properties

        let lineWidthIndex = max(0, min(Int(properties.lineWidth) - 1, 11))
        lineWidthPopUp.selectItem(at: lineWidthIndex)

        opacitySlider.doubleValue = Double(properties.opacity * 100)
        opacityValueLabel.stringValue = "\(Int(properties.opacity * 100))%"

        cornerRadiusSlider.doubleValue = Double(properties.cornerRadius)
        cornerRadiusValueLabel.stringValue = "\(Int(properties.cornerRadius))px"

        fillCheckbox.state = properties.isFilled ? .on : .off

        if let colorIndex = RGBColor.presetColors.firstIndex(of: properties.color) {
            updateColorSelection(selectedIndex: colorIndex)
        }

        lineWidthTitleLabel.stringValue = AppText.rectanglePanelLineWidth
        opacityTitleLabel.stringValue = AppText.rectanglePanelOpacity
        cornerRadiusTitleLabel.stringValue = AppText.rectanglePanelCornerRadius
        fillTitleLabel.stringValue = AppText.rectanglePanelFill
        colorTitleLabel.stringValue = AppText.rectanglePanelColor
        fillCheckbox.title = AppText.rectanglePanelFilled

        isUpdatingDisplay = false
    }

    /// 刷新颜色圆点选中态边框。
    ///
    /// 选中的圆点显示 2pt 青色边框，其余无边框。
    ///
    /// - Parameter selectedIndex: 选中的颜色索引。
    private func updateColorSelection(selectedIndex: Int) {
        for (index, button) in colorButtons.enumerated() {
            button.layer?.borderWidth = (index == selectedIndex) ? 2 : 0
            button.layer?.borderColor = (index == selectedIndex) ? NSColor.systemCyan.cgColor : nil
        }
    }

    /// 颜色索引对应的 Tooltip 本地化名称。
    ///
    /// - Parameter index: 预设色索引（0–7）。
    /// - Returns: 颜色本地化名称。
    private func colorName(at index: Int) -> String {
        ["红", "橙", "黄", "绿", "蓝", "紫", "白", "黑"][safe: index] ?? ""
    }
}

// MARK: - 辅助类型

/// 面板标题标签。
///
/// 10pt 中等字重、次级文字颜色、不可编辑不可选中，用于属性行标题。
private final class RectanglePanelLabel: NSTextField {
    init(text: String) {
        super.init(frame: .zero)
        isEditable = false
        isBezeled = false
        drawsBackground = false
        isSelectable = false
        stringValue = text
        font = .systemFont(ofSize: 10, weight: .medium)
        textColor = .secondaryLabelColor
        lineBreakMode = .byTruncatingTail
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

/// 面板数值标签。
///
/// 10pt 等宽数字、次级文字颜色、右对齐，用于百分数和 px 值显示。
private final class RectanglePanelValueLabel: NSTextField {
    init(text: String) {
        super.init(frame: .zero)
        isEditable = false
        isBezeled = false
        drawsBackground = false
        isSelectable = false
        stringValue = text
        font = .monospacedDigitSystemFont(ofSize: 10, weight: .medium)
        textColor = .secondaryLabelColor
        alignment = .right
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension Array {
    /// 安全下标访问，越界返回 `nil`。
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
