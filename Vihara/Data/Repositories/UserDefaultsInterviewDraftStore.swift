import Foundation

/// Unfinished interviews, in `UserDefaults`.
///
/// `UserDefaults` rather than the JSON directory ``FileTripRepository`` uses, because
/// the two have different lifetimes and different stakes: a plan is the traveller's
/// work and is worth an atomic write and a mapper that refuses bad data, while a
/// draft is a convenience that may be dropped on the floor without anyone losing
/// anything. Storing them the same way would imply they matter the same amount.
///
/// Still goes through a DTO, because ADR-003 applies to every serialisation boundary
/// and not only to the ones on the wire.
actor UserDefaultsInterviewDraftStore: InterviewDraftStore {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "interviewDrafts") {
        self.defaults = defaults
        self.key = key
    }

    func drafts() async -> [InterviewDraft] {
        stored()
            .map(\.domain)
            .filter(\.isWorthResuming)
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func save(_ draft: InterviewDraft) async {
        var records = stored().filter { $0.destination.lowercased() != draft.id }
        records.append(Record(draft))
        // Two is as many as anyone resumes. Keeping every abandoned interview would
        // turn a helpful row into a graveyard.
        write(Array(records.sorted { $0.updatedAt > $1.updatedAt }.prefix(Self.limit)))
    }

    func delete(id: String) async {
        write(stored().filter { $0.destination.lowercased() != id })
    }

    private static let limit = 2

    // MARK: - Storage

    private func stored() -> [Record] {
        guard let data = defaults.data(forKey: key),
              let records = try? JSONDecoder().decode([Record].self, from: data)
        else { return [] }
        return records
    }

    private func write(_ records: [Record]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: key)
    }

    /// The stored shape. A draft that cannot be decoded is dropped rather than
    /// thrown — see the type comment: nobody loses anything.
    private struct Record: Codable {
        let destination: String
        let step: Int
        let totalSteps: Int
        let nights: Int
        let updatedAt: Double

        init(_ draft: InterviewDraft) {
            destination = draft.destination
            step = draft.step
            totalSteps = draft.totalSteps
            nights = draft.nights
            updatedAt = draft.updatedAt.timeIntervalSince1970
        }

        var domain: InterviewDraft {
            InterviewDraft(destination: destination,
                           step: step,
                           totalSteps: totalSteps,
                           nights: nights,
                           updatedAt: Date(timeIntervalSince1970: updatedAt))
        }
    }
}

/// Drafts held in memory, for tests and previews.
actor InMemoryInterviewDraftStore: InterviewDraftStore {
    private var storage: [String: InterviewDraft]

    init(seed: [InterviewDraft] = []) {
        storage = Dictionary(uniqueKeysWithValues: seed.map { ($0.id, $0) })
    }

    func drafts() async -> [InterviewDraft] {
        storage.values.filter(\.isWorthResuming).sorted { $0.updatedAt > $1.updatedAt }
    }

    func save(_ draft: InterviewDraft) async { storage[draft.id] = draft }
    func delete(id: String) async { storage[id] = nil }
}
