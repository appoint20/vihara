import Foundation
@testable import Vihara

/// Builders for the domain values the tests need.
///
/// Every parameter has a default, so each test names only the field it is actually
/// about — which is what keeps a failing test readable a year later.
enum Fixture {

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        calendar.locale = Locale(identifier: "de_DE")
        return calendar
    }

    static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    static func place(_ name: String = "Ort",
                      opens: (Int, Int)? = nil,
                      closes: (Int, Int)? = nil,
                      diet: DietSignal = .notApplicable,
                      requiresTicket: Bool = false) -> Place {
        var hours: OpeningWindow?
        if let opens, let closes {
            hours = OpeningWindow(opensAt: MinuteOfDay(hour: opens.0, minute: opens.1),
                                  closesAt: MinuteOfDay(hour: closes.0, minute: closes.1))
        }
        return Place(providerPlaceID: "test:\(name)",
                     name: name,
                     address: "Teststraße 1",
                     coordinate: Coordinate(latitude: 44.49, longitude: 11.34),
                     openingHours: hours,
                     dietSignal: diet,
                     requiresTicket: requiresTicket)
    }

    static func item(_ name: String = "Ort",
                     kind: ItineraryItem.Kind = .sight,
                     at time: (Int, Int)? = nil,
                     minutes: Int = 60,
                     pinned: Bool = false,
                     walk: Int? = nil,
                     place: Place? = nil) -> ItineraryItem {
        ItineraryItem(place: place ?? Self.place(name),
                      kind: kind,
                      startsAt: time.map { MinuteOfDay(hour: $0.0, minute: $0.1) },
                      durationMinutes: minutes,
                      isPinned: pinned,
                      travelFromPrevious: walk.map { TravelLeg(mode: .walk, minutes: $0) })
    }

    static func brief(destination: String = "Bologna",
                      nights: Int = 3,
                      pace: TripBrief.Pace = .balanced,
                      diet: TripBrief.DietRequirement = .none) -> TripBrief {
        TripBrief(destination: destination,
                  startDate: date(2026, 4, 14),
                  nights: nights,
                  pace: pace,
                  diet: diet)
    }

    static func day(city: String = "Bologna", blocks: [DayBlock]) -> TripDay {
        TripDay(date: date(2026, 4, 14), city: city, blocks: blocks)
    }
}

/// A generator that replays a script, so tests over ``GenerateTrip`` are about the
/// use case and not about timing.
struct ScriptedTripGenerator: TripGenerating {
    let events: [TripGenerationEvent]
    var failure: (any Error)?

    func generate(from brief: TripBrief) -> AsyncThrowingStream<TripGenerationEvent, any Error> {
        AsyncThrowingStream { continuation in
            for event in events { continuation.yield(event) }
            continuation.finish(throwing: failure)
        }
    }
}
