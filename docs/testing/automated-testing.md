# 自动测试

当前项目的自动测试基于 `XCTest`。

Sprint 46 起，仓库内已具备正式的单元测试 target：

- `TYScreenShotToolTests`

当前自动测试定位：

- 优先覆盖纯逻辑
- 优先覆盖配置解析
- 优先覆盖枚举映射
- 不依赖窗口交互、系统权限、截图设备或 AI 网络环境

---

## 运行方式

运行全部单元测试：

```bash
xcodebuild \
  -project TYScreenShotTool.xcodeproj \
  -scheme TYScreenShotTool \
  -configuration Debug \
  -derivedDataPath DerivedDataTests \
  test
```

如需先清理测试构建产物，可执行：

```bash
rm -rf DerivedDataTests
```

当前项目保留 `./scripts/build.sh` 作为构建命令；
自动测试暂未单独封装为脚本，默认直接使用上面的 `xcodebuild test` 命令。

---

## 当前覆盖范围

Sprint 46 首批自动测试覆盖：

- `ScreenshotHotKey`
  - 默认值
  - 存储值序列化 / 反序列化
  - 旧格式兼容解析
  - 非法输入回退
  - 候选键过滤
  - 显示名称拼接
- `KeyEquivalentNameMap`
  - 字母键映射
  - 数字键映射
  - 功能键映射
  - 方向键映射
  - 不支持键码返回 `nil`
- `AppLanguage`
  - `storageValue`
  - `localizationCode`
  - `resolved(userSelection:preferredLanguages:)`
  - `ocrRecognitionLanguages`
  - `supportedDisplayLanguages`
- `AppLocalization`
  - `UserDefaults` 读取
  - 默认值回退
  - 非法值回退
  - `currentLanguage` 解析
- `AppSettings`
  - 关键键名常量
  - 默认值常量
- `AppAppearance`
  - `storageValue`
  - `nsAppearance`
  - 枚举集合

当前测试总数：

- `96` 个测试用例

---

## 当前未覆盖范围

以下能力当前仍以人工测试为主：

- `ScreenCaptureKit` 截图链路
- `Vision` OCR 真识别结果
- AI 请求链路与网络错误语义
- 菜单栏交互
- Settings 页面 AppKit 控件交互
- Overlay / 标注画布交互
- 结果窗口 UI
- 长截图控制面板、预览窗与完整滚动链路

原因：

- 这些能力更依赖系统权限、窗口行为或真实交互环境
- 第一版自动测试优先保证稳定、可重复、低脆弱性

---

## 扩展原则

后续新增自动测试时，优先遵守以下规则：

1. 先测纯逻辑，再测复杂交互。
2. 能通过参数注入或隔离存储完成测试的，不为测试做大范围重构。
3. 若某能力强依赖窗口、权限或真实设备，先补人工测试，再评估是否值得自动化。
4. 测试命名优先表达行为，不优先表达实现细节。
5. 测试必须可在本地重复运行，不依赖个人机器临时状态。

---

## 人工测试配合

自动测试不是当前项目唯一验证手段。

Sprint 46 起，推荐验证节奏为：

1. 设计功能时先明确自动测试覆盖范围与人工测试边界
2. 实现完成后先运行 `./scripts/build.sh`
3. 再运行自动测试命令
4. 最后按当前 Sprint 文档中的人工测试附录完成主链路回归

当前人工测试附录位置：

- `docs/SPRINTS/Sprint-46.md`
