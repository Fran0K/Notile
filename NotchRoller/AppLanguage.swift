import SwiftUI

enum AppLanguage: String, CaseIterable, Codable {
    case system
    case en
    case zhHans = "zh-Hans"
    case fr
    case ja

    var displayName: String {
        switch self {
        case .system:  return String(localized: "settings.general.systemDefault")
        case .en:      return "English"
        case .zhHans:  return "简体中文"
        case .fr:      return "Français"
        case .ja:      return "日本語"
        }
    }

    var locale: Locale {
        switch self {
        case .system:  return Locale.current
        case .en:      return Locale(identifier: "en")
        case .zhHans:  return Locale(identifier: "zh-Hans")
        case .fr:      return Locale(identifier: "fr")
        case .ja:      return Locale(identifier: "ja")
        }
    }
}
