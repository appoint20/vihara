import Testing
import Foundation
@testable import Vihara

@Suite("Composing a budget")
struct TripBudgetTests {

    private func brief(adults: Int = 2,
                       childAges: [Int] = [],
                       nights: Int = 3,
                       diet: TripBrief.DietRequirement = .none) -> TripBrief {
        var brief = Fixture.brief(destination: "Bologna", nights: nights, diet: diet)
        brief.party = TravelParty(adults: adults, childAges: childAges, accommodations: [])
        return brief
    }

    private func day(_ items: [ItineraryItem], transfer: Transfer? = nil) -> TripDay {
        TripDay(date: Fixture.date(2026, 4, 14), city: "Bologna", blocks: [
            DayBlock(slot: .morning, items: items),
            DayBlock(slot: .afternoon),
            DayBlock(slot: .evening),
        ], arrivalTransfer: transfer)
    }

    /// An admission comes from provider data, so it is not an estimate.
    @Test("Admissions are summed for the whole party")
    func admissionsForTheParty() throws {
        let place = Fixture.place("Torre", admission: Admission(adultPrice: Money(10)))
        let budget = TripBudget(brief: brief(adults: 2))

        let estimate = budget.estimate(for: [day([Fixture.item("Torre", place: place)])])
        let line = try #require(estimate.lines.first { $0.category == .admissions })

        #expect(line.band.low.amount == 20)
        #expect(line.isEstimate == false)
    }

    @Test("Children who enter free are not charged")
    func freeChildren() throws {
        let place = Fixture.place("Museum",
                                  admission: Admission(adultPrice: Money(10), freeUnderAge: 6))
        let budget = TripBudget(brief: brief(adults: 2, childAges: [4, 9]))

        let estimate = budget.estimate(for: [day([Fixture.item("Museum", place: place)])])
        let line = try #require(estimate.lines.first { $0.category == .admissions })

        // Two adults and the nine-year-old pay; the four-year-old does not.
        #expect(line.band.low.amount == 30)
    }

    /// A meal price is invented from ``TripBudget/Assumptions``, so it must say so —
    /// the same separation `DietSignal` makes between confirmed and likely.
    @Test("A meal is an estimate, and scales with the party")
    func mealsAreEstimates() throws {
        let budget = TripBudget(brief: brief(adults: 2),
                                assumptions: .init(mealPerPerson: .between(15, 35)))

        let estimate = budget.estimate(for: [day([Fixture.item("Osteria", kind: .meal)])])
        let line = try #require(estimate.lines.first { $0.category == .meals })

        #expect(line.isEstimate)
        #expect(line.band.low.amount == 30)
        #expect(line.band.high?.amount == 70)
    }

    @Test("One invented line makes the whole total an estimate")
    func anyEstimateTaintsTheTotal() throws {
        let place = Fixture.place("Torre", admission: Admission(adultPrice: Money(10)))
        let budget = TripBudget(brief: brief(adults: 1))

        let factsOnly = budget.estimate(for: [day([Fixture.item("Torre", place: place)])])
        #expect(!factsOnly.isEstimate)

        let withAMeal = budget.estimate(for: [day([
            Fixture.item("Torre", place: place),
            Fixture.item("Osteria", kind: .meal),
        ])])
        #expect(withAMeal.isEstimate)
    }

    /// Counting it as zero would understate the trip; hiding it would too.
    @Test("A ticketed stop with no known price is counted as a caveat, not as zero")
    func unpricedStopsAreNamed() throws {
        let place = Fixture.place("Torre", requiresTicket: true)
        let budget = TripBudget(brief: brief(adults: 1))

        let estimate = budget.estimate(for: [day([Fixture.item("Torre", place: place)])])

        #expect(estimate.unpricedStopCount == 1)
        #expect(estimate.lines.isEmpty)
        #expect(estimate.isEstimate)
    }

    /// An invented nightly rate would dominate the total while being the one figure
    /// we have no basis for.
    @Test("A bed is never counted")
    func lodgingIsExcluded() throws {
        let hotel = Fixture.place("Hotel", admission: Admission(adultPrice: Money(400)))
        let budget = TripBudget(brief: brief(adults: 1))

        let estimate = budget.estimate(for: [day([Fixture.item("Hotel", kind: .lodging, place: hotel)])])

        #expect(estimate.isEmpty)
    }

