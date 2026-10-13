import Foundation

enum AppResources {
    static let bundle: Bundle = {
        if let url = Bundle.main.url(forResource: "Mus_Mus", withExtension: "bundle"),
           let bundle = Bundle(url: url) { return bundle }
        return .module
    }()
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case system, chinese = "zh-Hans", english = "en"
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: return L10n.text("跟随系统")
        case .chinese: return "简体中文"
        case .english: return "English"
        }
    }
    var code: String {
        if self != .system { return rawValue }
        return Locale.preferredLanguages.first?.hasPrefix("zh") == true ? "zh-Hans" : "en"
    }
}

enum L10n {
    // Accessed on the main run loop, alongside the settings and event tap.
    static var language: AppLanguage = .system
    private static let bundles: [String: Bundle] = {
        Dictionary(uniqueKeysWithValues: ["en", "zh-Hans"].compactMap { code in
            guard let url = AppResources.bundle.url(forResource: code, withExtension: "lproj"),
                  let bundle = Bundle(url: url) else { return nil }
            return (code, bundle)
        })
    }()

    static func text(_ key: String) -> String {
        bundles[language.code]?.localizedString(forKey: key, value: key, table: nil) ?? key
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: Locale(identifier: language.code), arguments: arguments)
    }
}
