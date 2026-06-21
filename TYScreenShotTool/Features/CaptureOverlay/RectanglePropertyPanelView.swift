//
//  RectanglePropertyPanelView.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/21.
//

import AppKit

/// 矩形属性面板
///
/// 在截图编辑态工具栏下方显示，提供矩形标注的实时样式调整。
///
/// **两列布局（左列 + 右列）：**
/// - 左列：粗细下拉选 + 颜色预设网格
/// - 右列：透明度滑块 + 圆角滑块 + 实心/空心复选框
///
/// **数据流：**
/// 用户调整面板控件 → `currentProperties.didSet` → `onPropertyChanged` 回调 → 外部更新画布
///
/// **反向同步：**
/// 外部调用 `updateDisplay(with:)` → 面板控件同步到指定属性值（如点击选中已画矩形时）
/// 通过 `isUpdatingDisplay` 标志避免触发冗余的回调循环
final class RectanglePropertyPanelView: NSVisualEffectView {
    /// 面板首选尺寸：宽 382pt，高 118pt
    static let preferredSize = CGSize(width: 382, height: 118)

    // MARK: - 回调

    /// 属性变更回调，由外部（CaptureOverlayView）设置，用于响应面板控件的用户操作
    var onPropertyChanged: ((RectangleProperties) -> Void)?

    // MARK: - 内部状态

    /// 防止 `updateDisplay` 触发 `didSet` → `onPropertyChanged` 产生冗余回调
    private var isUpdatingDisplay = false

    /// 当前面板属性值，`didSet` 中触发 `onPropertyChanged` 回调
    private var currentProperties = RectangleProperties.default {
        didSet {
            guard !isUpdatingDisplay else { return }
            onPropertyChanged?(currentProperties)
        }
    }

    // MARK: - 布局容器

    /// 内容容器，提供统一的 14pt 内边距
    private let contentContainer = NSView()

    /// 左列 StackView：约束宽度 156pt，垂直排布，间距 10pt
    private let leftColumnStack = NSStackView()

    /// 右列 StackView：弹性宽度，等分填充，垂直排布，间距 8pt
    private let rightColumnStack = NSStackView()

    // MARK: - 标题标签

    /// 粗细标题：“粗细”
    private let lineWidthTitleLabel = RectanglePanelLabel(text: AppText.rectanglePanelLineWidth)
    /// 透明度标题：“透明度”
    private let opacityTitleLabel = RectanglePanelLabel(text: AppText.rectanglePanelOpacity)
    /// 圆角标题：“圆角”
    private let cornerRadiusTitleLabel = RectanglePanelLabel(text: AppText.rectanglePanelCornerRadius)
    /// 填充标题：“填充”
    private let fillTitleLabel = RectanglePanelLabel(text: AppText.rectanglePanelFill)
    /// 颜色标题：“颜色”
    private let colorTitleLabel = RectanglePanelLabel(text: AppText.rectanglePanelColor)

    // MARK: - 交互控件

    /// 粗细下拉选，选项 1px ~ 12px，默认选中 3px（索引 2）
    private let lineWidthPopUp = NSPopUpButton()

    /// 透明度滑块，范围 0-100，默认 100%，连续触发
    private let opacitySlider = NSSlider()

    /// 透明度数值标签，显示当前百分比，等宽数字字体
    private let opacityValueLabel = RectanglePanelValueLabel(text: "100%")

    /// 圆角滑块，范围 0-100，默认 0px，连续触发
    private let cornerRadiusSlider = NSSlider()

    /// 圆角数值标签，显示当前 px 值，等宽数字字体
    private let cornerRadiusValueLabel = RectanglePanelValueLabel(text: "0px")

    /// 实心/空心复选框，`.switch` 样式，默认关闭（空心）
    private let fillCheckbox = NSButton(checkboxWithTitle: AppText.rectanglePanelFilled, target: nil, action: nil)

    /// 颜色圆点按钮数组，R/G/B/Y/C/M/W/K 预设 8 色
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

    // MARK: - 视图与控件配置

    /// 配置毛玻璃基础样式：`.popover` 材质，圆角 12pt，连续曲线
    private func setupView() {
        material = .popover
        blendingMode = .withinWindow
        state = .active
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.cornerCurve = .continuous
    }

    /// 创建并配置所有子控件，设置 target/action，加入视图层级
    private func setupControls() {
        // 内容容器使用 Auto Layout
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentContainer)

        // 左列：垂直排布，左对齐，自然高度，间距 10pt
        leftColumnStack.orientation = .vertical
        leftColumnStack.alignment = .leading
        leftColumnStack.distribution = .fill
        leftColumnStack.spacing = 10
        leftColumnStack.translatesAutoresizingMaskIntoConstraints = false

