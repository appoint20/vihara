import Testing
import Foundation
@testable import Vihara

/// Intake parsing (F-01).
///
/// The bar is not linguistic sophistication: it is that the traveller's sentence is
/// never lost and never silently misread. Anything unrecognised must fall back to a
/// stated default they can see and correct.
@Suite("Trip brief parsing")
struct HeuristicTripBriefParserTests {

    private let today = Fixture.date(2026, 3, 10)

    private func parser(leadDays: Int = 21) -> HeuristicTripBriefParser {
        HeuristicTripBriefParser(catalogue: PilotDestinationCatalogue(),
                                 calendar: Fixture.calendar,
                                 defaultLeadDays: leadDays)
    }

    @Test("The PRD's own example sentence parses completely")
    func canonicalSentence() async throws {
        let brief = try await parser().parse("5 Tage Bologna, vegetarisch, entspanntes Tempo, Mittelklasse",
                                             relativeTo: today)

        #expect(brief.destination == "Bologna")
        #expect(brief.nights == 4)          // 5 days away is 4 nights
        #expect(brief.dayCount == 5)
        #expect(brief.diet == .vegetarian)
        #expect(brief.pace == .relaxed)
        #expect(brief.budget == .middle)
        #expect(brief.sourceText == "5 Tage Bologna, vegetarisch, entspanntes Tempo, Mittelklasse")
    }

    @Test("Nights are read directly when the traveller counts them")
    func nightsAreReadDirectly() async throws {
        let brief = try await parser().parse("3 Nächte in Modena", relativeTo: today)
        #expect(brief.nights == 3)
    }

    @Test("A weekend is two nights and a week is six")
    func namedDurations() async throws {
        let weekend = try await parser().parse("Wochenende in Ravenna", relativeTo: today)
        let week = try await parser().parse("eine Woche Bologna", relativeTo: today)
        #expect(weekend.nights == 2)
        #expect(week.nights == 6)
    }

    @Test("Vegan is not read as vegetarian")
    func veganIsDistinct() async throws {
        let vegan = try await parser().parse("Bologna, vegan", relativeTo: today)
        let vegetarian = try await parser().parse("Bologna, vegetarisch", relativeTo: today)
        let unstated = try await parser().parse("Bologna", relativeTo: today)
        #expect(vegan.diet == .vegan)
        #expect(vegetarian.diet == .vegetarian)
        #expect(unstated.diet == .none)
    }

    @Test("Umlauts and case do not defeat matching")
    func foldedMatching() async throws {
        let brief = try await parser().parse("4 nächte bologna, gemütliches tempo", relativeTo: today)

        #expect(brief.destination == "Bologna")
        #expect(brief.nights == 4)
        #expect(brief.pace == .relaxed)
    }

    /// The end-to-end case above can only use a curated destination, and none of the
    /// three Emilia-Romagna cities carries an accent. Folding is tested directly so
    /// the capability stays covered for the day San Sebastián is promoted out of
    /// ``PilotDestinationCatalogue/awaitingCuration``.
    @Test("Folding strips accents from a destination name")
    func foldingStripsAccents() {
        #expect(PilotDestinationCatalogue.fold("San Sebastián") == "san sebastian")
        #expect(PilotDestinationCatalogue.fold("  Reykjavík ") == "reykjavik")
        #expect(PilotDestinationCatalogue.fold("Nächte") == "nachte")
    }

    @Test("A region name resolves to a destination inside it")
    func regionMatching() async throws {
        let brief = try await parser().parse("5 Tage Emilia-Romagna", relativeTo: today)
        #expect(!brief.destination.isEmpty)
    }

    @Test("An uncovered destination yields an empty one rather than a guess")
    func unknownDestination() async throws {
        let brief = try await parser().parse("4 Tage Reykjavík, vegan", relativeTo: today)

        // We would rather admit we do not cover Iceland than plan it badly.
        #expect(brief.destination.isEmpty)
        #expect(!brief.isGeneratable)
        // Everything else the sentence said still survives.
        #expect(brief.diet == .vegan)
        #expect(brief.nights == 3)
    }

    @Suite("Dates")
    struct Dates {
        private let today = Fixture.date(2026, 3, 10)

        private var parser: HeuristicTripBriefParser {
            HeuristicTripBriefParser(catalogue: PilotDestinationCatalogue(),
                                     calendar: Fixture.calendar,
                                     defaultLeadDays: 21)
        }

        @Test("An explicit day and month is taken literally")
        func explicitDate() async throws {
            let brief = try await parser.parse("Bologna ab 14. April", relativeTo: today)

            #expect(brief.startDate == Fixture.date(2026, 4, 14))
        }

        @Test("A month already past means next year")
        func monthRollsOver() async throws {
            let brief = try await parser.parse("Bologna im Februar", relativeTo: today)

            #expect(brief.startDate == Fixture.date(2027, 2, 1))
        }

        @Test("Relative dates are understood")
        func relativeDates() async throws {
            let tomorrow = try await parser.parse("Bologna morgen", relativeTo: today)
            let nextWeek = try await parser.parse("Bologna nächste Woche", relativeTo: today)
            #expect(tomorrow.startDate == Fixture.date(2026, 3, 11))
            #expect(nextWeek.startDate == Fixture.date(2026, 3, 17))
        }

        @Test("No date at all lands far enough out to be plannable")
        func fallbackLead() async throws {
            let brief = try await parser.parse("Bologna", relativeTo: today)
            #expect(brief.startDate == Fixture.date(2026, 3, 31))
        }
    }
}
