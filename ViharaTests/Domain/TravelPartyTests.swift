import Testing
import Foundation
@testable import Vihara

/// The travel-party step earns its place only if the answers change the plan.
/// These are the tests that hold it to that.
@Suite("Travel party")
struct TravelPartyTests {

    private let bologna = Identifier<Destination>("bologna")

    private func brief(party: TravelParty, pace: TripBrief.Pace = .balanced) -> TripBrief {
        TripBrief(destination: "Bologna",
                  startDate: Fixture.date(2026, 4, 14),
                  nights: 2,
                  pace: pace,
                  party: party)
    }

    private func places(for party: TravelParty, pace: TripBrief.Pace = .balanced) -> [String] {
        SampleItineraries.templates(for: bologna)
            .flatMap { SampleItineraries.blocks(from: $0, brief: brief(party: party, pace: pace)) }
            .flatMap(\.items)
            .map(\.place.name)
    }

    // MARK: - Age limits

    /// The acceptance case, stated plainly: the Asinelli has a minimum age of 12, and
    /// a four-year-old in the party takes it off the plan.
    @Test("A four-year-old removes the Torre degli Asinelli")
    func youngChildDropsTheTower() {
        let withoutChildren = places(for: .couple)
        let withToddler = places(for: TravelParty(adults: 2, childAges: [4]))

        #expect(withoutChildren.contains("Torre degli Asinelli"))
        #expect(!withToddler.contains("Torre degli Asinelli"))
    }

    @Test("A child old enough to climb keeps it")
    func olderChildKeepsTheTower() {
        #expect(places(for: TravelParty(adults: 2, childAges: [12])).contains("Torre degli Asinelli"))
        #expect(!places(for: TravelParty(adults: 2, childAges: [11])).contains("Torre degli Asinelli"))
    }

    @Test("One child below the limit rules it out for everyone")
    func theWholePartyIsTurnedAway() {
        let mixed = TravelParty(adults: 2, childAges: [15, 6])
        #expect(!mixed.admits(towerPlace))
        #expect(mixed.childBlocked(by: towerPlace) == 6)
    }

    @Test("A place with no age limit admits anybody")
    func noLimitAdmitsAnyone() {
        let party = TravelParty(adults: 1, childAges: [1])
        let unlimited = Fixture.place("Piazza Maggiore")
        #expect(party.admits(unlimited))
        #expect(party.childBlocked(by: unlimited) == nil)
    }

    // MARK: - Nap window

    @Test("A nap holds the afternoon open only when somebody still naps")
    func napWindowRequiresAToddler() {
        let toddler = TravelParty(adults: 2, childAges: [3], accommodations: [.middaySleep])
        let teenager = TravelParty(adults: 2, childAges: [14], accommodations: [.middaySleep])
        let unaskedFor = TravelParty(adults: 2, childAges: [3])

        #expect(toddler.napWindow?.opensAt == MinuteOfDay(hour: 13))
        #expect(toddler.napWindow?.closesAt == MinuteOfDay(hour: 15))
        #expect(teenager.napWindow == nil)
        #expect(unaskedFor.napWindow == nil)
    }

    @Test("An afternoon stop inside the nap window is dropped")
    func napRemovesAfternoonStops() {
        // The Ferrari museum sits at 14:30, squarely inside a 13:00–15:00 nap.
        let party = TravelParty(adults: 2, childAges: [3], accommodations: [.middaySleep])
        let napping = places(for: party)
        let awake = places(for: TravelParty(adults: 2, childAges: [3]))

        #expect(awake.contains("Museo Enzo Ferrari"))
        #expect(!napping.contains("Museo Enzo Ferrari"))
    }

    // MARK: - Dinner

    @Test("Children pull dinner an hour earlier")
    func dinnerMovesEarlier() {
        #expect(TravelParty.couple.eveningMealStart == MinuteOfDay(hour: 19, minute: 30))
        #expect(TravelParty(adults: 2, childAges: [5]).eveningMealStart == MinuteOfDay(hour: 18, minute: 30))
    }

