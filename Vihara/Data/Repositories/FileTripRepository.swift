import Foundation

/// Plans on disk (F-14).
///
/// One JSON file per trip in Application Support, written atomically. One file per
/// trip rather than one file for all of them, for two reasons: saving a plan never
/// rewrites the others, and a record that somehow becomes unreadable costs the
/// traveller that plan instead of their whole library.
///
/// An `actor`, like the in-memory store it replaces, so no call site had to change.
///
/// This is deliberately not SwiftData. The domain types are not `Codable` and not
/// `@Model` (ADR-003), the volume is a handful of plans, and the mapper the store
/// needs has to exist either way. A JSON directory keeps the persistence format
/// something a person can read while debugging, which matters more at this stage than
/// query support the product does not use.
actor FileTripRepository: TripRepository {
    private let directory: URL
    private let mapper: TripRecordMapper
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// - Parameter directory: where records live. Defaults to
    ///   `Application Support/Trips`; tests pass a temporary directory.
    init(directory: URL? = nil,
         mapper: TripRecordMapper = TripRecordMapper(),
         fileManager: FileManager = .default) {
        self.directory = directory ?? Self.defaultDirectory(using: fileManager)
        self.mapper = mapper
        self.fileManager = fileManager

        let encoder = JSONEncoder()
        // Readable on disk while the backend does not exist, and stable across writes
        // so a diff of the store shows what actually changed.
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
        self.decoder = JSONDecoder()
    }

    // MARK: - TripRepository

    /// Newest first.
    ///
    /// A record that cannot be decoded is skipped rather than thrown, which is the
    /// one place this type deliberately departs from ADR-003's fail-loudly rule: the
    /// library screen must open. ``trip(id:)`` still throws, so opening that specific
    /// plan reports the problem instead of showing an empty one.
    func allTrips() async throws -> [Trip] {
        try ensureDirectoryExists()
        let files = try fileManager.contentsOfDirectory(at: directory,
                                                        includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == Self.fileExtension }

        return files
            .compactMap { try? decodeTrip(at: $0) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func trip(id: Identifier<Trip>) async throws -> Trip? {
        let url = self.url(for: id)
        guard fileManager.fileExists(atPath: url.path(percentEncoded: false)) else { return nil }
        return try decodeTrip(at: url)
    }

    func save(_ trip: Trip) async throws {
        try ensureDirectoryExists()
        let data = try encoder.encode(mapper.record(from: trip))
        // Atomic: a write interrupted by the app being killed leaves the previous
        // record intact rather than a truncated one.
        try data.write(to: url(for: trip.id), options: .atomic)
    }

    func delete(id: Identifier<Trip>) async throws {
        let url = self.url(for: id)
        guard fileManager.fileExists(atPath: url.path(percentEncoded: false)) else { return }
        try fileManager.removeItem(at: url)
    }

    // MARK: - Files

    private static let fileExtension = "json"

    private static func defaultDirectory(using fileManager: FileManager) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL.temporaryDirectory
        return base.appending(path: "Trips", directoryHint: .isDirectory)
    }

    private func ensureDirectoryExists() throws {
        guard !fileManager.fileExists(atPath: directory.path(percentEncoded: false)) else { return }
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// Trip ids are generated UUIDs, but percent-encoding keeps this correct even if
    /// the server ever hands out an id with a slash or a dot in it. Hyphens are left
    /// alone so a UUID still reads as a UUID in a directory listing.
    private static let filenameSafe = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))

    private func url(for id: Identifier<Trip>) -> URL {
        let name = id.rawValue.addingPercentEncoding(withAllowedCharacters: Self.filenameSafe)
            ?? id.rawValue
        return directory.appending(path: name).appendingPathExtension(Self.fileExtension)
    }

    private func decodeTrip(at url: URL) throws -> Trip {
        let data = try Data(contentsOf: url)
        return try mapper.trip(from: decoder.decode(TripRecordDTO.Trip.self, from: data))
    }
}
