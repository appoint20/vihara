import Foundation

/// The hand-off between the share extension and the app.
///
/// One JSON file in the App Group container. Not `UserDefaults`: a capture is the
/// traveller's content, it can be a few kilobytes of caption, and a defaults suite is
/// the wrong place for either.
///
/// **The App Group is a provisioning dependency, not just code.** Without
/// `group.com.vihara.app` registered on the App ID and enabled for both targets,
/// `containerURL(forSecurityApplicationGroupIdentifier:)` returns `nil` and every
/// capture is silently lost. So it does not return `nil` quietly — ``isAvailable``
/// exists so the extension can *say* it cannot save, which is the same lesson the
/// README records about Sign in with Apple: a capability wired in code before it is
/// wired in the portal fails in a way that looks like a bug in the feature.
struct SharedInbox: Sendable {
    static let appGroupIdentifier = "group.com.vihara.app"

    private let containerURL: URL?

    init(appGroupIdentifier: String = SharedInbox.appGroupIdentifier) {
        self.containerURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    /// For tests: an inbox in a directory of their choosing.
    init(directory: URL) {
        self.containerURL = directory
    }

    var isAvailable: Bool { containerURL != nil }

    private var fileURL: URL? {
        containerURL?.appendingPathComponent("inbox.json")
    }

    /// Everything waiting, oldest first.
    func captures() -> [SharedCapture] {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([SharedCapture].self, from: data)) ?? []
    }

    /// Appends one capture.
    ///
    /// Read-modify-write on a file two processes can touch. The extension and the app
    /// are rarely awake at the same moment, and the cost of the rare lost capture is
    /// one re-share — so this stays a plain atomic write rather than acquiring a file
    /// coordinator the extension would have to keep alive while it is being torn down.
    @discardableResult
    func append(_ capture: SharedCapture) -> Bool {
        guard !capture.isEmpty else { return false }
        var all = captures()
        all.append(capture)
        // Keeps the file small if the app is never opened. The traveller who shares
        // forty reels and opens the app once wants the recent ones.
        if all.count > Self.limit { all = Array(all.suffix(Self.limit)) }
        return write(all)
    }

    func remove(_ id: UUID) {
        write(captures().filter { $0.id != id })
    }

    func removeAll() {
        write([])
    }

    static let limit = 50

    @discardableResult
    private func write(_ captures: [SharedCapture]) -> Bool {
        guard let fileURL else { return false }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(captures) else { return false }
        do {
            try data.write(to: fileURL, options: .atomic)
            return true
        } catch {
            return false
        }
    }
}
