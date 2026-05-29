@testable import TrailShot
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
}
