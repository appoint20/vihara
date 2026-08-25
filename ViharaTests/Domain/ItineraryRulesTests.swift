import Testing
import Foundation
@testable import Vihara

/// The composition constraints from PRD 3.1.
///
/// These rules are what let the client name a conflict the instant an edit creates
/// one, with no round trip — so they are worth pinning down precisely.
@Suite("Itinerary rules")
struct ItineraryRulesTests {

    @Test("A block holding more than the pace allows is flagged")
    func blockOverfull() {
        let rules = ItineraryRules(brief: Fixture.brief(pace: .relaxed))
        let block = DayBlock(slot: .morning, items: [
            Fixture.item("Basilica"),
            Fixture.item("Markt"),
        ])

        let warnings = rules.warnings(for: block)

        #expect(warnings.contains { $0.kind == .blockOverfull(limit: 1) })
        #expect(warnings.allSatisfy { $0.slot == .morning })
    }

    @Test("Two headline sights in one half-day are flagged")
    func competingHeadlines() {
        let rules = ItineraryRules(brief: Fixture.brief(pace: .packed))
        let block = DayBlock(slot: .afternoon, items: [
            Fixture.item("Torre", kind: .sight),
            Fixture.item("Basilica", kind: .sight),
            Fixture.item("Trattoria", kind: .meal),
        ])

        #expect(rules.warnings(for: block).contains { $0.kind == .competingHeadlines })
    }

    @Test("An evening with plans but no meal is flagged; an empty evening is not")
    func missingMeal() {
        let rules = ItineraryRules(brief: Fixture.brief())

        let withPlans = DayBlock(slot: .evening, items: [Fixture.item("Konzert", kind: .activity)])
        #expect(rules.warnings(for: withPlans).contains { $0.kind == .missingMeal })

        // A free evening is a plan, not an omission.
        #expect(rules.warnings(for: DayBlock(slot: .evening)).isEmpty)
    }

    @Test("Mornings are not expected to carry a meal")
    func morningNeedsNoMeal() {
        let rules = ItineraryRules(brief: Fixture.brief())
        let morning = DayBlock(slot: .morning, items: [Fixture.item("Basilica")])

        #expect(!rules.warnings(for: morning).contains { $0.kind == .missingMeal })
    }

    @Test("A meal that cannot be verified against a stated diet is flagged on the item")
    func unverifiedDiet() throws {
        let rules = ItineraryRules(brief: Fixture.brief(diet: .vegan))
        let meal = Fixture.item("Trattoria", kind: .meal,
                                place: Fixture.place("Trattoria", diet: .confirmed(.vegetarian, source: .venueMenu)))
        let block = DayBlock(slot: .evening, items: [meal])

        let warning = try #require(rules.warnings(for: block).first {
            $0.kind == .mealNotVerifiedForDiet(place: "Trattoria", diet: .vegan)
        })
        // Item-scoped so it can be drawn under the item that caused it.
        #expect(warning.itemID == meal.id)
    }

    @Test("A confirmed vegan venue satisfies a vegetarian brief")
    func veganSatisfiesVegetarian() {
        let rules = ItineraryRules(brief: Fixture.brief(diet: .vegetarian))
        let block = DayBlock(slot: .evening, items: [
            Fixture.item(kind: .meal,
                         place: Fixture.place("Botanica", diet: .confirmed(.vegan, source: .providerAttribute))),
        ])

        #expect(!rules.warnings(for: block).contains {
            if case .mealNotVerifiedForDiet = $0.kind { return true } else { return false }
        })
    }

    @Test("A visit that runs past closing time is flagged")
    func closedAtPlannedTime() {
        let rules = ItineraryRules(brief: Fixture.brief())
        let block = DayBlock(slot: .morning, items: [
            Fixture.item(at: (12, 30), minutes: 60,
                         place: Fixture.place("Basilica", opens: (8, 30), closes: (13, 0))),
        ])

        #expect(rules.warnings(for: block).contains { $0.kind == .closedAtPlannedTime(place: "Basilica") })
    }

    @Test("A visit inside opening hours is not flagged")
    func openAtPlannedTime() {
        let rules = ItineraryRules(brief: Fixture.brief())
        let block = DayBlock(slot: .morning, items: [
            Fixture.item(at: (8, 30), minutes: 75,
                         place: Fixture.place("Basilica", opens: (8, 30), closes: (13, 0))),
        ])

        #expect(rules.warnings(for: block).isEmpty)
    }

    @Test("Walking beyond the pace's allowance is flagged")
    func excessiveWalking() {
        // relaxed → 900 m at 80 m/min → 11 minutes.
        let rules = ItineraryRules(brief: Fixture.brief(pace: .relaxed))
        let block = DayBlock(slot: .afternoon, items: [
            Fixture.item("Museum", walk: 20),
        ])

        #expect(rules.warnings(for: block).contains { $0.kind == .excessiveWalking(minutes: 20, limit: 11) })
    }

    @Test("Warnings for a whole day cover every block")
    func warningsAcrossADay() {
        let rules = ItineraryRules(brief: Fixture.brief(pace: .relaxed))
        let day = Fixture.day(blocks: [
            DayBlock(slot: .morning, items: [Fixture.item("A"), Fixture.item("B")]),
            DayBlock(slot: .afternoon),
            DayBlock(slot: .evening, items: [Fixture.item("Konzert", kind: .activity)]),
        ])

        let slots = Set(rules.warnings(for: day).map(\.slot))
        #expect(slots == [.morning, .evening])
    }

    @Suite("Drop targets")
    struct DropTargets {

        @Test("A full block refuses another item")
        func fullBlockRefuses() {
            let rules = ItineraryRules(brief: Fixture.brief(pace: .relaxed))
            let block = DayBlock(slot: .morning, items: [Fixture.item("Basilica")])

            #expect(!rules.canAccept(Fixture.item("Markt"), into: block))
        }

        @Test("A block with a headline refuses a second one but accepts a meal")
        func headlineExclusivity() {
            let rules = ItineraryRules(brief: Fixture.brief(pace: .balanced))
            let block = DayBlock(slot: .evening, items: [Fixture.item("Torre", kind: .sight)])

            #expect(!rules.canAccept(Fixture.item("Basilica", kind: .sight), into: block))
            #expect(rules.canAccept(Fixture.item("Trattoria", kind: .meal), into: block))
        }
    }
}
