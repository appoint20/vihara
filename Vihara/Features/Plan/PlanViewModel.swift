import Foundation

/// F-02 — the plan as it arrives.
///
/// Days are appended as the stream validates them, so the screen has content long
/// before generation finishes. The traveller never waits on a full-screen spinner;
/// they watch a plan being written.
@MainActor
@Observable
final class PlanViewModel {
    enum Phase: Equatable {
        case generating
        case ready
        case failed(DomainError)
    }

    /// Where the days come from.
    ///
    /// The screen is the same either way — a plan being written and a plan being
    /// re-read are the same three blocks a day — so this is a difference in how the
    /// model fills, not in what the view draws.
    private enum Source {
        case generating(GenerateTrip)
        /// Already composed and on disk. Nothing to stream, nothing to retry.
        case stored
    }

    let brief: TripBrief
    private let source: Source
    private let rules: ItineraryRules

    private(set) var days: [TripDay] = []
    private(set) var expectedDays = 0
    private(set) var phase: Phase = .generating
    private(set) var tripID: Identifier<Trip>?

    private var generation: Task<Void, Never>?

    init(brief: TripBrief, generateTrip: GenerateTrip) {
        self.brief = brief
        self.source = .generating(generateTrip)
        self.rules = ItineraryRules(brief: brief)
        self.expectedDays = brief.dayCount
    }

    /// Opens a plan the traveller already has.
    ///
    /// Reads as finished from the first frame: no skeleton, no stream, no second
    /// generation. Re-generating a saved plan would spend an allowance and could
    /// quietly return something different from what they saved.
    init(trip: Trip) {
        self.brief = trip.brief
        self.source = .stored
        self.rules = ItineraryRules(brief: trip.brief)
        self.days = trip.days
        self.expectedDays = trip.days.count
        self.phase = .ready
        self.tripID = trip.id
    }

    /// Idempotent: re-entering the screen after a background does not restart a
    /// generation that is already running or already finished.
    func startIfNeeded() {
        guard case let .generating(generateTrip) = source, generation == nil else { return }
        generation = Task { await run(generateTrip) }
    }

    func retry() {
        guard case .generating = source else { return }
        generation?.cancel()
        generation = nil
        days = []
        phase = .generating
        startIfNeeded()
    }

    func cancel() {
        generation?.cancel()
        generation = nil
    }

    private func run(_ generateTrip: GenerateTrip) async {
        do {
            for try await event in generateTrip(brief: brief) {
                switch event {
                case let .accepted(tripID, expectedDays):
                    self.tripID = tripID
                    self.expectedDays = expectedDays
                case let .dayReady(day):
                    days.append(day)
                case .completed:
                    phase = .ready
                }
            }
            // A stream that ends without `completed` — a dropped connection — leaves
            // whatever arrived on screen and offers a retry, rather than discarding a
            // partial plan the traveller can already read.
            if phase == .generating {
                phase = days.isEmpty ? .failed(.connectionFailed) : .ready
            }
        } catch let error as DomainError {
            phase = .failed(error)
        } catch {
            phase = .failed(.unexpectedResponse)
        }
    }

    // MARK: - Presentation

    /// Conflicts in a day, computed locally. No round trip is needed to tell the
    /// traveller that a museum shuts before their visit ends (F-06).
    func warnings(for day: TripDay) -> [PlanWarning] {
        rules.warnings(for: day)
    }

    /// Exactly one skeleton, for the day being composed right now — never a queue of
    /// grey rectangles standing in for the whole trip (PRD 5.1, rule 7).
    var showsSkeleton: Bool {
        phase == .generating && days.count < expectedDays
    }

    var title: String {
        brief.destination.isEmpty ? "Dein Plan" : brief.destination
    }

    /// "4 Nächte · Entspannt · Vegetarisch"
    var subtitle: String {
        var parts = [brief.nightsLabel, brief.pace.label]
        if brief.diet.requiresSignal { parts.append(brief.diet.label) }
        return parts.joined(separator: " · ")
    }

    /// What the share sheet hands on. Built from the days actually on screen, so a
    /// plan shared is always the plan the traveller is looking at.
    var shareText: String {
        PlanTextExport.text(brief: brief, days: days)
    }
}
