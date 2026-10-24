import Foundation

/// Generates a plan from ``SampleItineraries``, one day at a time, with the latency
/// a real composition run would have.
///
/// The delay is not decoration. Day-by-day streaming is a product rule (PRD 5.1,
/// rule 7), and a stub that returns instantly would let a full-screen spinner or a
/// missing skeleton state ship unnoticed. Building the streaming UI against a stub
/// that streams is the whole point.
struct StubTripGenerator: TripGenerating {
    private let catalogue: any DestinationCatalogue
    private let calendar: Calendar
    /// Time to the first validated day. The PRD budget is 25 s; the stub is quick
    /// enough to work with and slow enough to be visible.
    private let firstDayLatency: Duration
    private let subsequentDayLatency: Duration

    init(catalogue: any DestinationCatalogue,
         calendar: Calendar = .current,
         firstDayLatency: Duration = .milliseconds(900),
         subsequentDayLatency: Duration = .milliseconds(650)) {
        self.catalogue = catalogue
        self.calendar = calendar
        self.firstDayLatency = firstDayLatency
        self.subsequentDayLatency = subsequentDayLatency
    }

    func generate(from brief: TripBrief) -> AsyncThrowingStream<TripGenerationEvent, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    // Resolve once, then plan against the resolved identity. Matching
                    // on the raw string in two places is what let the name and the
                    // itinerary disagree.
                    guard let destination = try await catalogue.destination(matching: brief.destination) else {
                        throw DomainError.noValidatedCandidates(destination: brief.destination)
                    }

                    let templates = SampleItineraries.templates(for: destination.id)
                    guard !templates.isEmpty else {
                        throw DomainError.noValidatedCandidates(destination: brief.destination)
                    }

                    let tripID = Identifier<Trip>.generate()
                    continuation.yield(.accepted(tripID: tripID, expectedDays: brief.dayCount))

                    for offset in 0..<brief.dayCount {
                        try await Task.sleep(for: offset == 0 ? firstDayLatency : subsequentDayLatency)
                        try Task.checkCancellation()

                        let template = templates[offset % templates.count]
                        let date = calendar.date(byAdding: .day, value: offset, to: brief.startDate)
                            ?? brief.startDate
                        continuation.yield(.dayReady(TripDay(
                            date: date,
                            city: template.city,
                            blocks: SampleItineraries.blocks(from: template, brief: brief),
                            // The first day is an arrival, not a transfer between stops.
                            arrivalTransfer: offset == 0 ? nil : template.arrivalTransfer
                        )))
                    }

                    continuation.yield(.completed)
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
