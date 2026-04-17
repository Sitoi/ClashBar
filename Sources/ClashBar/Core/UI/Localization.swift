import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case zhHans = "zh-Hans"
    case en

    var id: String {
        rawValue
    }

    var localeIdentifier: String {
        switch self {
        case .zhHans:
            "zh_Hans_CN"
        case .en:
            "en_US_POSIX"
        }
    }
}

enum L10n {
    private static let localeCacheKeyPrefix = "clashbar.localization.locale."

    static func t(_ key: String, language: AppLanguage, _ args: CVarArg...) -> String {
        self.t(key, language: language, args: args)
    }

    static func t(_ key: String, language: AppLanguage, args: [CVarArg]) -> String {
        let format = self.localizedString(for: key, language: language)
        guard !args.isEmpty else { return format }
        return String(format: format, locale: self.locale(for: language), arguments: args)
    }

    private static func localizedString(for key: String, language: AppLanguage) -> String {
        for bundle in AppResourceBundleLocator.candidateBundles() {
            if let value = self.localizedString(in: bundle, key: key, language: language) {
                return value
            }
        }

        if language != .zhHans {
            for bundle in AppResourceBundleLocator.candidateBundles() {
                if let fallbackValue = self.localizedString(in: bundle, key: key, language: .zhHans) {
                    return fallbackValue
                }
            }
        }

        return key
    }

    private static func localizedString(in bundle: Bundle, key: String, language: AppLanguage) -> String? {
        guard let localizedBundle = self.localizationBundle(in: bundle, language: language) else {
            return nil
        }

        let value = localizedBundle.localizedString(forKey: key, value: key, table: nil)
        return value == key ? nil : value
    }

    private static func localizationBundle(in bundle: Bundle, language: AppLanguage) -> Bundle? {
        let candidateLocalizationNames = self.localizationNames(in: bundle, for: language)
        let candidatePaths: [String?] = candidateLocalizationNames.flatMap { localizationName in
            [
                bundle.path(forResource: localizationName, ofType: "lproj"),
                bundle.path(forResource: localizationName, ofType: "lproj", inDirectory: "Localization"),
                bundle.resourceURL?
                    .appendingPathComponent("Localization", isDirectory: true)
                    .appendingPathComponent("\(localizationName).lproj", isDirectory: true)
                    .path,
            ]
        }

        for path in candidatePaths.compactMap(\.self) {
            if let localizedBundle = Bundle(path: path) {
                return localizedBundle
            }
        }

        return nil
    }

    private static func localizationNames(in bundle: Bundle, for language: AppLanguage) -> [String] {
        let requestedName = language.rawValue
        let normalizedRequestedName = self.normalizedLocalizationName(requestedName)

        var names: [String] = [requestedName]
        for localization in bundle.localizations where
            self.normalizedLocalizationName(localization) == normalizedRequestedName
        {
            names.append(localization)
        }

        var seen = Set<String>()
        return names.filter { seen.insert($0).inserted }
    }

    private static func normalizedLocalizationName(_ name: String) -> String {
        name
            .replacingOccurrences(of: "_", with: "-")
            .lowercased()
    }

    private static func locale(for language: AppLanguage) -> Locale {
        let key = self.localeCacheKeyPrefix + language.rawValue
        let threadStorage = Thread.current.threadDictionary
        if let cached = threadStorage[key] as? Locale {
            return cached
        }
        let locale = Locale(identifier: language.localeIdentifier)
        threadStorage[key] = locale
        return locale
    }
}
