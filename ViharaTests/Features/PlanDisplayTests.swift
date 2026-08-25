import Testing
@testable import Vihara

/// The word "bestätigt" is a promise, not a label.
///
/// PRD 6.5 allows it only for stage 1 and 2 evidence — a provider attribute or the
/// venue's own structured menu. Review-text inference is a weak signal and must read
/// differently. These tests exist so that promise cannot be weakened by an edit to a
/// `switch` somewhere.
@Suite("Diet badge wording")
struct PlanDisplayTests {

    @Test("Provider-grade evidence earns the word bestätigt")
    func confirmedEarnsTheWord() {
        let attribute = DietSignal.confirmed(.vegetarian, source: .providerAttribute)
        let menu = DietSignal.confirmed(.vegan, source: .venueMenu)

        #expect(attribute.badge?.text == "vegetarisch bestätigt")
        #expect(attribute.badge?.isConfirmed == true)
        #expect(menu.badge?.text == "vegan bestätigt")
        #expect(menu.badge?.isConfirmed == true)
    }

    @Test("Inferred evidence never says bestätigt")
    func likelyNeverClaimsConfirmation() {
        for signal in [DietSignal.likely(.vegetarian), .likely(.vegan)] {
            let badge = try? #require(signal.badge)
            #expect(badge?.isConfirmed == false)
            #expect(badge?.text.contains("wahrscheinlich") == true)
            #expect(badge?.text.contains("bestätigt") == false)
        }
    }

    @Test("Nothing to say means no badge, not a reassuring one")
    func absentEvidenceShowsNothing() {
        #expect(DietSignal.unknown.badge == nil)
        #expect(DietSignal.notApplicable.badge == nil)
    }

    /// Guards the downgrade made while the plan runs on hand-written data: the stub
    /// asserts no provider-grade evidence, because it has none. Restoring a
    /// `.confirmed` signal here should be a deliberate act that fails this test
    /// first — and it must happen in the same change that turns on live validation.
    @Test("The shipped stub claims no evidence it does not have")
    func stubDataMakesNoConfirmedClaims() {
        let places = PilotDestinationCatalogue.curated
            .flatMap { SampleItineraries.templates(for: $0.id) }
            .flatMap { $0.morning + $0.afternoon + $0.eveningMeals + $0.eveningExtras }
            .map(\.place)

        #expect(!places.isEmpty)
        for place in places {
            if case .confirmed = place.dietSignal {
                let message = "\(place.name) claims a confirmed diet signal, but nothing in the pilot data has been read from a provider or a menu"
                Issue.record(Comment(rawValue: message))
            }
        }
    }
}
