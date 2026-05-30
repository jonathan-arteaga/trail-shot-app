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

    @MainActor
    func testCaptureFlowPreferencesDefaultOnAndPersist() {
        let suiteName = "TrailShotTests.CaptureFlowPreferenceTests"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let store = CaptureStore(userDefaults: defaults, captureLibraryDirectory: Self.temporaryCaptureDirectory())
        XCTAssertTrue(store.isAutoCopyAfterCaptureEnabled)
        XCTAssertTrue(store.isQuickAccessAfterCaptureEnabled)

        store.setAutoCopyAfterCaptureEnabled(false)
        store.setQuickAccessAfterCaptureEnabled(false)

        let restoredStore = CaptureStore(userDefaults: defaults, captureLibraryDirectory: Self.temporaryCaptureDirectory())
        XCTAssertFalse(restoredStore.isAutoCopyAfterCaptureEnabled)
        XCTAssertFalse(restoredStore.isQuickAccessAfterCaptureEnabled)
    }

    @MainActor
    func testRetentionPreferenceDefaultsForeverAndPersists() {
        let suiteName = "TrailShotTests.RetentionPreferenceTests"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let store = CaptureStore(userDefaults: defaults, captureLibraryDirectory: Self.temporaryCaptureDirectory())
        XCTAssertEqual(store.captureRetentionPolicy, .forever)
        XCTAssertEqual(store.recordingRetentionPolicy, .forever)

        store.setCaptureRetentionPolicy(.thirtyDays)
        store.setRecordingRetentionPolicy(.sevenDays)

        let restoredStore = CaptureStore(userDefaults: defaults, captureLibraryDirectory: Self.temporaryCaptureDirectory())
        XCTAssertEqual(restoredStore.captureRetentionPolicy, .thirtyDays)
        XCTAssertEqual(restoredStore.recordingRetentionPolicy, .sevenDays)
    }

    private static func temporaryCaptureDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("TrailShotPrivacyPreferenceTests-\(UUID().uuidString)", isDirectory: true)
    }
}
