import Foundation
import LockoutCore

/// The App Group folder the app and both extensions share.
enum AppGroup {
    static let id = "group.fun.thedailygame.lockout"

    static var container: URL {
        // Without the App Group entitlement this is nil; falling back to the
        // target's own folder keeps the app running (the extensions would not
        // see the same file, which the on-device checks would catch).
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }
}

/// Reads and writes `AppState` as one JSON file, coordinated so the app and an
/// extension writing at the same moment cannot lose each other's change.
enum StateStore {
    static var url: URL { AppGroup.container.appendingPathComponent("state.json") }

    struct Unreadable: Error {}

    /// nil only when the file exists but cannot be opened right now.
    static func load() -> AppState? {
        var state: AppState?
        var error: NSError?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &error) { url in
            state = read(url)
        }
        return state
    }

    /// Read, change and write back in one coordinated step. Nothing is written
    /// if `body` throws or the file cannot be opened.
    @discardableResult
    static func update<T>(_ body: (inout AppState) throws -> T) throws -> T {
        var result: Result<T, Error> = .failure(Unreadable())
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forMerging, error: &coordinationError) { url in
            guard var state = read(url) else { return }
            result = Result { try body(&state) }
            if case .success = result { write(state, to: url) }
        }
        if let coordinationError { throw coordinationError }
        return try result.get()
    }

    /// No file yet, or a file that is not valid JSON, reads as an empty state,
    /// which means "unlocked": if the data is ever damaged, Lockout fails open,
    /// never shut. A file that exists but cannot be opened (which should not
    /// happen with no file protection, but is cheap to guard) returns nil so the
    /// caller does nothing rather than wiping saved schedules.
    private static func read(_ url: URL) -> AppState? {
        guard FileManager.default.fileExists(atPath: url.path) else { return AppState() }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return (try? JSONDecoder().decode(AppState.self, from: data)) ?? AppState()
    }

    private static func write(_ state: AppState, to url: URL) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        // No file protection: the monitor extension must be able to release a
        // lock even right after a restart, before the phone is first unlocked.
        try? data.write(to: url, options: [.atomic, .noFileProtection])
    }
}
