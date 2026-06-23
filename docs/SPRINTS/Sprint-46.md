# Sprint 46 - 测试补齐

## Status

✅ Done

## Goal

为项目补齐最小可运行的测试环节：建立正式 `XCTest` 单元测试基座，补第一批自动测试，并新增自动测试说明与当前 Sprint 的人工测试附录。

---

## Scope

### Included

- 新增 `TYScreenShotToolTests` 单元测试 target
- 新增共享 scheme，支持 `xcodebuild test`
- 新增 `TestUserDefaults` 测试辅助
- 为稳定纯逻辑模块补第一批单元测试
- 新增自动测试文档
- 新增当前 Sprint 人工测试附录

### Out of Scope

- 不引入 `XCUITest`
- 不补全所有 service 测试
- 不重构现有截图主状态机
- 不将窗口交互、权限链路、AI 网络链路自动化

---

## Implementation

### 实现

- 在工程中新增 `TYScreenShotToolTests` 测试 target
- 新增共享 scheme：`TYScreenShotTool.xcscheme`
- 新增 `TestUserDefaults.swift`，使用隔离 suite 避免污染本机配置
- 新增 `ScreenshotHotKeyTests.swift`
- 新增 `KeyEquivalentNameMapTests.swift`
- 新增 `AppLanguageTests.swift`
- 新增 `AppLocalizationTests.swift`
- 新增 `AppSettingsTests.swift`
- 新增 `AppAppearanceTests.swift`
- 新增自动测试说明文档：`docs/testing/automated-testing.md`

### 自动测试覆盖

- `ScreenshotHotKey`
  - 默认值
  - 存储值 round-trip
  - 旧格式兼容
  - 非法值回退
  - 候选键过滤
  - 显示名称
- `KeyEquivalentNameMap`
  - 字母 / 数字 / 功能键 / 方向键映射
  - 不支持键码返回 `nil`
- `AppLanguage`
  - 存储值
  - 本地化 code
  - 跟随系统解析
  - OCR 识别语言顺序
  - 支持展示语言集合
- `AppLocalization`
  - 语言配置读取
  - 默认值回退
  - 非法值回退
  - 当前语言解析
- `AppSettings`
  - 配置 key 常量
  - 默认值常量
- `AppAppearance`
  - 存储值
  - `NSAppearance` 映射
  - 枚举 case

---

## Validation

1. `./scripts/build.sh` 构建通过
2. `xcodebuild -project TYScreenShotTool.xcodeproj -scheme TYScreenShotTool -configuration Debug -derivedDataPath DerivedDataTests test` 测试通过
3. 首批 `96` 个单元测试全部通过
4. 新增测试 target、scheme 与测试文档已纳入仓库
5. 人工测试附录补齐

---

## Manual Testing Appendix

### 1. 启动与菜单栏

步骤：

1. 启动 App
2. 观察菜单栏是否显示图标
3. 点击菜单栏图标展开菜单

预期：

- 菜单栏图标可见
- 菜单可正常展开
- `Settings` 等基础入口可见

### 2. 全局截图热键

步骤：

1. 使用当前配置的截图热键
2. 在桌面或任意窗口上触发截图

预期：

- 可以进入截图态
- 不出现热键失效或无响应

### 3. 普通截图编辑态

步骤：

1. 进行一次普通框选截图
2. 进入截图编辑态
3. 依次点击矩形、圆形、直线、箭头、画笔、文字、马赛克

预期：

- 编辑态可正常进入
- 工具栏显示正常
- 各标注工具可正常切换
- 属性面板与既有行为无明显回退

### 4. Settings 页面

步骤：

1. 从菜单栏打开 `Settings`
2. 检查 `HotKey`、保存目录、语言、外观、AI 配置 section
3. 切换语言或外观后观察页面刷新

预期：

- Settings 可正常打开
- 5 个 section 布局可用
- 切换后界面刷新正常

### 5. OCR / AI 结果链路

步骤：

1. 在普通截图中触发 OCR
2. 在普通截图中触发 AI
3. 验证复制、关闭等关键动作

预期：

- OCR 结果窗可正常显示
- AI 结果窗可正常显示
- 关键按钮行为不回退

### 6. 长截图主链路

步骤：

1. 进入长截图模式
2. 检查控制面板与预览窗
3. 在长截图结果上触发 OCR / AI

预期：

- 控制面板可用
- 预览窗可用
- 长截图结果链路未因测试接入回退

### 7. 输出能力回归

步骤：

1. 在普通截图中执行复制
2. 在普通截图中执行保存
3. 在普通截图中执行 Pin

预期：

- 复制成功
- 保存成功
- Pin 正常显示

---

## Result

Sprint 46 完成后，TShot 已从“只有零散人工验证记录”的状态，
进入“自动测试 + 人工测试并存”的最小可运行测试阶段：

- 自动测试负责保护纯逻辑和配置解析
- 人工测试继续覆盖窗口交互与真实主链路

这为后续每个 Feature / Sprint 的验证收尾提供了统一起点。