        // 右列：垂直排布，左对齐，等分填充，间距 8pt
        rightColumnStack.orientation = .vertical
        rightColumnStack.alignment = .leading
        rightColumnStack.distribution = .fillEqually
        rightColumnStack.spacing = 8
        rightColumnStack.translatesAutoresizingMaskIntoConstraints = false

        // --- 粗细下拉选 ---
        for i in 1...12 {
            lineWidthPopUp.addItem(withTitle: "\(i)px")
        }
        lineWidthPopUp.selectItem(at: 2) // 默认 3px
        lineWidthPopUp.target = self
        lineWidthPopUp.action = #selector(lineWidthChanged)
        lineWidthPopUp.font = .systemFont(ofSize: 12)
        lineWidthPopUp.bezelStyle = .rounded
        lineWidthPopUp.translatesAutoresizingMaskIntoConstraints = false

        // --- 透明度滑块 ---
        opacitySlider.minValue = 0
        opacitySlider.maxValue = 100
        opacitySlider.doubleValue = 100
        opacitySlider.isContinuous = true
        opacitySlider.target = self
        opacitySlider.action = #selector(opacityChanged)
        opacitySlider.controlSize = .small
        opacitySlider.translatesAutoresizingMaskIntoConstraints = false

        // --- 圆角滑块 ---
        cornerRadiusSlider.minValue = 0
        cornerRadiusSlider.maxValue = 100
        cornerRadiusSlider.doubleValue = 0
        cornerRadiusSlider.isContinuous = true
        cornerRadiusSlider.target = self
        cornerRadiusSlider.action = #selector(cornerRadiusChanged)
        cornerRadiusSlider.controlSize = .small
        cornerRadiusSlider.translatesAutoresizingMaskIntoConstraints = false

        // --- 实心/空心复选框 ---
        fillCheckbox.setButtonType(.switch)
        fillCheckbox.font = .systemFont(ofSize: 13, weight: .medium)
        fillCheckbox.target = self
        fillCheckbox.action = #selector(fillChanged)
        fillCheckbox.state = .off
        fillCheckbox.translatesAutoresizingMaskIntoConstraints = false

        // 标题和数值标签启用 Auto Layout
        lineWidthTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        opacityTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        cornerRadiusTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        fillTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        colorTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        opacityValueLabel.translatesAutoresizingMaskIntoConstraints = false
        cornerRadiusValueLabel.translatesAutoresizingMaskIntoConstraints = false

        // --- 颜色圆点按钮 ---
        for (index, preset) in RGBColor.presetColors.enumerated() {
            let button = NSButton(frame: .zero)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.wantsLayer = true
            button.isBordered = false
            button.layer?.backgroundColor = preset.toNSColor().cgColor
            button.layer?.cornerRadius = 9 // 18pt 直径 → 圆角半径 9
            button.layer?.borderWidth = 0
            button.tag = index
            button.target = self
            button.action = #selector(colorChanged(_:))
            button.toolTip = colorName(at: index)
            colorButtons.append(button)
        }

