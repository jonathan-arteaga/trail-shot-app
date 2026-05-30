import Foundation

struct AppBuildInfo: Equatable {
    static let releasesURL = URL(string: "https://github.com/jonathan-arteaga/trail-shot-app/releases")!
    static let latestReleaseAPIURL = URL(string: "https://api.github.com/repos/jonathan-arteaga/trail-shot-app/releases/latest")!

    let name: String
    let version: String
    let buildNumber: String
    let commit: String
    let releaseChannel: String

    init(infoDictionary: [String: Any]) {
        name = infoDictionary["CFBundleDisplayName"] as? String
            ?? infoDictionary["CFBundleName"] as? String
            ?? "TrailShot"
        version = infoDictionary["CFBundleShortVersionString"] as? String ?? "0.1.0"
        buildNumber = infoDictionary["CFBundleVersion"] as? String ?? "0"
        commit = infoDictionary["TrailShotBuildCommit"] as? String ?? "unknown"
        releaseChannel = infoDictionary["TrailShotReleaseChannel"] as? String ?? "development"
    }

    static func current(bundle: Bundle = .main) -> AppBuildInfo {
        AppBuildInfo(infoDictionary: bundle.infoDictionary ?? [:])
    }

    var displayVersion: String {
        "\(version) (\(buildNumber))"
    }

    var releaseSummary: String {
        "\(releaseChannel.capitalized) - \(commit)"
    }
}
