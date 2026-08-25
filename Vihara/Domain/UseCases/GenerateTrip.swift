import Foundation

/// Generating a plan, end to end: check the traveller may, stream the days through,
/// keep what arrives.
///
/// This is the one place those three collaborators meet. Feature code depends on
/// this use case rather than on three repositories, so a screen cannot accidentally
/// generate without the allowance check, and the persistence step cannot be
/// forgotten in a second call site.
struct GenerateTrip: Sendable {
    private let generator: any TripGenerating
    private let trips: any TripRepository
    private let wallets: any WalletRepository
    private let calendar: Calendar

    init(generator: any TripGenerating,
         trips: any TripRepository,
         wallets: any WalletRepository,
         calendar: Calendar = .current) {
        self.generator = generator
        self.trips = trips
        self.wallets = wallets
        self.calendar = calendar
    }

    /// Streams the plan as it is composed. Cancelling the consuming task cancels the
    /// generation.
    ///
    /// The allowance check here is a courtesy to the traveller — it turns a wasted
    /// 25-second wait into an immediate, explicit answer. It is *not* the enforcement
    /// point: the server re-checks, because a client-side gate is a suggestion.
    func callAsFunction(brief: TripBrief) -> AsyncThrowingStream<TripGenerationEvent, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard brief.isGeneratable else { throw DomainError.incompleteBrief }

                    let wallet = try await wallets.currentWallet()
                    guard wallet.canGenerateAnotherTrip else {
                        throw DomainError.generationLimitReached(resetsOn: startOfNextYear())
                    }

                    var composed: Trip?
                    for try await event in generator.generate(from: brief) {
                        switch event {
                        case let .accepted(tripID, _):
                            composed = Trip(id: tripID, brief: brief)
                        case let .dayReady(day):
                            composed?.days.append(day)
                        case .completed:
                            if let composed { try await trips.save(composed) }
                        }
                        continuation.yield(event)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// When the free allowance refills. The counter resets on 1 January (PRD 4.1).
    private func startOfNextYear() -> Date? {
        let year = calendar.component(.year, from: .now)
        return calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1))
    }
}
