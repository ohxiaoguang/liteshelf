import SwiftUI
import AppKit

/// Normalize language only for this process before AppKit builds its native menus.
/// This preserves the ordered per-app/system preferences without changing saved settings.
@main
@MainActor
enum LiteShelfEntryPoint {
    static func main() {
        let defaults = UserDefaults.standard
        let preferences = defaults.stringArray(forKey: "AppleLanguages") ?? Locale.preferredLanguages
        var arguments = defaults.volatileDomain(forName: UserDefaults.argumentDomain)
        arguments["AppleLanguages"] = [L10n.language(for: preferences)]
        defaults.setVolatileDomain(arguments, forName: UserDefaults.argumentDomain)
        LiteShelfApp.main()
    }
}

struct LiteShelfApp: App {
    @StateObject private var store = LibraryStore()
    var body: some Scene {
        WindowGroup(L10n.text("app.name")) {
            LibraryView().environmentObject(store)
        }
        .defaultSize(width: 820, height: 580)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button(L10n.text("menu.about")) {
                    NSApplication.shared.orderFrontStandardAboutPanel(options: [
                        .applicationName: L10n.text("app.name"),
                        .credits: NSAttributedString(string: L10n.text("about.description") + "\n\n" + L10n.text("about.copyright"))
                    ])
                }
            }
            CommandGroup(after: .newItem) {
                Button(L10n.text("folder.add")) { store.addFolder() }
                    .keyboardShortcut("o", modifiers: [.command, .shift]).disabled(store.busy)
                Button(L10n.text("library.refresh")) { Task { await store.refresh() } }
                    .keyboardShortcut("r").disabled(store.busy)
            }
        }
        Settings { SettingsView().environmentObject(store) }
    }
}
