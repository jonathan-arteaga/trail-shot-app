@testable import TrailShot
import Carbon.HIToolbox
import XCTest

final class GlobalShortcutTests: XCTestCase {
    func testDefaultShortcutsUseConflictSafeModifiers() {
        let shortcuts = GlobalShortcutAction.allCases.map(\.defaultShortcut)

        XCTAssertEqual(shortcuts.map(\.displayValue), ["⌃⌥⇧4", "⌃⌥⇧3", "⌃⌥⇧5", "⌃⌥⇧R", "⌃⌥⇧A"])
        XCTAssertEqual(Set(shortcuts.map(\.keyCode)).count, shortcuts.count)
        XCTAssertTrue(shortcuts.allSatisfy { $0.modifiers != 0 })
    }

    @MainActor
    func testShortcutPreferencePersists() {
        let defaults = UserDefaults(suiteName: "TrailShotTests.GlobalShortcutTests")!
        defaults.removePersistentDomain(forName: "TrailShotTests.GlobalShortcutTests")

        let store = CaptureStore(userDefaults: defaults)
        XCTAssertTrue(store.areGlobalShortcutsEnabled)

        store.setGlobalShortcutsEnabled(false)

        let restoredStore = CaptureStore(userDefaults: defaults)
        XCTAssertFalse(restoredStore.areGlobalShortcutsEnabled)
    }

    @MainActor
    func testCustomShortcutPersists() {
        let defaults = UserDefaults(suiteName: "TrailShotTests.CustomGlobalShortcutTests")!
        defaults.removePersistentDomain(forName: "TrailShotTests.CustomGlobalShortcutTests")

        let store = CaptureStore(userDefaults: defaults)
        store.updateGlobalShortcut(
            GlobalShortcut(
                action: .captureArea,
                keyCode: UInt32(kVK_ANSI_6),
                modifiers: UInt32(controlKey | optionKey)
            )
        )

        let restoredStore = CaptureStore(userDefaults: defaults)
        XCTAssertEqual(restoredStore.shortcut(for: .captureArea).displayValue, "⌃⌥6")
    }

    @MainActor
    func testDuplicateShortcutIsRejected() {
        let defaults = UserDefaults(suiteName: "TrailShotTests.DuplicateGlobalShortcutTests")!
        defaults.removePersistentDomain(forName: "TrailShotTests.DuplicateGlobalShortcutTests")
        let store = CaptureStore(userDefaults: defaults)
        let existing = store.shortcut(for: .captureArea)

        store.updateGlobalShortcut(
            GlobalShortcut(
                action: .captureWindow,
                keyCode: existing.keyCode,
                modifiers: existing.modifiers
            )
        )

        XCTAssertNotEqual(store.shortcut(for: .captureWindow), existing)
        XCTAssertEqual(store.shortcutEditingMessage, "\(existing.displayValue) is already assigned.")
    }
}