    @Test("The composed evening meal actually carries the earlier time")
    func composedDinnerIsEarlier() {
        let template = SampleItineraries.templates(for: bologna)[0]
        let family = SampleItineraries.blocks(from: template,
                                              brief: brief(party: TravelParty(adults: 2, childAges: [5])))
        let meal = family.first { $0.slot == .evening }?.items.first

        #expect(meal?.startsAt == MinuteOfDay(hour: 18, minute: 30))
    }

    // MARK: - Cost

    @Test("Party size drives what the tickets cost")
    func ticketsScaleWithTheParty() {
        // Torre degli Asinelli is 5 € a head with no child concession.
        #expect(TravelParty.solo.admissionCost(for: towerPlace)?.amount == 5)
        #expect(TravelParty.couple.admissionCost(for: towerPlace)?.amount == 10)
        #expect(TravelParty(adults: 2, childAges: [13, 14]).admissionCost(for: towerPlace)?.amount == 20)
    }

    @Test("A child under the concession age costs nothing")
    func youngChildrenEnterFree() {
        let museum = Fixture.place("Museum", admission: Admission(adultPrice: Money(20), freeUnderAge: 6))
        let party = TravelParty(adults: 2, childAges: [4, 8])

        #expect(party.admissionCost(for: museum)?.amount == 60)  // two adults + the eight-year-old
        #expect(party.childrenAdmittedFree(at: museum) == 1)
    }

    @Test("A free place has no cost to report")
    func freePlacesCostNothing() {
        #expect(TravelParty.couple.admissionCost(for: Fixture.place("Piazza")) == nil)
    }

    // MARK: - Effects panel

    @Test("The panel names the stop the party loses")
    func effectsNameTheDroppedStop() {
        let party = TravelParty(adults: 2, childAges: [4], accommodations: [.middaySleep, .pushchair])
        let candidates = SampleItineraries.candidatePlaces(for: bologna)
        let effects = TravelPartyEffects(party: party).effects(against: candidates)

        #expect(effects.contains(.stopDropped(place: "Torre degli Asinelli",
                                              minimumAge: 12,
                                              childAge: 4)))
        #expect(effects.contains(.dinnerMovedEarlier(to: MinuteOfDay(hour: 18, minute: 30))))
        #expect(effects.contains(.stepFreeOnly))
        #expect(effects.contains { if case .afternoonHeldForNap = $0 { return true } else { return false } })
    }

    @Test("A party with nothing to accommodate produces no noise")
    func couplesGetNoPanel() {
        let candidates = SampleItineraries.candidatePlaces(for: bologna)
        let effects = TravelPartyEffects(party: .couple).effects(against: candidates)

        #expect(!effects.contains { if case .stopDropped = $0 { return true } else { return false } })
        #expect(!effects.contains { if case .dinnerMovedEarlier = $0 { return true } else { return false } })
    }

    /// A dropped stop must never be cut by the summary cap: it is the only effect that
    /// takes something away.
    @Test("The summary always keeps the dropped stops")
    func summaryKeepsDroppedStops() {
        let party = TravelParty(adults: 2, childAges: [4], accommodations: Set(TravelParty.Accommodation.allCases))
        let candidates = SampleItineraries.candidatePlaces(for: bologna)
        let summary = TravelPartyEffects(party: party).summary(against: candidates, limit: 1)

        #expect(summary.contains { if case .stopDropped = $0 { return true } else { return false } })
    }

    @Test("Candidate places are de-duplicated across the day templates")
    func candidatesAreUnique() {
        let candidates = SampleItineraries.candidatePlaces(for: bologna)
        let ids = candidates.map(\.providerPlaceID)
        #expect(Set(ids).count == ids.count)
        #expect(candidates.contains { $0.name == "Torre degli Asinelli" })
    }

    private var towerPlace: Place {
        SampleItineraries.candidatePlaces(for: Identifier("bologna"))
            .first { $0.name == "Torre degli Asinelli" }!
    }
}
