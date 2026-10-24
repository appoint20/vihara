import Testing
import Foundation
@testable import Vihara

/// F-14. A plan the traveller generated has to still be there tomorrow.
@Suite("On-device trip store")
struct FileTripRepositoryTests {

    /// Each test gets its own directory, so nothing leaks between them and none of
    /// them touch the real Application Support folder.
    private func store() -> (FileTripRepository, URL) {
        let directory = URL.temporaryDirectory
            .appending(path: "vihara-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
        return (FileTripRepository(directory: directory,
                                   mapper: TripRecordMapper(calendar: Fixture.calendar)),
                directory)
    }

    private func trip(destination: String = "Bologna",
                      nights: Int = 2,
                      createdAt: Date = Fixture.date(2026, 4, 1)) -> Trip {
        let brief = TripBrief(destination: destination,
                              startDate: Fixture.date(2026, 4, 14),
                              nights: nights,
                              travelStyle: .roundTrip,
                              pace: .relaxed,
                              budget: .premium,
                              diet: .vegan,
                              party: TravelParty(adults: 2,
                                                 childAges: [4, 9],
                                                 accommodations: [.middaySleep, .pushchair]),
                              sourceText: "\(nights + 1) Tage \(destination), vegan")
        let day = TripDay(
            date: Fixture.date(2026, 4, 14),
            city: destination,
            blocks: [
                DayBlock(slot: .morning, items: [
                    ItineraryItem(place: Fixture.place("Santo Stefano",
                                                       opens: (8, 30),
                                                       closes: (18, 0),
                                                       requiresTicket: true,
                                                       minimumAge: 12,
                                                       admission: Admission(adultPrice: Money(5),
                                                                            freeUnderAge: 6),
                                                       isStepFree: false),
                                  kind: .sight,
                                  startsAt: MinuteOfDay(hour: 9, minute: 15),
                                  durationMinutes: 75,
                                  isPinned: true),
                ]),
                DayBlock(slot: .afternoon),
                DayBlock(slot: .evening, items: [
                    ItineraryItem(place: Fixture.place("Botanica", diet: .likely(.vegan)),
                                  kind: .meal,
                                  travelFromPrevious: TravelLeg(mode: .walk, minutes: 12)),
                ]),
            ]
        )
        return Trip(brief: brief, days: [day], revision: 3, createdAt: createdAt)
    }

    @Test("A saved plan survives a new store over the same directory")
    func survivesRelaunch() async throws {
        let (repository, directory) = store()
        let original = trip()
        try await repository.save(original)

        // A fresh actor over the same directory is what a relaunch looks like.
        let relaunched = FileTripRepository(directory: directory,
                                            mapper: TripRecordMapper(calendar: Fixture.calendar))
        let loaded = try await relaunched.trip(id: original.id)

        #expect(loaded == original)
    }

    @Test("Every field of a plan round-trips, not just its name")
    func roundTripIsLossless() async throws {
        let (repository, _) = store()
        let original = trip()
        try await repository.save(original)
        let loaded = try #require(try await repository.trip(id: original.id))

        #expect(loaded.revision == 3)
        #expect(loaded.createdAt == original.createdAt)
        #expect(loaded.brief == original.brief)
        #expect(loaded.brief.sourceText == "3 Tage Bologna, vegan")
        #expect(loaded.brief.party.adults == 2)
        #expect(loaded.brief.party.childAges == [4, 9])
        #expect(loaded.brief.party.accommodations == [.middaySleep, .pushchair])

        let item = try #require(loaded.days.first?[.morning]?.items.first)
        #expect(item.place.name == "Santo Stefano")
        #expect(item.place.openingHours?.opensAt == MinuteOfDay(hour: 8, minute: 30))
        #expect(item.place.requiresTicket)
        #expect(item.place.minimumAge == 12)
        #expect(item.place.admission == Admission(adultPrice: Money(5), freeUnderAge: 6))
        #expect(item.place.isStepFree == false)
        #expect(item.startsAt == MinuteOfDay(hour: 9, minute: 15))
        #expect(item.durationMinutes == 75)
        #expect(item.isPinned)

        let meal = try #require(loaded.days.first?[.evening]?.items.first)
        #expect(meal.place.dietSignal == .likely(.vegan))
        #expect(meal.travelFromPrevious == TravelLeg(mode: .walk, minutes: 12))
    }

    @Test("Trips list newest first")
    func listedNewestFirst() async throws {
        let (repository, _) = store()
        let older = trip(destination: "Modena", createdAt: Fixture.date(2026, 3, 1))
        let newer = trip(destination: "Ravenna", createdAt: Fixture.date(2026, 5, 1))

        try await repository.save(older)
        try await repository.save(newer)

        let all = try await repository.allTrips()
        #expect(all.map(\.brief.destination) == ["Ravenna", "Modena"])
    }

    @Test("Saving the same trip twice updates it rather than duplicating it")
    func saveIsIdempotentPerTrip() async throws {
        let (repository, _) = store()
        var plan = trip()
        try await repository.save(plan)
        plan.revision = 9
        try await repository.save(plan)

        let all = try await repository.allTrips()
        #expect(all.count == 1)
        #expect(all.first?.revision == 9)
    }

    @Test("Deleting removes the record; deleting twice is not an error")
    func deletion() async throws {
        let (repository, _) = store()
        let plan = trip()
        try await repository.save(plan)

        try await repository.delete(id: plan.id)
        try await repository.delete(id: plan.id)

        #expect(try await repository.trip(id: plan.id) == nil)
        #expect(try await repository.allTrips().isEmpty)
    }

    @Test("An empty store reads as empty rather than failing")
    func emptyStore() async throws {
        let (repository, _) = store()
        #expect(try await repository.allTrips().isEmpty)
        #expect(try await repository.trip(id: Identifier("nothing-here")) == nil)
    }

    /// The library screen must open even when one record is damaged. Opening that
    /// specific plan still reports the problem — see ``FileTripRepository/allTrips()``.
    @Test("A corrupt record costs that plan, not the whole library")
    func corruptRecordIsSkipped() async throws {
        let (repository, directory) = store()
        let good = trip(destination: "Bologna")
        try await repository.save(good)

        let corrupt = directory.appending(path: "broken.json")
        try Data("{ not json".utf8).write(to: corrupt)

        let all = try await repository.allTrips()
        #expect(all.map(\.brief.destination) == ["Bologna"])
    }

    @Test("A record written by a newer app version is refused, not half-read")
    func futureSchemaIsRefused() throws {
        let mapper = TripRecordMapper(calendar: Fixture.calendar)
        var record = mapper.record(from: trip())
        record.schemaVersion = TripRecordDTO.currentSchemaVersion + 1

        #expect(throws: DomainError.unexpectedResponse) {
            try mapper.trip(from: record)
        }
    }

    @Test("An unknown enum value in a record is refused rather than guessed at")
    func unknownRawValueIsRefused() throws {
        let mapper = TripRecordMapper(calendar: Fixture.calendar)
        let record = mapper.record(from: trip())
        let broken = TripRecordDTO.Trip(id: record.id,
                                        brief: TripRecordDTO.Brief(destination: "Bologna",
                                                                   startDate: "2026-04-14",
                                                                   nights: 2,
                                                                   travelStyle: "teleportation",
                                                                   pace: record.brief.pace,
                                                                   budget: record.brief.budget,
                                                                   diet: record.brief.diet,
                                                                   party: record.brief.party,
                                                                   sourceText: nil),
                                        days: record.days,
                                        revision: record.revision,
                                        createdAt: record.createdAt)

        #expect(throws: DomainError.unexpectedResponse) {
            try mapper.trip(from: broken)
        }
    }
}
