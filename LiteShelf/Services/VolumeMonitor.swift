import AppKit

// Immutable tokens can be released on any executor; NotificationCenter removal is thread-safe.
private final class NotificationObservers: @unchecked Sendable {
    let tokens: [NSObjectProtocol]
    init(_ tokens: [NSObjectProtocol]) { self.tokens = tokens }
    deinit { for token in tokens { NSWorkspace.shared.notificationCenter.removeObserver(token) } }
}

@MainActor
final class VolumeMonitor {
    private let observers: NotificationObservers
    init(onChange: @escaping @MainActor @Sendable () -> Void) {
        let tokens = [NSWorkspace.didMountNotification, NSWorkspace.didUnmountNotification, NSWorkspace.didRenameVolumeNotification].map { name in
            NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { _ in
                Task { @MainActor in onChange() }
            }
        }
        observers = NotificationObservers(tokens)
    }
}
