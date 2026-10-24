import Foundation

/// An interview somebody started and did not finish.
///
/// The home surface offers these back as "Angefangen" rows. Without them, closing the
/// interview four questions in throws four questions away — which is the single most
/// annoying thing a multi-step flow can do, and the reason people do not start them.
///
/// Keyed on the destination rather than on a generated id: starting a second Bologna
/// interview should continue the first one, not stack a duplicate beside it.
struct InterviewDraft: Hashable, Sendable, Identifiable {
    var id: String { destination.lowercased() }

    var destination: String
    /// Zero-based, matching the interview's own step index.
    var step: Int
    var totalSteps: Int
    var nights: Int
    var updatedAt: Date

    init(destination: String, step: Int, totalSteps: Int, nights: Int, updatedAt: Date = .now) {
        self.destination = destination
        self.step = step
        self.totalSteps = totalSteps
        self.nights = nights
        self.updatedAt = updatedAt
    }

    /// A draft is only worth offering back if it got somewhere. Resuming at step one
    /// is just starting, and a row that saves nobody anything is a row in the way.
    var isWorthResuming: Bool { step > 0 && step < totalSteps }
}

/// Where unfinished interviews live.
///
/// Deliberately not ``TripRepository``: a draft is not a plan. It has no days, it has
/// never been validated, and it should disappear the moment the plan it becomes is
/// generated.
protocol InterviewDraftStore: Sendable {
    func drafts() async -> [InterviewDraft]
    func save(_ draft: InterviewDraft) async
    func delete(id: String) async
}
