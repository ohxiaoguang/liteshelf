import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var store: LibraryStore
    @Environment(\.openSettings) private var openSettings
    var body: some View {
        VStack(spacing: 0) {
            if !store.loaded {
                Spacer()
            } else if store.snapshot.folders.isEmpty {
                ContentUnavailableView {
                    Label(L10n.text("empty.title"), systemImage: "square.grid.2x2")
                } description: {
                    Text(L10n.text("empty.description"))
                } actions: {
                    Button(L10n.text("folder.add")) { store.addFolder() }
                        .disabled(store.busy)
                }
            } else if store.games.isEmpty {
                ContentUnavailableView {
                    Label(L10n.text(store.query.isEmpty ? "empty.games" : "empty.search"),
                          systemImage: store.query.isEmpty ? "gamecontroller" : "magnifyingglass")
                } description: {
                    Text(L10n.text(store.query.isEmpty ? "empty.games.description" : "empty.search.description"))
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 124, maximum: 160), spacing: 24)], spacing: 24) {
                        ForEach(store.games) { game in GameGridItem(game: game) }
                    }
                    .padding(28)
                }
            }
            Spacer(minLength: 0)
            Divider()
            HStack {
                Text(L10n.format(store.count == 1 ? "library.count.one" : "library.count", store.count))
                Spacer()
                if store.busy {
                    ProgressView().controlSize(.small)
                    Text(L10n.text("library.refreshing"))
                } else if store.snapshot.folders.contains(where: { $0.status != .available }) {
                    Label(L10n.text("library.offline"), systemImage: "externaldrive.badge.exclamationmark")
                } else if !store.snapshot.folders.isEmpty {
                    Label(L10n.text("library.ready"), systemImage: "externaldrive")
                }
            }
            .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 18).padding(.vertical, 10)
        }
        .frame(minWidth: 540, minHeight: 380)
        .searchable(text: $store.query, placement: .toolbar, prompt: Text(L10n.text("search.placeholder")))
        .toolbar {
            ToolbarItemGroup {
                Button { Task { await store.refresh() } } label: {
                    Label(L10n.text("library.refresh"), systemImage: "arrow.clockwise")
                }
                .disabled(store.busy || !store.loaded).help(L10n.text("library.refresh"))
                Button { openSettings() } label: {
                    Label(L10n.text("settings.title"), systemImage: "gearshape")
                }.help(L10n.text("settings.title"))
            }
        }
        .task { await store.start() }
        .alert(L10n.text("app.name"), isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) {
            Button(L10n.text("common.ok"), role: .cancel) { store.message = nil }
        } message: { Text(store.message ?? "") }
        .sheet(item: $store.selectedGame) { game in GameInfoView(game: game) }
    }
}
