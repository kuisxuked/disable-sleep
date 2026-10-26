import Foundation

enum AppLanguage: String, Sendable {
    case chinese = "zh"
    case english = "en"

    static var systemDefault: AppLanguage {
        Locale.preferredLanguages.first?.hasPrefix("zh") == true ? .chinese : .english
    }

    static var current: AppLanguage {
        UserDefaults.standard.string(forKey: "DisableSleep.language").flatMap(Self.init(rawValue:)) ?? systemDefault
    }

    func text(_ chinese: String, _ english: String) -> String {
        self == .chinese ? chinese : english
    }
}
