@testable import TrailShot
import XCTest

final class PrivacyPreferenceTests: XCTestCase {
    @MainActor
    func testAutoRedactAfterCaptureDefaultsOffAndPersists() {
        let suiteName = "TrailShotTests.PrivacyPreferenceTests"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let store = CaptureStore(userDefaults: defaults, captureLibraryDirectory: Self.temporaryCaptureDirectory())
        XCTAssertFalse(store.isAutoRedactAfterCaptureEnabled)

        store.setAutoRedactAfterCaptureEnabled(true)

        let restoredStore = CaptureStore(userDefaults: defaults, captureLibraryDirectory: Self.temporaryCaptureDirectory())
        XCTAssertTrue(restoredStore.isAutoRedactAfterCaptureEnabled)
    }

    private static func temporaryCaptureDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("TrailShotPrivacyPreferenceTests-\(UUID().uuidString)", isDirectory: true)
    }
}
