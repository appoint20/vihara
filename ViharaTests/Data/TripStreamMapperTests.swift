import Testing
import Foundation
@testable import Vihara

/// The wire → domain boundary.
///
/// Mapping is where a backend change becomes visible, so these tests double as the
/// executable half of the contract.
@Suite("Trip stream mapping")
struct TripStreamMapperTests {

    private let mapper = TripStreamMapper(calendar: Fixture.calendar)

    private func placeDTO(diet: TripStreamDTO.Diet? = nil,
                          opens: String? = "08:30",
                          closes: String? = "13:00") -> TripStreamDTO.Place {
        TripStreamDTO.Place(id: "p1", providerPlaceId: "ChIJ1", name: "Basilica di San Petronio",
                            address: "Piazza Maggiore", lat: 44.4929, lng: 11.3426,
                            opensAt: opens, closesAt: closes, requiresTicket: false, diet: diet)
    }

    private func itemDTO(startsAt: String? = "08:30", kind: String = "sight") -> TripStreamDTO.Item {
        TripStreamDTO.Item(id: "i1", kind: kind, startsAt: startsAt, durationMinutes: 75,
                           pinned: false,
                           travelFromPrevious: TripStreamDTO.Travel(mode: "walk", minutes: 7),
                           place: placeDTO())
    }

    @Test("A full day maps across")
    func dayMapping() throws {
        let dto = TripStreamDTO.Day(id: "d1", date: "2026-04-14", city: "Bologna", blocks: [
            TripStreamDTO.Block(id: "b1", slot: "morning", items: [itemDTO()]),
        ])

        let day = try mapper.day(from: dto)

        #expect(day.city == "Bologna")
        #expect(day.date == Fixture.date(2026, 4, 14))
        let item = try #require(day[.morning]?.items.first)
        #expect(item.place.name == "Basilica di San Petronio")
        #expect(item.travelFromPrevious == TravelLeg(mode: .walk, minutes: 7))
    }

    @Test("Blocks the server omits come through empty, never missing")
    func missingBlocksAreBackfilled() throws {
        let dto = TripStreamDTO.Day(id: "d1", date: "2026-04-14", city: "Bologna", blocks: [
            TripStreamDTO.Block(id: "b1", slot: "evening", items: []),
        ])

        let day = try mapper.day(from: dto)

        // The UI has no "missing block" case to handle, because it cannot happen.
        #expect(day.blocks.count == 3)
        #expect(day.blocks.map(\.slot) == DaySlot.allCases)
    }

    @Test("An unknown slot is a contract break, not something to guess at")
    func unknownSlotThrows() {
        let dto = TripStreamDTO.Block(id: "b1", slot: "lateNight", items: [])

        #expect(throws: DomainError.unexpectedResponse) { try mapper.block(from: dto) }
    }

    @Test("An unparseable time is rejected rather than dropped")
    func badTimeThrows() {
        #expect(throws: DomainError.unexpectedResponse) {
            try mapper.item(from: itemDTO(startsAt: "8.30"))
        }
    }

    @Test("A confirmed diet signal keeps its evidence source")
    func confirmedDiet() {
        let signal = mapper.dietSignal(from: .init(status: "confirmed", diet: "vegan", source: "venueMenu"))

        #expect(signal == .confirmed(.vegan, source: .venueMenu))
    }

    @Test("A confirmed signal missing its source degrades to unknown, never to confirmed")
    func confirmedWithoutSourceDegrades() {
        let signal = mapper.dietSignal(from: .init(status: "confirmed", diet: "vegan", source: nil))

        // Erring towards a badge we cannot back up is the one failure that matters
        // here: it puts a vegan traveller in front of a meat menu.
        #expect(signal == .unknown)
    }

    @Test("An unrecognised status degrades to unknown rather than failing the day")
    func unknownStatusDegrades() {
        #expect(mapper.dietSignal(from: .init(status: "maybe", diet: "vegan", source: nil)) == .unknown)
    }

    @Suite("Scalars")
    struct Scalars {

        @Test("Times parse to minutes since midnight")
        func timeParsing() {
            #expect(TripStreamMapper.minute(from: "08:30") == MinuteOfDay(hour: 8, minute: 30))
            #expect(TripStreamMapper.minute(from: "0:05") == MinuteOfDay(hour: 0, minute: 5))
        }

        @Test("Out-of-range and malformed times are rejected", arguments: [
            "24:00", "08:60", "830", "08:30:00", "", "ab:cd",
        ])
        func invalidTimes(raw: String) {
            #expect(TripStreamMapper.minute(from: raw) == nil)
        }

        @Test("Dates parse to the start of the calendar day")
        func dateParsing() {
            #expect(TripStreamMapper.date(from: "2026-04-14", calendar: Fixture.calendar)
                    == Fixture.date(2026, 4, 14))
            #expect(TripStreamMapper.date(from: "14.04.2026", calendar: Fixture.calendar) == nil)
        }
    }
}