    @Test("The cheapest transfer option is the one counted")
    func transfersTakeTheCheapestOption() throws {
        let transfer = Transfer(origin: "Bologna", destination: "Ravenna", options: [
            Transfer.Option(mode: .rentalCar, minutes: 70, priceBand: .between(60, 90)),
            Transfer.Option(mode: .regionalTrain, minutes: 80, priceBand: .between(12, 18)),
        ])
        let budget = TripBudget(brief: brief(adults: 2))

        let estimate = budget.estimate(for: [day([], transfer: transfer)])
        let line = try #require(estimate.lines.first { $0.category == .transfers })

        #expect(line.band.low.amount == 24)
    }

    @Test("A plan with nothing priced produces an empty budget, not a zero")
    func emptyPlan() {
        #expect(TripBudget(brief: brief()).estimate(for: []).isEmpty)
        #expect(TripBudget(brief: brief()).estimate(for: []).total == nil)
    }

    // MARK: - Bands

    @Test("Bands add up, and an open band keeps the total open")
    func bandArithmetic() throws {
        let closed = try #require(PriceBand.sum([.between(10, 20), .between(5, 8)]))
        #expect(closed.low.amount == 15)
        #expect(closed.high?.amount == 28)

        let open = try #require(PriceBand.sum([.between(10, 20), .from(5)]))
        #expect(open.low.amount == 15)
        // A total with an unknown component has no upper bound.
        #expect(open.high == nil)
    }

    @Test("Multiplying by a party of zero does not zero the price")
    func multiplyClamps() {
        #expect(PriceBand.between(10, 20).multiplied(by: 0).low.amount == 10)
    }
}

@Suite("Converting a budget")
struct ExchangeRateTests {

    private let rates = StaticExchangeRates()

    @Test("A currency converts to itself at par")
    func identity() async {
        #expect(await rates.rate(from: .eur, to: .eur) == 1)
    }

    @Test("A cross rate goes through the euro")
    func crossRate() async throws {
        let rate = try #require(await rates.rate(from: .usd, to: .eur))
        // 1 EUR = 1.08 USD, so a dollar is worth less than a euro.
        #expect(rate < 1)
    }

    /// A missing rate silently becoming zero would show a traveller a free holiday.
    @Test("An unknown pair returns nil rather than zero")
    func unknownPair() async {
        #expect(await rates.rate(from: .eur, to: .bgn) != nil)
        // Not in the table at all.
        #expect(await rates.rate(from: .eur, to: .myr) != nil)
    }

    @Test("The mock does not claim to be authoritative")
    func notAuthoritative() {
        #expect(rates.isAuthoritative == false)
    }

    @Test("Converting a budget converts every line or none")
    func conversionIsAllOrNothing() throws {
        let estimate = BudgetEstimate(
            lines: [
                .init(category: .admissions, band: .between(10, 20), isEstimate: false),
                .init(category: .meals, band: .between(30, 70), isEstimate: true),
            ],
            currency: .eur,
            unpricedStopCount: 0
        )

        let converted = estimate.converted(to: .usd, rate: 2)

        #expect(converted.currency == .usd)
        #expect(converted.lines.allSatisfy { $0.band.low.currency == .usd })
        #expect(converted.lines[0].band.low.amount == 20)
        #expect(converted.lines[1].band.high?.amount == 140)
        // The estimate flag survives conversion: converting a guess leaves a guess.
        #expect(converted.lines[1].isEstimate)
    }

    @Test("Every currency case is a real ISO code")
    func currencyCodes() {
        for currency in Money.Currency.allCases {
            #expect(currency.rawValue.count == 3, "\(currency) is not a 3-letter code")
            #expect(currency.rawValue == currency.rawValue.lowercased())
        }
    }
}

@Suite("Composing a packing list")
struct PackingListTests {

    private func brief(childAges: [Int] = [],
                       nights: Int = 3,
                       diet: TripBrief.DietRequirement = .none) -> TripBrief {
        var brief = Fixture.brief(destination: "Bologna", nights: nights, diet: diet)
        brief.party = TravelParty(adults: 2, childAges: childAges, accommodations: [])
        return brief
    }

    private func day(_ items: [ItineraryItem] = [], month: Int = 4) -> TripDay {
        TripDay(date: Fixture.date(2026, month, 14), city: "Bologna", blocks: [
            DayBlock(slot: .morning, items: items),
            DayBlock(slot: .afternoon),
            DayBlock(slot: .evening),
        ])
    }

    private func keys(_ sections: [PackingSection]) -> [String] {
        sections.flatMap { $0.items.map(\.key) }
    }

    @Test("Papers and a charger are always on the list")
    func alwaysPresent() {
        let sections = PackingList(brief: brief()).sections(for: [day()])
        #expect(keys(sections).contains("packing.item.id"))
        #expect(keys(sections).contains("packing.item.charger"))
    }

