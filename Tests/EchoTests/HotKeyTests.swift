import AppKit
import Carbon
@testable import Echo
import XCTest

final class HotKeyTests: XCTestCase {
    private var suiteName: String!
    private var originalDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "com.kartikjain.echo.tests.\(UUID().uuidString)"
        originalDefaults = HotKeyPreference.defaults
        HotKeyPreference.defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        HotKeyPreference.defaults.removePersistentDomain(forName: suiteName)
        HotKeyPreference.defaults = originalDefaults
        super.tearDown()
    }

    func testDefaultsToCommandShiftV() {
        XCTAssertEqual(HotKeyPreference.keyCode, UInt32(kVK_ANSI_V))
        XCTAssertEqual(HotKeyPreference.modifiers, UInt32(cmdKey | shiftKey))
        XCTAssertTrue(HotKeyPreference.isDefault)
        XCTAssertEqual(HotKeyPreference.displayString, "⇧⌘V")
    }

    func testPersistsAChosenShortcut() {
        HotKeyPreference.set(keyCode: UInt32(kVK_ANSI_C), modifiers: UInt32(optionKey | controlKey))

        XCTAssertEqual(HotKeyPreference.keyCode, UInt32(kVK_ANSI_C))
        XCTAssertEqual(HotKeyPreference.modifiers, UInt32(optionKey | controlKey))
        XCTAssertFalse(HotKeyPreference.isDefault)
        XCTAssertEqual(HotKeyPreference.displayString, "⌃⌥C")
    }

    func testDisplayStringOrdersModifiersAndNamesKeys() {
        let all = UInt32(cmdKey | shiftKey | optionKey | controlKey)
        XCTAssertEqual(HotKeyPreference.displayString(keyCode: UInt32(kVK_Space), modifiers: all), "⌃⌥⇧⌘Space")
        XCTAssertEqual(HotKeyPreference.displayString(keyCode: UInt32(kVK_ANSI_5), modifiers: UInt32(cmdKey)), "⌘5")
        XCTAssertEqual(HotKeyPreference.keyName(for: 999), "Key999")
    }

    func testCarbonModifiersMapEachAppKitFlag() {
        XCTAssertEqual(HotKeyPreference.carbonModifiers(from: []), 0)
        XCTAssertEqual(HotKeyPreference.carbonModifiers(from: .command), UInt32(cmdKey))
        XCTAssertEqual(HotKeyPreference.carbonModifiers(from: [.shift, .option]), UInt32(shiftKey | optionKey))
        XCTAssertEqual(HotKeyPreference.carbonModifiers(from: [.command, .shift, .option, .control, .capsLock]),
                       UInt32(cmdKey | shiftKey | optionKey | controlKey),
                       "Caps Lock is not a shortcut modifier")
    }

    func testRecorderSavesAnAcceptedShortcut() {
        let recorder = ShortcutRecorder()
        var applied: (UInt32, UInt32)?
        recorder.onChange = { applied = ($0, $1); return true }

        recorder.apply(keyCode: UInt32(kVK_ANSI_K), modifiers: UInt32(cmdKey))

        XCTAssertEqual(applied?.0, UInt32(kVK_ANSI_K))
        XCTAssertEqual(recorder.displayString, "⌘K")
        XCTAssertNil(recorder.errorMessage)
        XCTAssertEqual(HotKeyPreference.keyCode, UInt32(kVK_ANSI_K))
    }

    func testRecorderKeepsTheWorkingShortcutWhenOneIsRefused() {
        let recorder = ShortcutRecorder()
        recorder.onChange = { _, _ in false }

        recorder.apply(keyCode: UInt32(kVK_ANSI_K), modifiers: UInt32(cmdKey))

        XCTAssertEqual(recorder.errorMessage, "⌘K is unavailable. Try another shortcut.")
        XCTAssertEqual(recorder.displayString, "⇧⌘V")
        XCTAssertTrue(HotKeyPreference.isDefault, "A refused shortcut must not be saved")
    }

    func testRestoreDefaultClearsAnError() {
        let recorder = ShortcutRecorder()
        recorder.onChange = { _, _ in true }
        recorder.apply(keyCode: UInt32(kVK_ANSI_K), modifiers: UInt32(cmdKey))
        recorder.errorMessage = "stale"

        recorder.resetToDefault()

        XCTAssertNil(recorder.errorMessage)
        XCTAssertFalse(recorder.isRecording)
        XCTAssertTrue(HotKeyPreference.isDefault)
    }
}
