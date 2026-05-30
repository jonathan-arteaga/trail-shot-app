import Foundation

struct AppUpdateInfo: Equatable {
    let currentVersion: String
    let latestVersion: String
    let releaseName: String
    let releaseURL: URL
    let downloadURL: URL?

    var isNewerAvailable: Bool {
        guard
            let current = AppVersion(currentVersion),
            let latest = AppVersion(latestVersion)
        else {
            return false
        }

        return latest > current
    }
}

enum UpdateCheckState: Equatable {
    case idle
    case checking
    case upToDate(AppUpdateInfo)
    case updateAvailable(AppUpdateInfo)
    case failed(String)

    var isChecking: Bool {
        self == .checking
    }

    var message: String? {
        switch self {
        case .idle:
            nil
        case .checking:
            "Checking GitHub Releases..."
        case .upToDate(let info):
            "TrailShot is up to date at \(info.currentVersion)."
        case .updateAvailable(let info):
            "TrailShot \(info.latestVersion) is available."
        case .failed(let message):
            message
        }
    }
}

struct UpdateCheckService {
    let latestReleaseURL: URL
    var fetchData: @Sendable (URLRequest) async throws -> (Data, URLResponse)

    init(
        latestReleaseURL: URL = AppBuildInfo.latestReleaseAPIURL,
        fetchData: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse) = { request in
            try await URLSession.shared.data(for: request)
        }
    ) {
        self.latestReleaseURL = latestReleaseURL
        self.fetchData = fetchData
    }

    func checkForUpdates(currentVersion: String) async throws -> AppUpdateInfo {
        var request = URLRequest(url: latestReleaseURL)
        request.setValue("TrailShot", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await fetchData(request)
        if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
            throw UpdateCheckError.invalidResponse(statusCode: httpResponse.statusCode)
        }

        let release = try Self.decodeRelease(from: data)
        return try Self.updateInfo(currentVersion: currentVersion, release: release)
    }

    static func decodeRelease(from data: Data) throws -> GitHubRelease {
        let decoder = JSONDecoder()
        return try decoder.decode(GitHubRelease.self, from: data)
    }

    static func updateInfo(currentVersion: String, release: GitHubRelease) throws -> AppUpdateInfo {
        guard !release.tagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw UpdateCheckError.missingVersion
        }

        guard AppVersion(currentVersion) != nil else {
            throw UpdateCheckError.invalidVersion(currentVersion)
        }

        let latestVersion = AppVersion.displayString(from: release.tagName)
        guard AppVersion(latestVersion) != nil else {
            throw UpdateCheckError.invalidVersion(release.tagName)
        }

        let releaseURL = release.htmlURL ?? AppBuildInfo.releasesURL
        let releaseName = release.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayReleaseName: String
        if let releaseName, !releaseName.isEmpty {
            displayReleaseName = releaseName
        } else {
            displayReleaseName = release.tagName
        }
        let dmgAsset = release.assets.first { asset in
            asset.name.lowercased().hasSuffix(".dmg") ||
                asset.contentType?.lowercased() == "application/x-apple-diskimage"
        }

        return AppUpdateInfo(
            currentVersion: currentVersion,
            latestVersion: latestVersion,
            releaseName: displayReleaseName,
            releaseURL: releaseURL,
            downloadURL: dmgAsset?.browserDownloadURL
        )
    }
}

struct GitHubRelease: Decodable, Equatable {
    let tagName: String
    let name: String?
    let htmlURL: URL?
    let assets: [GitHubReleaseAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case htmlURL = "html_url"
        case assets
    }
}

struct GitHubReleaseAsset: Decodable, Equatable {
    let name: String
    let contentType: String?
    let browserDownloadURL: URL

    enum CodingKeys: String, CodingKey {
        case name
        case contentType = "content_type"
        case browserDownloadURL = "browser_download_url"
    }
}

enum UpdateCheckError: LocalizedError, Equatable {
    case invalidResponse(statusCode: Int)
    case missingVersion
    case invalidVersion(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse(let statusCode):
            "Could not check GitHub Releases. GitHub returned \(statusCode)."
        case .missingVersion:
            "The latest GitHub Release did not include a version."
        case .invalidVersion(let version):
            "Could not compare TrailShot version \(version)."
        }
    }
}

struct AppVersion: Comparable, Equatable {
    private let components: [Int]

    init?(_ rawValue: String) {
        let trimmed = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingPrefix("v")
            .trimmingPrefix("V")
        let numericPart = trimmed.split(separator: "-", maxSplits: 1).first.map(String.init) ?? trimmed
        let versionParts = numericPart.split(separator: ".")
        let parsedComponents = versionParts.compactMap { Int($0) }

        guard !parsedComponents.isEmpty, parsedComponents.count == versionParts.count else { return nil }
        components = parsedComponents
    }

    static func == (lhs: AppVersion, rhs: AppVersion) -> Bool {
        !(lhs < rhs) && !(rhs < lhs)
    }

    static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        for index in 0..<count {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right {
                return left < right
            }
        }

        return false
    }

    static func displayString(from rawValue: String) -> String {
        rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingPrefix("v")
            .trimmingPrefix("V")
    }
}

private extension String {
    func trimmingPrefix(_ prefix: String) -> String {
        hasPrefix(prefix) ? String(dropFirst(prefix.count)) : self
    }
}
