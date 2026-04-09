import Foundation

struct AppReleaseInfo: Decodable, Equatable {
    let tagName: String
    let name: String?
    let releaseURL: URL
    let isDraft: Bool
    let isPrerelease: Bool

    private enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case releaseURL = "html_url"
        case isDraft = "draft"
        case isPrerelease = "prerelease"
    }

    var displayVersion: String {
        AppSemanticVersion.normalizedDisplayVersion(from: self.tagName)
    }
}

struct AppSemanticVersion: Comparable, Equatable {
    private let components: [Int]

    init?(_ rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let withoutBuildMetadata = trimmed.split(separator: "+", maxSplits: 1).first.map(String.init) ?? trimmed
        let withoutPrerelease = withoutBuildMetadata.split(separator: "-", maxSplits: 1).first.map(String.init)
            ?? withoutBuildMetadata
        guard let firstDigitIndex = withoutPrerelease.firstIndex(where: \.isNumber) else {
            return nil
        }

        let numericPortion = withoutPrerelease[firstDigitIndex...]
        let parsedComponents = numericPortion.split(separator: ".").compactMap { segment -> Int? in
            let digits = segment.prefix(while: \.isNumber)
            guard !digits.isEmpty else { return nil }
            return Int(digits)
        }

        guard !parsedComponents.isEmpty else { return nil }
        self.components = parsedComponents
    }

    var displayString: String {
        self.components.map(String.init).joined(separator: ".")
    }

    static func < (lhs: AppSemanticVersion, rhs: AppSemanticVersion) -> Bool {
        let maxCount = max(lhs.components.count, rhs.components.count)

        for index in 0..<maxCount {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right {
                return left < right
            }
        }

        return false
    }

    static func normalizedDisplayVersion(from rawValue: String) -> String {
        if let version = Self(rawValue) {
            return version.displayString
        }

        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("v"), trimmed.dropFirst().first?.isNumber == true {
            return String(trimmed.dropFirst())
        }
        return trimmed
    }

    static func isNewerRelease(tagName: String, than currentVersion: String) -> Bool {
        guard let releaseVersion = Self(tagName), let currentVersion = Self(currentVersion) else {
            let normalizedRelease = Self.normalizedDisplayVersion(from: tagName)
            let normalizedCurrent = Self.normalizedDisplayVersion(from: currentVersion)
            return normalizedRelease.compare(normalizedCurrent, options: .numeric) == .orderedDescending
        }

        return releaseVersion > currentVersion
    }
}