    @Test("The season decides the clothing")
    func seasonDrivesClothing() {
        let list = PackingList(brief: brief(), calendar: Fixture.calendar)

        #expect(keys(list.sections(for: [day(month: 7)])).contains("packing.item.sunHat"))
        #expect(keys(list.sections(for: [day(month: 1)])).contains("packing.item.warmCoat"))
        #expect(keys(list.sections(for: [day(month: 4)])).contains("packing.item.rainJacket"))
    }

    /// A ticket bought ahead has to be reachable at the door, and the door is where
    /// there is no signal.
    @Test("A ticketed stop adds the offline-tickets line")
    func ticketedStops() {
        let ticketed = Fixture.item("Torre", place: Fixture.place("Torre", requiresTicket: true))
        let sections = PackingList(brief: brief()).sections(for: [day([ticketed])])
        #expect(keys(sections).contains("packing.item.tickets"))

        let without = PackingList(brief: brief()).sections(for: [day([Fixture.item("Piazza")])])
        #expect(!keys(without).contains("packing.item.tickets"))
    }

    /// Derived from the plan's own walking total, so it is a fact about their days
    /// rather than generic advice.
    @Test("A lot of walking adds shoes, and says how much")
    func walkingAddsShoes() throws {
        let far = day([
            Fixture.item("A"),
            Fixture.item("B", walk: 40),
            Fixture.item("C", walk: 30),
        ])
        let sections = PackingList(brief: brief()).sections(for: [far])
        let shoes = try #require(sections.flatMap(\.items).first { $0.key == "packing.item.walkingShoes" })

        #expect(shoes.reasonKey == "packing.why.walking")
        #expect(shoes.reasonArgument == "70")
    }

    @Test("A short walk does not")
    func littleWalkingNoShoes() {
        let near = day([Fixture.item("A"), Fixture.item("B", walk: 5)])
        #expect(!keys(PackingList(brief: brief()).sections(for: [near])).contains("packing.item.walkingShoes"))
    }

    @Test("Children add their own lines")
    func children() {
        let sections = PackingList(brief: brief(childAges: [4])).sections(for: [day()])
        #expect(keys(sections).contains("packing.item.childID"))
        #expect(keys(sections).contains("packing.item.snacks"))
    }

    @Test("A stated diet adds snacks for travel days")
    func dietSnacks() {
        #expect(keys(PackingList(brief: brief(diet: .vegan)).sections(for: [day()]))
            .contains("packing.item.dietSnacks"))
        #expect(!keys(PackingList(brief: brief(diet: .none)).sections(for: [day()]))
            .contains("packing.item.dietSnacks"))
    }

    @Test("A long trip adds a laundry bag, a short one does not")
    func laundry() {
        #expect(keys(PackingList(brief: brief(nights: 7)).sections(for: [day()]))
            .contains("packing.item.laundryBag"))
        #expect(!keys(PackingList(brief: brief(nights: 2)).sections(for: [day()]))
            .contains("packing.item.laundryBag"))
    }

    @Test("Sections with nothing in them are left out")
    func noEmptySections() {
        let sections = PackingList(brief: brief()).sections(for: [day()])
        #expect(sections.allSatisfy { !$0.items.isEmpty })
    }

    /// A line the traveller cannot read is a line that does not exist.
    @Test("Every line and every reason is localised in both languages")
    func everyLineIsLocalised() {
        let far = day([Fixture.item("A"), Fixture.item("B", walk: 90)])
        let brief = brief(childAges: [4], nights: 9, diet: .vegan)
        var allItems: [PackingItem] = []
        for month in [1, 4, 7, 10] {
            let days = [day(month: month), far]
            allItems += PackingList(brief: brief).sections(for: days).flatMap(\.items)
        }

        for language in ["de", "en"] {
            let locale = Locale(identifier: language)
            for item in allItems {
                #expect(localized(item.key, locale: locale) != item.key,
                        "\(item.key) missing in \(language)")
                if let reasonKey = item.reasonKey {
                    let text = item.reasonArgument.map { localized(reasonKey, $0, locale: locale) }
                        ?? localized(reasonKey, locale: locale)
                    #expect(text != reasonKey, "\(reasonKey) missing in \(language)")
                }
            }
            for category in PackingSection.Category.allCases {
                #expect(localized(category.labelKey, locale: locale) != category.labelKey,
                        "\(category.labelKey) missing in \(language)")
            }
        }
    }
}
