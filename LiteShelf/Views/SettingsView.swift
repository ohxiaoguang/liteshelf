import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: LibraryStore
    @State private var removing: GameFolder?
    var body: some View {
        Form {
            Section {
                if store.snapshot.folders.isEmpty { Text(L10n.text("settings.noFolders")).foregroundStyle(.secondary) }
                ForEach(store.snapshot.folders) { folder in
                    VStack(alignment: .leading, spacing: 8) {
                        Label(folder.volumeName, systemImage: "folder")
                        Text(folder.path).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                        HStack {
                            Text(folder.status.label).font(.caption)
                            Spacer()
                            Button(L10n.text("folder.reauthorize")) { store.addFolder(replacing: folder.id) }
                            Button(L10n.text("folder.remove"), role: .destructive) { removing = folder }
                        }
                    }.padding(.vertical, 6)
                }
                Button(L10n.text("folder.add")) { store.addFolder() }
            } header: { Text(L10n.text("settings.folders")) }
            footer: { Text(L10n.text("settings.explanation")) }
            Section {
                Text(L10n.text("settings.language"))
                Text(L10n.text("settings.privacy"))
            }
        }
        .formStyle(.grouped).padding(8).frame(width: 570, height: 450)
        .disabled(store.busy || !store.loaded)
        .confirmationDialog(L10n.text("folder.remove.title"), isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } })) {
            Button(L10n.text("folder.remove"), role: .destructive) {
                if let folder = removing { Task { await store.removeFolder(folder) } }
                removing = nil
            }
        } message: { Text(L10n.text("folder.remove.description")) }
    }
}
