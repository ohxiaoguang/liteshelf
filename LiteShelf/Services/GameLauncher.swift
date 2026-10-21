import AppKit

@MainActor
enum GameLauncher {
    enum Action { case launch, reveal }
    static func perform(_ action: Action, game: Game, folder: GameFolder, worker: LibraryWorker) async throws {
        let (root, _) = try await worker.resolve(folder)
        let accessed = root.startAccessingSecurityScopedResource()
        defer { if accessed { root.stopAccessingSecurityScopedResource() } }
        let url = root.appendingPathComponent(game.relativePath).standardizedFileURL
        guard url.path.hasPrefix(root.standardizedFileURL.path + "/"), url.pathExtension.lowercased() == "app" else {
            throw LibraryError.invalidApplication
        }
        switch action {
        case .launch:
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
        case .reveal:
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }
}
