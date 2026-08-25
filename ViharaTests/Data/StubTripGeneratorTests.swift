import Testing
import Foundation
@testable import Vihara

@Suite("Stub generation")
struct StubTripGeneratorTests {

    private let generator = StubTripGenerator(catalogue: PilotDestinationCatalogue(),
                                              calendar: Fixture.calendar,
                                              firstDayLatency: .zero,
                                              subsequentDayLatency: .zero)

    private func days(for destination: String, nights: Int = 2) async throws -> [TripDay] {
        let brief = TripBrief(destination: destination,
                              startDate: Fixture.date(2026, 4, 14),
                              nights: nights)
        var days: [TripDay] = []
        for try await event in generator.generate(from: brief) {
            if case let .dayReady(day) = event { days.append(day) }
        }
        return days
    }

    /// The regression that mattered: Formentera was in the catalogue, had no
    /// itinerary, and fell through to Emilia-Romagna — so the plan header said
    /// Formentera while every day underneath said Bologna.
    @Test("A destination we cannot plan fails loudly rather than returning another city")
    func uncuratedDestinationDoesNotBorrowAnotherCitysPlan() async {
        await #expect(throws: DomainError.noValidatedCandidates(destination: "Formentera")) {
            try await days(for: "Formentera")
        }
    }

    @Test("Somewhere we have never heard of fails the same way")
    func unknownDestinationFails() async {
        await #expect(throws: DomainError.noValidatedCandidates(destination: "Reykjavík")) {
            try await days(for: "Reykjavík")
        }
    }

    @Test("Every day of a curated plan names a city inside the region asked for")
    func curatedPlanStaysInRegion() async throws {
        let days = try await days(for: "Bologna", nights: 3)

        #expect(days.count == 4)
        // The Emilia-Romagna set day-trips to Modena and Ravenna, which is the point
        // of a round trip — but never to somewhere in another country.
        let cities = Set(days.map(\.city))
        #expect(cities.isSubset(of: ["Bologna", "Modena", "Ravenna"]))
        #expect(days.first?.city == "Bologna")
    }

    @Test("The first day is an arrival, so it carries no transfer")
    func firstDayHasNoTransfer() async throws {
        let days = try await days(for: "Bologna", nights: 2)
        #expect(days.first?.arrivalTransfer == nil)
    }
}
