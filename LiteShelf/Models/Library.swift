import Foundation

struct GameFolder: Codable, Identifiable, Sendable {
    var id = UUID()
    var path: String
    var bookmark: Data
    var volumeName: String
    var volumeUUID: String?
    var status: FolderStatus = .offline
}

enum FolderStatus: String, Codable, Sendable {
    case available, offline, needsPermission, scanFailed
    var label: String { L10n.text("folder.\(rawValue)") }
}

struct Game: Codable, Identifiable, Sendable {
    var id = UUID()
    var folderID: UUID
    var relativePath: String
    var name: String
    var bundleIdentifier: String?
    var version: String?
    var available = false
    var iconFile: String { "\(id.uuidString).png" }
    func url(in folder: GameFolder) -> URL {
        URL(fileURLWithPath: folder.path, isDirectory: true).appendingPathComponent(relativePath)
    }
}

struct LibrarySnapshot: Codable, Sendable {
    var schemaVersion = 1
    var folders: [GameFolder] = []
    var games: [Game] = []
}

enum L10n {
    // Bundle localization respects per-app AppleLanguages. Map every Chinese variant to Simplified Chinese.
    static func language(for preferences: [String]) -> String {
        for preference in preferences {
            let language = preference.replacingOccurrences(of: "_", with: "-").lowercased()
            if language == "zh" || language.hasPrefix("zh-") { return "zh-Hans" }
            if language == "en" || language.hasPrefix("en-") { return "en" }
        }
        return "en"
    }
    static var bundle: Bundle {
        let preferences = UserDefaults.standard.stringArray(forKey: "AppleLanguages") ?? Locale.preferredLanguages
        let code = language(for: preferences)
        guard let path = Bundle.main.path(forResource: code, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return .main }
        return bundle
    }
    static func text(_ key: String) -> String { bundle.localizedString(forKey: key, value: nil, table: nil) }
    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: Locale.current, arguments: arguments)
    }
}
