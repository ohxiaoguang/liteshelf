import XCTest
@testable import LiteShelf

final class LibraryTests: XCTestCase {
    var temporary: URL!
    override func setUpWithError() throws {
        temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: temporary) }

    private func app(_ relative: String, display: String? = nil, name: String? = nil) throws -> URL {
        let url = temporary.appendingPathComponent(relative)
        try FileManager.default.createDirectory(at: url.appendingPathComponent("Contents"), withIntermediateDirectories: true)
        var info = ["CFBundleIdentifier": "test." + UUID().uuidString,
                    "CFBundlePackageType": "APPL", "CFBundleShortVersionString": "1.2.3"]
        info["CFBundleDisplayName"] = display
        info["CFBundleName"] = name
        let data = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        try data.write(to: url.appendingPathComponent("Contents/Info.plist"))
        return url
    }

    func testScanHonorsBoundariesAndNamePriority() async throws {
        let root = temporary.appendingPathComponent("Games")
        _ = try app("Games/Display.app", display: "Display Title", name: "Internal Name")
        _ = try app("Games/Nested/Named.app", name: "Bundle Name")
        _ = try app("Games/Filename.app")
        _ = try app("Games/Display.app/Contents/Hidden.app")
        _ = try app("Outside/NotSelected.app")
        _ = try app("Games/.hidden/Secret.app")
        let outside = temporary.appendingPathComponent("Outside")
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("Link"), withDestinationURL: outside)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Ignore.exe"), withIntermediateDirectories: true)
        let worker = LibraryWorker(directory: temporary.appendingPathComponent("Cache"))
        let folder = try await worker.makeFolder(root)
        let result = await worker.scan(LibrarySnapshot(folders: [folder]))
        XCTAssertFalse(result.hadFailures)
        XCTAssertEqual(Set(result.snapshot.games.map(\.name)), ["Display Title", "Bundle Name", "Filename"])
        XCTAssertTrue(result.snapshot.games.allSatisfy(\.available))
        XCTAssertTrue(result.snapshot.games.contains { $0.version == "1.2.3" && $0.bundleIdentifier != nil })
        for game in result.snapshot.games { let data = await worker.iconData(game); XCTAssertNotNil(data) }
    }

    func testOfflineRecordsPersistAndReconnectKeepsIdentity() async throws {
        let gameURL = try app("Games/Example.app")
        let root = gameURL.deletingLastPathComponent()
        let worker = LibraryWorker(directory: temporary.appendingPathComponent("Cache"))
        let folder = try await worker.makeFolder(root)
        let first = await worker.scan(LibrarySnapshot(folders: [folder]))
        let game = try XCTUnwrap(first.snapshot.games.first)
        try await worker.save(first.snapshot)
        let cached = try await worker.load()
        XCTAssertEqual(cached.games.first?.id, game.id)
        XCTAssertEqual(cached.games.first?.available, false)
        var offline = first.snapshot
        offline.folders[0].volumeUUID = "a-different-volume"
        let disconnected = await worker.scan(offline)
        XCTAssertEqual(disconnected.snapshot.games.first?.id, game.id)
        XCTAssertEqual(disconnected.snapshot.games.first?.available, false)
        let icon = await worker.iconData(game)
        XCTAssertNotNil(icon)
        var reconnected = disconnected.snapshot
        reconnected.folders[0] = folder
        let restored = await worker.scan(reconnected)
        XCTAssertEqual(restored.snapshot.games.first?.id, game.id)
        XCTAssertEqual(restored.snapshot.games.first?.available, true)
    }

    func testSuccessfulRefreshRemovesDeletedGameAndOrphanIcon() async throws {
        let url = try app("Games/Removed.app")
        let worker = LibraryWorker(directory: temporary.appendingPathComponent("Cache"))
        let folder = try await worker.makeFolder(url.deletingLastPathComponent())
        let first = await worker.scan(LibrarySnapshot(folders: [folder]))
        let game = try XCTUnwrap(first.snapshot.games.first)
        try await worker.save(first.snapshot)
        try FileManager.default.removeItem(at: url)
        let refreshed = await worker.scan(first.snapshot)
        XCTAssertTrue(refreshed.snapshot.games.isEmpty)
        try await worker.save(refreshed.snapshot)
        let data = await worker.iconData(game)
        XCTAssertNil(data)
    }

    func testCorruptCacheThrowsAndIsNotOverwritten() async throws {
        let worker = LibraryWorker(directory: temporary)
        let file = temporary.appendingPathComponent("Library.json")
        let invalid = Data("invalid json".utf8)
        try invalid.write(to: file)
        do { _ = try await worker.load(); XCTFail("Expected a corrupt cache error") } catch { }
        XCTAssertEqual(try Data(contentsOf: file), invalid)
    }

    func testLanguagePreferenceOrderAndFallback() {
        XCTAssertEqual(L10n.language(for: ["zh-Hant-TW", "en"]), "zh-Hans")
        XCTAssertEqual(L10n.language(for: ["en-GB", "zh-Hans"]), "en")
        XCTAssertEqual(L10n.language(for: ["fr-FR", "zh-HK", "en-US"]), "zh-Hans")
        XCTAssertEqual(L10n.language(for: ["ja-JP", "de"]), "en")
    }

    func testCompiledEnglishAndChineseResources() throws {
        for (language, expected) in [("en", "Done"), ("zh-Hans", "完成")] {
            let path = try XCTUnwrap(Bundle.main.path(forResource: language, ofType: "lproj"))
            let bundle = try XCTUnwrap(Bundle(path: path))
            XCTAssertEqual(bundle.localizedString(forKey: "common.done", value: nil, table: nil), expected)
            XCTAssertNotEqual(bundle.localizedString(forKey: "error.offline", value: nil, table: nil), "error.offline")
        }
    }

    @MainActor
    func testSearchAndOverlappingFolderDeduplication() async throws {
        let url = try app("Games/Nested/Puzzle.app", display: "Puzzle World")
        let worker = LibraryWorker(directory: temporary.appendingPathComponent("Cache"))
        let parent = try await worker.makeFolder(temporary.appendingPathComponent("Games"))
        let child = try await worker.makeFolder(url.deletingLastPathComponent())
        let result = await worker.scan(LibrarySnapshot(folders: [parent, child]))
        try await worker.save(result.snapshot)
        let store = LibraryStore(worker: worker)
        await store.start()
        XCTAssertEqual(store.games.count, 1)
        store.query = "pUzZle"
        XCTAssertEqual(store.games.count, 1)
        store.query = "missing"
        XCTAssertTrue(store.games.isEmpty)
        await store.removeFolder(parent)
        store.query = ""
        XCTAssertEqual(store.games.count, 1)
    }
}
