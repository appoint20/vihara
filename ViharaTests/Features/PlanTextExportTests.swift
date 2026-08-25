import Testing
import Foundation
@testable import Vihara

@Suite("Sharing a plan")
struct PlanTextExportTests {

    private let brief = TripBrief(destination: "Bologna",
                                  startDate: Fixture.date(2026, 4, 14),
                                  nights: 2,
                                  pace: .relaxed,
                                  diet: .vegetarian)

    private var day: TripDay {
        TripDay(date: Fixture.date(2026, 4, 14), city: "Bologna", blocks: [
            DayBlock(slot: .morning, items: [
                ItineraryItem(place: Fixture.place("Basilica di Santo Stefano",
                                                   requiresTicket: true),
                              kind: .sight,
                              startsAt: MinuteOfDay(hour: 9, minute: 15)),
            ]),
            DayBlock(slot: .afternoon),
            DayBlock(slot: .evening, items: [
                ItineraryItem(place: Fixture.place("Osteria dell'Orsa",
                                                   diet: .likely(.vegetarian)),
                              kind: .meal,
                              travelFromPrevious: TravelLeg(mode: .walk, minutes: 7)),
            ]),
        ])
    }

    @Test("The shared text names the trip, the day and every stop")
    func rendersThePlan() {
        let text = PlanTextExport.text(brief: brief, days: [day])

        #expect(text.hasPrefix("Bologna\n"))
        #expect(text.contains("2 Nächte · Entspannt"))
        #expect(text.contains("Basilica di Santo Stefano"))
        #expect(text.contains("Osteria dell'Orsa"))
        #expect(text.contains("9:15"))
        #expect(text.contains("7 Min. zu Fuß"))
        #expect(text.contains("Ticket vorab nötig"))
    }

    @Test("An empty block is left out rather than shared as a heading with nothing under it")
    func skipsEmptyBlocks() {
        let text = PlanTextExport.text(brief: brief, days: [day])

        #expect(text.contains("VORMITTAG"))
        #expect(text.contains("ABEND"))
        #expect(!text.contains("NACHMITTAG"))
    }

    /// The caveat is the one line that must survive being pasted into a message —
    /// that is the moment the plan is read by someone who never saw the screen.
    @Test("The transparency notice travels with the plan")
    func carriesTheDisclaimer() {
        let full = PlanTextExport.text(brief: brief, days: [day])
        let empty = PlanTextExport.text(brief: brief, days: [])

        #expect(full.contains("Automatisch erstellt mit Vihara"))
        #expect(full.contains("nicht gegen Live-Daten geprüft"))
        #expect(empty.contains("Automatisch erstellt mit Vihara"))
    }

    @Test("A shared plan never claims evidence the screen does not show")
    func neverOverclaims() {
        let text = PlanTextExport.text(brief: brief, days: [day])

        // The stop carries a `.likely` signal, so the share text must say
        // "wahrscheinlich" — exactly as the badge on screen does.
        #expect(text.contains("vegetarisch wahrscheinlich"))
        #expect(!text.contains("vegetarisch bestätigt"))
    }
}