        // 默认选中红色（索引 0），显示青色选中边框
        updateColorSelection(selectedIndex: 0)
    }

    /// 使用 Auto Layout 构建左右两列布局，组装行元素和颜色区域
    private func setupLayout() {
        // 内容容器：14pt 四边内边距
        NSLayoutConstraint.activate([
            contentContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            contentContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            contentContainer.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            contentContainer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])

        contentContainer.addSubview(leftColumnStack)
        contentContainer.addSubview(rightColumnStack)

        // 左右列约束：左列固定 156pt，右列填充剩余空间，列间距 18pt
        NSLayoutConstraint.activate([
            leftColumnStack.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            leftColumnStack.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            leftColumnStack.bottomAnchor.constraint(lessThanOrEqualTo: contentContainer.bottomAnchor),

            rightColumnStack.leadingAnchor.constraint(equalTo: leftColumnStack.trailingAnchor, constant: 18),
            rightColumnStack.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            rightColumnStack.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            rightColumnStack.bottomAnchor.constraint(lessThanOrEqualTo: contentContainer.bottomAnchor),

            leftColumnStack.widthAnchor.constraint(equalToConstant: 156)
        ])

        // 左列：粗细行 + 颜色区域
        let lineWidthRow = makeLabeledRow(
            label: lineWidthTitleLabel,
            content: lineWidthPopUp,
            labelWidth: 52
        )
        let colorRow = makeColorSection()

        leftColumnStack.addArrangedSubview(lineWidthRow)
        leftColumnStack.addArrangedSubview(colorRow)

        // 右列：透明度滑块行 + 圆角滑块行 + 填充复选框行
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
            labelWidth: 44
        )

        rightColumnStack.addArrangedSubview(opacityRow)
        rightColumnStack.addArrangedSubview(cornerRadiusRow)
        rightColumnStack.addArrangedSubview(fillRow)
    }

    // MARK: - 行构建器

    /// 创建“标签 + 控件”水平行
    /// - Parameters:
    ///   - label: 行标题标签（固定宽度）
    ///   - content: 行内控件（下拉选、复选框等）
    ///   - labelWidth: 标题标签宽度约束
    /// - Returns: 组装好的水平 NSStackView
    private func makeLabeledRow(label: NSTextField, content: NSView, labelWidth: CGFloat) -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .firstBaseline    // 文字基线对齐
        row.distribution = .fill
        row.spacing = 8
        row.translatesAutoresizingMaskIntoConstraints = false

        row.addArrangedSubview(label)
        row.addArrangedSubview(content)

        NSLayoutConstraint.activate([
            label.widthAnchor.constraint(equalToConstant: labelWidth),
            content.heightAnchor.constraint(greaterThanOrEqualToConstant: 20),
            row.heightAnchor.constraint(greaterThanOrEqualToConstant: 22)
        ])

        return row
    }

    /// 创建“标签 + 滑块 + 数值标签”水平行
    /// - Parameters:
    ///   - label: 行标题标签（44pt 固定宽度）
    ///   - slider: NSSlider
    ///   - valueLabel: 右侧数值标签（36pt 固定宽度，等宽字体右对齐）
    /// - Returns: 组装好的水平 NSStackView
    private func makeSliderRow(label: NSTextField, slider: NSSlider, valueLabel: NSTextField) -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY    // 垂直居中
        row.distribution = .fill
        row.spacing = 6
        row.translatesAutoresizingMaskIntoConstraints = false

        row.addArrangedSubview(label)
        row.addArrangedSubview(slider)
        row.addArrangedSubview(valueLabel)

        NSLayoutConstraint.activate([
            label.widthAnchor.constraint(equalToConstant: 44),
            valueLabel.widthAnchor.constraint(equalToConstant: 36),
            slider.heightAnchor.constraint(equalToConstant: 20),
            row.heightAnchor.constraint(equalToConstant: 24)
        ])

        return row
    }

    /// 创建颜色选择区域：标题 + 2×4 网格圆点
    /// - Returns: 包含标题行和 NSGridView 的容器视图
    private func makeColorSection() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        // 颜色标题行
        let titleRow = NSStackView()
        titleRow.orientation = .horizontal
        titleRow.alignment = .firstBaseline
        titleRow.spacing = 8
        titleRow.translatesAutoresizingMaskIntoConstraints = false
        titleRow.addArrangedSubview(colorTitleLabel)
        titleRow.addArrangedSubview(NSView()) // 弹簧，占满剩余空间

        // 2 行 × 4 列颜色网格
        let colorGrid = NSGridView(views: [
            Array(colorButtons.prefix(4)),   // 第一行：红/橙/黄/绿
            Array(colorButtons.suffix(4))    // 第二行：蓝/紫/白/黑
        ])
        colorGrid.translatesAutoresizingMaskIntoConstraints = false
        colorGrid.rowSpacing = 8
        colorGrid.columnSpacing = 8
        colorGrid.xPlacement = .leading
        colorGrid.yPlacement = .center

        container.addSubview(titleRow)
        container.addSubview(colorGrid)

        NSLayoutConstraint.activate([
            colorTitleLabel.widthAnchor.constraint(equalToConstant: 52),

            titleRow.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titleRow.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            titleRow.topAnchor.constraint(equalTo: container.topAnchor),

            // 颜色网格左侧缩进 60pt，在标题下方 6pt
            colorGrid.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 60),
            colorGrid.topAnchor.constraint(equalTo: titleRow.bottomAnchor, constant: 6),
            colorGrid.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            container.heightAnchor.constraint(equalToConstant: 54)
        ])

        // 每个颜色圆点：18 × 18pt
        for button in colorButtons {
            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalToConstant: 18),
                button.heightAnchor.constraint(equalToConstant: 18)
            ])
        }

        return container
    }

    // MARK: - 控件事件

    /// 粗细下拉选变更：`indexOfSelectedItem + 1` 即 px 值
    @objc private func lineWidthChanged() {
        let selectedIndex = lineWidthPopUp.indexOfSelectedItem
        currentProperties.lineWidth = CGFloat(selectedIndex + 1)
    }

    /// 透明度滑块变更：0-100 映射到 0.0-1.0，同步更新百分比标签
    @objc private func opacityChanged() {
        let value = opacitySlider.doubleValue
        opacityValueLabel.stringValue = "\(Int(value))%"
        currentProperties.opacity = CGFloat(value) / 100.0
    }

    /// 圆角滑块变更：0-100 直接映射到 CGFloat，同步更新 px 标签
    @objc private func cornerRadiusChanged() {
        let value = cornerRadiusSlider.doubleValue
        cornerRadiusValueLabel.stringValue = "\(Int(value))px"
        currentProperties.cornerRadius = CGFloat(value)
    }

    /// 填充复选框变更：`.on` = 实心，`.off` = 空心
    @objc private func fillChanged() {
        currentProperties.isFilled = (fillCheckbox.state == .on)
    }

    /// 颜色圆点点击：更新 `currentProperties.color` 并刷新选中边框
    @objc private func colorChanged(_ sender: NSButton) {
        let index = sender.tag
        guard index >= 0, index < RGBColor.presetColors.count else { return }
        currentProperties.color = RGBColor.presetColors[index]
        updateColorSelection(selectedIndex: index)
    }

    // MARK: - 外部同步接口

    /// 外部调用，将面板值同步到指定属性（如点击选中已画矩形时）
    ///
    /// 通过 `isUpdatingDisplay` 标志暂停 `didSet` 回调，
    /// 避免将“同步面板显示”误判为“用户修改属性”而触发重复更新。
    ///
    /// - Parameter properties: 要同步显示的矩形属性
    func updateDisplay(with properties: RectangleProperties) {
        isUpdatingDisplay = true
        currentProperties = properties

        // 粗细：CGFloat → 下拉选索引（0-based，clamp 到 0-11）
        let lineWidthIndex = max(0, min(Int(properties.lineWidth) - 1, 11))
        lineWidthPopUp.selectItem(at: lineWidthIndex)

        // 透明度：0.0-1.0 → 0-100
        opacitySlider.doubleValue = Double(properties.opacity * 100)
        opacityValueLabel.stringValue = "\(Int(properties.opacity * 100))%"

        // 圆角：CGFloat → slider + "Npx"
        cornerRadiusSlider.doubleValue = Double(properties.cornerRadius)
        cornerRadiusValueLabel.stringValue = "\(Int(properties.cornerRadius))px"

        // 填充：Bool → checkbox state
        fillCheckbox.state = properties.isFilled ? .on : .off

        // 颜色：在预设列表中匹配
        if let colorIndex = RGBColor.presetColors.firstIndex(of: properties.color) {
            updateColorSelection(selectedIndex: colorIndex)
        }

        // 刷新控件标题（支持本地化切换时更新文案）
        lineWidthTitleLabel.stringValue = AppText.rectanglePanelLineWidth
        opacityTitleLabel.stringValue = AppText.rectanglePanelOpacity
        cornerRadiusTitleLabel.stringValue = AppText.rectanglePanelCornerRadius
        fillTitleLabel.stringValue = AppText.rectanglePanelFill
        colorTitleLabel.stringValue = AppText.rectanglePanelColor
        fillCheckbox.title = AppText.rectanglePanelFilled

        isUpdatingDisplay = false
    }

    /// 更新颜色圆点的选中态：选中项显示 2pt 青色边框，其他项无边框
    /// - Parameter selectedIndex: 当前选中颜色的索引
    private func updateColorSelection(selectedIndex: Int) {
        for (index, button) in colorButtons.enumerated() {
            button.layer?.borderWidth = (index == selectedIndex) ? 2 : 0
            button.layer?.borderColor = (index == selectedIndex) ? NSColor.systemCyan.cgColor : nil
        }
    }

    /// 颜色圆点的 Tooltip 中文名
    /// - Parameter index: 颜色索引 0-7
    /// - Returns: "红"/"橙"/"黄"/"绿"/"蓝"/"紫"/"白"/"黑"
    private func colorName(at index: Int) -> String {
        ["红", "橙", "黄", "绿", "蓝", "紫", "白", "黑"][safe: index] ?? ""
    }
}

// MARK: - 辅助类型

/// 面板标题标签：10pt 中等字重，次级文字颜色，不可编辑不可选中
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

/// 面板数值标签：10pt 等宽数字，次级文字颜色，右对齐，用于百分比/px 值显示
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
    /// 安全下标访问，越界返回 nil
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
