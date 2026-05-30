@testable import TrailShot
import XCTest

final class UpdateCheckServiceTests: XCTestCase {
    func testUpdateInfoFindsNewerDmgRelease() throws {
        let release = try UpdateCheckService.decodeRelease(from: Data("""
        {
          "tag_name": "v0.2.0",
          "name": "TrailShot 0.2.0",
          "html_url": "https://github.com/jonathan-arteaga/trail-shot-app/releases/tag/v0.2.0",
          "assets": [
            {
              "name": "TrailShot.dmg",
              "content_type": "application/x-apple-diskimage",
              "browser_download_url": "https://github.com/jonathan-arteaga/trail-shot-app/releases/download/v0.2.0/TrailShot.dmg"
            }
          ]
        }
        """.utf8))

        let info = try UpdateCheckService.updateInfo(currentVersion: "0.1.0", release: release)

        XCTAssertEqual(info.currentVersion, "0.1.0")
        XCTAssertEqual(info.latestVersion, "0.2.0")
        XCTAssertEqual(info.releaseName, "TrailShot 0.2.0")
        XCTAssertTrue(info.isNewerAvailable)
        XCTAssertEqual(info.downloadURL?.lastPathComponent, "TrailShot.dmg")
    }

    func testVersionComparisonHandlesCommonReleaseTags() {
        XCTAssertTrue(AppVersion("v0.10.0")! > AppVersion("0.9.9")!)
        XCTAssertEqual(AppVersion("0.1"), AppVersion("0.1.0"))
        XCTAssertEqual(AppVersion("V1.2.3-internal"), AppVersion("1.2.3"))
        XCTAssertNil(AppVersion("release-candidate"))
    }

    func testUpdateInfoRejectsNonVersionReleaseTags() throws {
        let release = GitHubRelease(
            tagName: "release-candidate",
            name: nil,
            htmlURL: nil,
            assets: []
        )

        XCTAssertThrowsError(try UpdateCheckService.updateInfo(currentVersion: "0.1.0", release: release)) { error in
            XCTAssertEqual(error.localizedDescription, "Could not compare TrailShot version release-candidate.")
        }
    }

    func testInjectedFetcherUsesGitHubHeaders() async throws {
        let service = UpdateCheckService(
            latestReleaseURL: URL(string: "https://api.github.com/repos/example/trailshot/releases/latest")!
        ) { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "User-Agent"), "TrailShot")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/vnd.github+json")

            let data = Data("""
            {
              "tag_name": "v0.1.0",
              "html_url": "https://github.com/example/trailshot/releases/tag/v0.1.0",
              "assets": []
            }
            """.utf8)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (data, response)
        }

        let info = try await service.checkForUpdates(currentVersion: "0.1.0")

        XCTAssertFalse(info.isNewerAvailable)
        XCTAssertEqual(info.latestVersion, "0.1.0")
    }

    func testFailedGitHubResponseIsReadable() async {
        let service = UpdateCheckService(
            latestReleaseURL: URL(string: "https://api.github.com/repos/example/trailshot/releases/latest")!
        ) { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 404,
                httpVersion: nil,
                headerFields: nil
            )!
            return (Data(), response)
        }

        do {
            _ = try await service.checkForUpdates(currentVersion: "0.1.0")
            XCTFail("Expected update check to throw.")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Could not check GitHub Releases. GitHub returned 404.")
        }
    }
}
