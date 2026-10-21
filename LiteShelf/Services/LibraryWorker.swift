import AppKit

struct ScanResult: Sendable {
    var snapshot: LibrarySnapshot
    var hadFailures: Bool
}

enum LibraryError: Error { case invalidCache, missingFolder, inaccessible, invalidApplication }

/// All filesystem traversal, bookmark resolution, icon conversion and persistence stays off the main actor.
actor LibraryWorker {
    let directory: URL
    private let fileManager = FileManager.default
    var iconsDirectory: URL { directory.appendingPathComponent("Icons", isDirectory: true) }
    private var libraryFile: URL { directory.appendingPathComponent("Library.json") }

    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LiteShelf", isDirectory: true)
    }

    func load() throws -> LibrarySnapshot {
        guard fileManager.fileExists(atPath: libraryFile.path) else { return LibrarySnapshot() }
        let snapshot = try JSONDecoder().decode(LibrarySnapshot.self, from: Data(contentsOf: libraryFile))
        guard snapshot.schemaVersion == 1 else { throw LibraryError.invalidCache }
        // Cached presence is never trusted across launches.
        var result = snapshot
        for index in result.games.indices { result.games[index].available = false }
        for index in result.folders.indices { result.folders[index].status = .offline }
        return result
    }

    func save(_ snapshot: LibrarySnapshot) throws {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(snapshot).write(to: libraryFile, options: .atomic)
        // Prune only after an atomic successful library write.
        let retained = Set(snapshot.games.map(\.iconFile))
        if let icons = try? fileManager.contentsOfDirectory(at: iconsDirectory, includingPropertiesForKeys: nil) {
            for icon in icons where icon.pathExtension == "png" && !retained.contains(icon.lastPathComponent) {
                try? fileManager.removeItem(at: icon)
            }
        }
    }

    func makeFolder(_ url: URL) throws -> GameFolder {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey, .volumeNameKey, .volumeUUIDStringKey])
        guard values.isDirectory == true, values.isPackage != true else { throw LibraryError.inaccessible }
        return GameFolder(path: url.standardizedFileURL.path,
                          bookmark: try url.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                                                         includingResourceValuesForKeys: nil, relativeTo: nil),
                          volumeName: values.volumeName ?? url.lastPathComponent,
                          volumeUUID: values.volumeUUIDString)
    }

    /// Resolve without mounting disks or displaying UI. Never probe another volume at a reused mount path.
    func resolve(_ folder: GameFolder) throws -> (URL, Data) {
        var stale = false
        let url = try URL(resolvingBookmarkData: folder.bookmark,
                          options: [.withSecurityScope, .withoutUI, .withoutMounting],
                          relativeTo: nil, bookmarkDataIsStale: &stale)
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        let values = try url.resourceValues(forKeys: [.volumeUUIDStringKey, .isDirectoryKey])
        guard values.isDirectory == true else { throw LibraryError.missingFolder }
        if let expected = folder.volumeUUID, values.volumeUUIDString != expected { throw LibraryError.missingFolder }
        let bookmark = stale ? try url.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                                                    includingResourceValuesForKeys: nil, relativeTo: nil) : folder.bookmark
        return (url, bookmark)
    }

    func scan(_ input: LibrarySnapshot) -> ScanResult {
        var output = input
        var failed = false
        for index in output.folders.indices {
            var folder = output.folders[index]
            let previous = input.games.filter { $0.folderID == folder.id }
            var records = previous.map { var copy = $0; copy.available = false; return copy }
            do {
                let (url, bookmark) = try resolve(folder)
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                folder.path = url.path
                folder.bookmark = bookmark
                var complete = true
                let found = discover(in: url) { complete = false }
                var discovered: [Game] = []
                for app in found {
                    let relative = String(app.path.dropFirst(url.path.hasSuffix("/") ? url.path.count : url.path.count + 1))
                    var game = previous.first { $0.relativePath == relative }
                        ?? Game(folderID: folder.id, relativePath: relative, name: app.deletingPathExtension().lastPathComponent)
                    if let bundle = Bundle(url: app) {
                        game.name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String).flatMap { $0.isEmpty ? nil : $0 }
                            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String).flatMap { $0.isEmpty ? nil : $0 }
                            ?? app.deletingPathExtension().lastPathComponent
                        game.bundleIdentifier = bundle.bundleIdentifier
                        game.version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
                            ?? bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
                    }
                    game.available = true
                    cacheIcon(for: app, game: game)
                    discovered.append(game)
                }
                if complete { records = discovered } else {
                    let paths = Set(discovered.map(\.relativePath))
                    records.removeAll { paths.contains($0.relativePath) }
                    records += discovered
                    failed = true
                }
                folder.status = complete ? .available : .scanFailed
            } catch {
                let nsError = error as NSError
                folder.status = nsError.domain == NSCocoaErrorDomain &&
                    [NSFileReadNoPermissionError, NSFileReadCorruptFileError].contains(nsError.code) ? .needsPermission : .offline
            }
            output.folders[index] = folder
            output.games.removeAll { $0.folderID == folder.id }
            output.games += records
        }
        return ScanResult(snapshot: output, hadFailures: failed)
    }

    /// No symlink traversal, hidden folders, or package contents. No URL outside the chosen root is visited.
    func discover(in root: URL, onError: () -> Void) -> [URL] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey, .isPackageKey]
        var found: [URL] = []
        var pending = [root]
        while let directory = pending.popLast() {
            do {
                let children = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: keys,
                                                                   options: [.skipsHiddenFiles])
                for child in children {
                    do {
                        let values = try child.resourceValues(forKeys: Set(keys))
                        guard values.isSymbolicLink != true, values.isDirectory == true else { continue }
                        if child.pathExtension.lowercased() == "app" { found.append(child) }
                        else if values.isPackage != true { pending.append(child) }
                    } catch { onError() }
                }
            } catch { onError() }
        }
        return found.sorted { $0.path < $1.path }
    }

    private func cacheIcon(for url: URL, game: Game) {
        let target = iconsDirectory.appendingPathComponent(game.iconFile)
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        var rect = CGRect(x: 0, y: 0, width: 128, height: 128)
        guard let source = icon.cgImage(forProposedRect: &rect, context: nil, hints: nil),
              let context = CGContext(data: nil, width: 128, height: 128, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return }
        context.interpolationQuality = .high
        context.draw(source, in: rect)
        guard let image = context.makeImage(),
              let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { return }
        do {
            try fileManager.createDirectory(at: iconsDirectory, withIntermediateDirectories: true)
            if (try? Data(contentsOf: target)) != png { try png.write(to: target, options: .atomic) }
        } catch { /* An icon is optional; library persistence errors are surfaced separately. */ }
    }

    func iconData(_ game: Game) -> Data? { try? Data(contentsOf: iconsDirectory.appendingPathComponent(game.iconFile)) }
}
