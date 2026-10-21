import SwiftUI

struct GameIcon: View {
    let game: Game
    @EnvironmentObject private var store: LibraryStore
    @State private var icon: NSImage?
    var body: some View {
        Group {
            if let icon { Image(nsImage: icon).resizable().interpolation(.high) }
            else { Image(systemName: "app.dashed").resizable().scaledToFit().padding(12).foregroundStyle(.secondary) }
        }
        .frame(width: 80, height: 80)
        .task(id: "\(game.id)-\(game.available)") {
            if let data = await store.worker.iconData(game) { icon = NSImage(data: data) }
        }
        .accessibilityHidden(true)
    }
}

struct GameGridItem: View {
    let game: Game
    @EnvironmentObject private var store: LibraryStore
    @FocusState private var focused: Bool
    var body: some View {
        VStack(spacing: 8) {
            GameIcon(game: game).opacity(game.available ? 1 : 0.45)
            Text(game.name).font(.callout).multilineTextAlignment(.center).lineLimit(2).frame(height: 34, alignment: .top)
            Text(game.available ? "" : L10n.text("game.unavailable"))
                .font(.caption2).foregroundStyle(.secondary).frame(height: 14)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(focused ? Color.accentColor.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 12))
        .contentShape(Rectangle())
        .focusable().focused($focused)
        .onTapGesture(count: 2) { store.perform(.launch, game: game) }
        .onTapGesture { focused = true }
        .onKeyPress(.return) { store.perform(.launch, game: game); return .handled }
        .contextMenu {
            Button(L10n.text("game.launch")) { store.perform(.launch, game: game) }
            Button(L10n.text("game.reveal")) { store.perform(.reveal, game: game) }
            Divider()
            Button(L10n.text("game.info")) { store.selectedGame = game }
        }
        .help(L10n.text("game.hint"))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(game.name)
        .accessibilityValue(game.available ? L10n.text("game.available") : L10n.text("game.unavailable"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { store.perform(.launch, game: game) }
    }
}

struct GameInfoView: View {
    let game: Game
    @EnvironmentObject private var store: LibraryStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 18) {
            GameIcon(game: game)
            Text(game.name).font(.title2).textSelection(.enabled)
            Form {
                LabeledContent(L10n.text("info.identifier"), value: game.bundleIdentifier ?? L10n.text("info.unknown"))
                LabeledContent(L10n.text("info.version"), value: game.version ?? L10n.text("info.unknown"))
                LabeledContent(L10n.text("info.status"), value: L10n.text(game.available ? "game.available" : "game.unavailable"))
                if let folder = store.snapshot.folders.first(where: { $0.id == game.folderID }) {
                    LabeledContent(L10n.text("info.location")) {
                        Text(game.url(in: folder).path).multilineTextAlignment(.trailing).textSelection(.enabled)
                    }
                    LabeledContent(L10n.text("info.drive"), value: folder.volumeName)
                }
            }.formStyle(.grouped)
            Button(L10n.text("common.done")) { dismiss() }.keyboardShortcut(.defaultAction)
        }
        .padding(24).frame(width: 480)
    }
}
