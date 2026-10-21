import SwiftUI
import AppKit

@MainActor
final class LibraryStore: ObservableObject {
    @Published private(set) var snapshot = LibrarySnapshot()
    @Published private(set) var busy = false
    @Published private(set) var loaded = false
    @Published var query = ""
    @Published var message: String?
    @Published var selectedGame: Game?
    let worker: LibraryWorker
    private var monitor: VolumeMonitor?
    private var refreshPending = false
    private var debounce: Task<Void, Never>?
    private var failedToLoad = false

    init(worker: LibraryWorker = LibraryWorker()) { self.worker = worker }

    var games: [Game] {
        var seen: Set<String> = []
        return snapshot.games.sorted {
            let order = $0.name.localizedStandardCompare($1.name)
            if order != .orderedSame { return order == .orderedAscending }
            if $0.available != $1.available { return $0.available }
            return $0.id.uuidString < $1.id.uuidString
        }.filter { game in
            guard let folder = snapshot.folders.first(where: { $0.id == game.folderID }) else { return false }
            let path = game.url(in: folder).standardizedFileURL.path
            return seen.insert(path).inserted && (query.isEmpty || game.name.localizedStandardContains(query))
        }
    }
    var count: Int {
        Set(snapshot.games.compactMap { game in
            snapshot.folders.first { $0.id == game.folderID }.map { game.url(in: $0).standardizedFileURL.path }
        }).count
    }

    func start() async {
        guard !loaded else { return }
        loaded = true
        busy = true
        do { snapshot = try await worker.load() }
        catch { failedToLoad = true; busy = false; message = L10n.text("error.load"); return }
        monitor = VolumeMonitor { [weak self] in
            guard let self else { return }
            // Invalidate cached availability immediately, then coalesce mount/unmount bursts.
            for i in self.snapshot.games.indices { self.snapshot.games[i].available = false }
            self.debounce?.cancel()
            self.debounce = Task {
                try? await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled else { return }
                await self.refresh()
            }
        }
        busy = false
        await refresh()
    }

    func refresh() async {
        guard !failedToLoad else { message = L10n.text("error.load"); return }
        guard !busy else { refreshPending = true; return }
        busy = true
        repeat {
            refreshPending = false
            let result = await worker.scan(snapshot)
            snapshot = result.snapshot
            await persist()
            if result.hadFailures { message = L10n.text("error.scan") }
        } while refreshPending
        busy = false
    }

    func addFolder(replacing folderID: UUID? = nil) {
        guard !busy, !failedToLoad else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = folderID == nil
        panel.message = L10n.text(folderID == nil ? "panel.message" : "panel.reauthorize")
        panel.prompt = L10n.text("folder.choose")
        panel.begin { [weak self] response in
            guard response == .OK, let self else { return }
            let urls = panel.urls
            Task { await self.add(urls, replacing: folderID) }
        }
    }

    private func add(_ urls: [URL], replacing folderID: UUID?) async {
        guard !busy else { return }
        busy = true
        for url in urls {
            do {
                var folder = try await worker.makeFolder(url)
                if let folderID, let index = snapshot.folders.firstIndex(where: { $0.id == folderID }) {
                    folder.id = folderID
                    snapshot.folders[index] = folder
                } else if !snapshot.folders.contains(where: { $0.path == folder.path }) {
                    snapshot.folders.append(folder)
                }
            } catch { message = L10n.text("error.folder") }
        }
        await persist()
        busy = false
        await refresh()
    }

    func removeFolder(_ folder: GameFolder) async {
        guard !busy else { return }
        busy = true
        snapshot.folders.removeAll { $0.id == folder.id }
        snapshot.games.removeAll { $0.folderID == folder.id }
        await persist()
        busy = false
    }

    private func persist() async {
        do { try await worker.save(snapshot) }
        catch { message = L10n.text("error.save") }
    }

    func perform(_ action: GameLauncher.Action, game: Game) {
        guard let folder = snapshot.folders.first(where: { $0.id == game.folderID }) else { return }
        guard game.available else { message = L10n.format("error.offline", folder.volumeName); return }
        Task {
            do { try await GameLauncher.perform(action, game: game, folder: folder, worker: worker) }
            catch {
                message = L10n.text(action == .launch ? "error.launch" : "error.reveal")
                await refresh()
            }
        }
    }
}
