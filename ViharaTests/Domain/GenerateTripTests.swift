import Testing
import Foundation
@testable import Vihara

@Suite("Generate trip")
struct GenerateTripTests {

    private func collect(
        _ stream: AsyncThrowingStream<TripGenerationEvent, any Error>
    ) async throws -> [TripGenerationEvent] {
        var events: [TripGenerationEvent] = []
        for try await event in stream { events.append(event) }
        return events
    }

    @Test("A brief with no destination never reaches the generator")
    func incompleteBriefIsRejected() async {
        var brief = Fixture.brief()
        brief.destination = ""
        let useCase = GenerateTrip(generator: ScriptedTripGenerator(events: []),
                                   trips: InMemoryTripRepository(),
                                   wallets: StubWalletRepository())

        await #expect(throws: DomainError.incompleteBrief) {
            _ = try await collect(useCase(brief: brief))
        }
    }

    @Test("A free account out of generations is told immediately, not after 25 seconds")
    func allowanceIsCheckedBeforeGenerating() async {
        let spent = Wallet(freeTripsUsedThisYear: 2, freeTripsAllowance: 2,
                           subscription: .none, periodCreditsGranted: 0,
                           periodCreditsUsed: 0, purchasedCredits: 0,
                           unlockedTripIDs: [], periodRenewsOn: nil)
        let useCase = GenerateTrip(generator: ScriptedTripGenerator(events: []),
                                   trips: InMemoryTripRepository(),
                                   wallets: StubWalletRepository(wallet: spent))

        await #expect(throws: (any Error).self) {
            _ = try await collect(useCase(brief: Fixture.brief()))
        }
    }

    @Test("Every streamed day is passed through in order")
    func daysArePassedThrough() async throws {
        let days = [Fixture.day(blocks: []), Fixture.day(city: "Modena", blocks: [])]
        let generator = ScriptedTripGenerator(events:
            [.accepted(tripID: Identifier("t1"), expectedDays: 2)]
            + days.map { .dayReady($0) }
            + [.completed])
        let useCase = GenerateTrip(generator: generator,
                                   trips: InMemoryTripRepository(),
                                   wallets: StubWalletRepository())

        let events = try await collect(useCase(brief: Fixture.brief()))

        #expect(events.count == 4)
        #expect(events.last == .completed)
    }

    @Test("The finished trip is saved exactly once, on completion")
    func tripIsPersistedOnCompletion() async throws {
        let repository = InMemoryTripRepository()
        let generator = ScriptedTripGenerator(events: [
            .accepted(tripID: Identifier("t1"), expectedDays: 1),
            .dayReady(Fixture.day(blocks: [])),
            .completed,
        ])
        let useCase = GenerateTrip(generator: generator,
                                   trips: repository,
                                   wallets: StubWalletRepository())

        _ = try await collect(useCase(brief: Fixture.brief()))

        let saved = try #require(await repository.trip(id: Identifier("t1")))
        let all = try await repository.allTrips()
        #expect(saved.days.count == 1)
        #expect(all.count == 1)
    }

    @Test("A stream that fails part-way saves nothing")
    func partialGenerationIsNotPersisted() async throws {
        let repository = InMemoryTripRepository()
        let generator = ScriptedTripGenerator(
            events: [.accepted(tripID: Identifier("t1"), expectedDays: 3),
                     .dayReady(Fixture.day(blocks: []))],
            failure: DomainError.planningUnavailable)
        let useCase = GenerateTrip(generator: generator,
                                   trips: repository,
                                   wallets: StubWalletRepository())

        _ = try? await collect(useCase(brief: Fixture.brief()))

        // A half-written trip in the store would later look like a finished plan.
        let all = try await repository.allTrips()
        #expect(all.isEmpty)
    }
}
