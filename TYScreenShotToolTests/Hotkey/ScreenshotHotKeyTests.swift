import Carbon
import XCTest
@testable import TShot

final class ScreenshotHotKeyTests: XCTestCase {

    // MARK: - Default

    func test_defaultHotKey_is_commad_shift_2() {
        let hotKey = ScreenshotHotKey.screenshot
        XCTAssertEqual(hotKey.keyCode, UInt32(kVK_ANSI_2))
        XCTAssertEqual(hotKey.modifiers, UInt32(cmdKey | shiftKey))
    }

    // MARK: - Storage Value

    func test_storageValue_format() {
        let hotKey = ScreenshotHotKey(keyCode: UInt32(kVK_ANSI_2), modifiers: UInt32(cmdKey | shiftKey))
        XCTAssertEqual(hotKey.storageValue, "\(UInt32(kVK_ANSI_2)):\(UInt32(cmdKey | shiftKey))")
    }

    func test_storageValue_roundTrip() {
        let original = ScreenshotHotKey(keyCode: UInt32(kVK_ANSI_A), modifiers: UInt32(cmdKey | optionKey))
        let parsed = ScreenshotHotKey(storageValue: original.storageValue)
        XCTAssertEqual(parsed, original)
    }

    func test_storageValue_roundTrip_with_control_modifier() {
        let original = ScreenshotHotKey(keyCode: UInt32(kVK_ANSI_5), modifiers: UInt32(controlKey | shiftKey))
        let parsed = ScreenshotHotKey(storageValue: original.storageValue)
        XCTAssertEqual(parsed, original)
    }

    // MARK: - Old Format Parsing

    func test_parses_old_commandShift2_format() {
        let hotKey = ScreenshotHotKey(storageValue: "commandShift2")
        XCTAssertNotNil(hotKey)
        XCTAssertEqual(hotKey, ScreenshotHotKey.screenshot)
    }

    func test_parses_old_commandShift8_format() {
        let hotKey = ScreenshotHotKey(storageValue: "commandShift8")
        XCTAssertNotNil(hotKey)
        XCTAssertEqual(hotKey?.keyCode, UInt32(kVK_ANSI_8))
    }

    func test_parses_old_commandShift9_format() {
        let hotKey = ScreenshotHotKey(storageValue: "commandShift9")
        XCTAssertNotNil(hotKey)
        XCTAssertEqual(hotKey?.keyCode, UInt32(kVK_ANSI_9))
    }

    // MARK: - Invalid Storage Value

    func test_invalid_storageValue_returns_nil() {
        XCTAssertNil(ScreenshotHotKey(storageValue: ""))
        XCTAssertNil(ScreenshotHotKey(storageValue: "invalid"))
        XCTAssertNil(ScreenshotHotKey(storageValue: "abc:123"))
        XCTAssertNil(ScreenshotHotKey(storageValue: "999:768")) // unknown key code
    }

    func test_missing_modifier_returns_nil() {
        // "18:" only — missing modifier part
        XCTAssertNil(ScreenshotHotKey(storageValue: "18:"))
    }

    func test_non_numeric_storageValue_returns_nil() {
        XCTAssertNil(ScreenshotHotKey(storageValue: "abc:def"))
    }

    // MARK: - Candidate

    func test_makeCandidate_valid_keyCode() {
        let candidate = ScreenshotHotKey.makeCandidate(
            keyCode: UInt32(kVK_ANSI_A),
            modifiers: UInt32(cmdKey)
        )
        XCTAssertNotNil(candidate)
        XCTAssertEqual(candidate?.keyCode, UInt32(kVK_ANSI_A))
        XCTAssertEqual(candidate?.modifiers, UInt32(cmdKey))
    }

    func test_makeCandidate_invalid_keyCode() {
        let candidate = ScreenshotHotKey.makeCandidate(
            keyCode: 0xFFFF,
            modifiers: UInt32(cmdKey)
        )
        XCTAssertNil(candidate)
    }

    // MARK: - Display Name

    func test_displayName_includes_modifiers_and_key() {
        let hotKey = ScreenshotHotKey(keyCode: UInt32(kVK_ANSI_A), modifiers: UInt32(cmdKey | optionKey))
        XCTAssertEqual(hotKey.displayName, "⌘⌥A")
    }

    func test_displayName_shift_only() {
        let hotKey = ScreenshotHotKey(keyCode: UInt32(kVK_ANSI_2), modifiers: UInt32(shiftKey))
        XCTAssertEqual(hotKey.displayName, "⇧2")
    }

    func test_displayName_all_modifiers() {
        let hotKey = ScreenshotHotKey(
            keyCode: UInt32(kVK_ANSI_F),
            modifiers: UInt32(cmdKey | shiftKey | optionKey | controlKey)
        )
        XCTAssertEqual(hotKey.displayName, "⌘⇧⌥⌃F")
    }

    func test_displayName_no_modifiers() {
        let hotKey = ScreenshotHotKey(keyCode: UInt32(kVK_ANSI_X), modifiers: 0)
        XCTAssertEqual(hotKey.displayName, "X")
    }

    // MARK: - Presets

    func test_presets_contains_three_items() {
        XCTAssertEqual(ScreenshotHotKey.presets.count, 3)
    }

    func test_first_preset_is_screenshot_default() {
        XCTAssertEqual(ScreenshotHotKey.presets[0], ScreenshotHotKey.screenshot)
    }

    func test_presets_all_have_valid_storageValues() {
        for preset in ScreenshotHotKey.presets {
            let parsed = ScreenshotHotKey(storageValue: preset.storageValue)
            XCTAssertEqual(parsed, preset)
        }
    }
}
