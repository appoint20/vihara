import Testing
import Foundation
@testable import Vihara

@Suite("What the mock offer service answers")
struct StubOfferProviderTests {

    private let provider = StubOfferProvider()

    private func placeRequest(name: String = "Torre degli Asinelli",
                              city: String = "Bologna",
                              requiresTicket: Bool) -> OfferRequest {
        .place(providerPlaceID: "test:\(name)",
               name: name,
               city: city,
               requiresTicket: requiresTicket,
               on: Fixture.date(2026, 4, 14))
    }

    /// `Place.requiresTicket` is documented as "surfaced as a warning, not a booking
    /// button". This is that warning becoming an offer — the cheapest monetisation
    /// change in the product (`docs/MONETISATION.md` §2).
    @Test("A ticketed place is offered a ticket")
    func ticketedPlaceGetsAnOffer() async throws {
        let offers = try await provider.offers(for: placeRequest(requiresTicket: true))

        #expect(offers.count == 1)
        #expect(offers.first?.kind == .ticket)
        #expect(offers.first?.partner == .getYourGuide)
        #expect(offers.first?.priceBand != nil)
    }

    @Test("A place that needs no ticket is offered nothing")
    func unticketedPlaceGetsNothing() async throws {
        #expect(try await provider.offers(for: placeRequest(requiresTicket: false)).isEmpty)
    }

    @Test("A transfer is offered a train and a door-to-door pickup")
    func transferOffers() async throws {
        let offers = try await provider.offers(for: .transfer(origin: "Bologna",
                                                              destination: "Ravenna"))
        #expect(offers.map(\.kind) == [.rail, .transfer])
        #expect(offers.map(\.partner) == [.trainline, .welcomePickups])
    }

    @Test("The trip as a whole is offered a bed and data")
    func tripOffers() async throws {
        let offers = try await provider.offers(for: .trip(city: "Bologna", nights: 3))
        #expect(offers.map(\.kind) == [.lodging, .esim])
        #expect(offers.map(\.partner) == [.booking, .airalo])
    }

    /// The central product conclusion in `docs/MONETISATION.md` §2: people book a
    /// bed before they plan their days, so a bed offered beside "Vormittag:
    /// Uffizien" is offered to somebody who booked one weeks ago. Lodging belongs to
    /// intake and nowhere else.
    @Test("A bed is never offered inside a day")
    func lodgingIsNeverOfferedInsideADay() async throws {
        let inDay = try await provider.offers(for: placeRequest(requiresTicket: true))
            + (try await provider.offers(for: .transfer(origin: "A", destination: "B")))

        #expect(!inDay.contains { $0.kind == .lodging })
    }

    /// `SFSafariViewController` traps on a scheme it cannot load, and these URLs are
    /// the only ones in the app a traveller is handed.
    @Test("Every offer URL is https")
    func everyURLIsHTTPS() async throws {
        var all: [BookableOffer] = []
        all += try await provider.offers(for: placeRequest(requiresTicket: true))
        all += try await provider.offers(for: .transfer(origin: "Bologna", destination: "Ravenna"))
        all += try await provider.offers(for: .trip(city: "Bologna", nights: 2))

        #expect(!all.isEmpty)
        #expect(all.allSatisfy { $0.url.scheme == "https" })
        #expect(all.allSatisfy { $0.url.host?.isEmpty == false })
    }

    /// The stub must not pretend to hold an affiliate account it has not been
    /// approved for. A marker here would be a fabricated tracking parameter that
    /// earns nothing and misrepresents the integration.
    @Test("The mock links carry no affiliate marker")
    func noFabricatedAffiliateMarkers() async throws {
        var all: [BookableOffer] = []
        all += try await provider.offers(for: placeRequest(requiresTicket: true))
        all += try await provider.offers(for: .transfer(origin: "Bologna", destination: "Ravenna"))
        all += try await provider.offers(for: .trip(city: "Bologna", nights: 2))

        // The parameter names every travel network keys attribution on.
        let markers = ["aid=", "marker=", "partner_id=", "affiliate", "utm_", "sid=", "cmp="]
        for offer in all {
            let query = (offer.url.query ?? "").lowercased()
            for marker in markers {
                #expect(!query.contains(marker),
                        "\(offer.partner.displayName) carries \(marker)")
            }
        }
    }

    @Test("Every partner spells its own name")
    func partnersHaveNames() {
        #expect(AffiliatePartner.allCases.allSatisfy { !$0.displayName.isEmpty })
        #expect(AffiliatePartner.getYourGuide.displayName == "GetYourGuide")
    }
}

@Suite("Offers on the plan screen")
@MainActor
struct PlanOfferTests {

    private let brief = Fixture.brief(destination: "Bologna", nights: 2)

    private func ticketedDay() -> TripDay {
        TripDay(date: Fixture.date(2026, 4, 14), city: "Bologna", blocks: [
            DayBlock(slot: .morning, items: [
                Fixture.item("Torre", place: Fixture.place("Torre", requiresTicket: true)),
            ]),
            DayBlock(slot: .afternoon, items: [
                Fixture.item("Piazza", place: Fixture.place("Piazza")),
            ]),
            DayBlock(slot: .evening),
        ])
    }

    private func model(offerProvider: (any OfferProviding)?,
                       clickReporter: (any OfferClickReporting)? = nil,
                       day: TripDay) -> PlanViewModel {
        let generator = ScriptedTripGenerator(events: [
            .accepted(tripID: Identifier("t1"), expectedDays: 1),
            .dayReady(day),
            .completed,
        ])
        return PlanViewModel(brief: brief,
                             generateTrip: GenerateTrip(generator: generator,
                                                        trips: InMemoryTripRepository(),
                                                        wallets: StubWalletRepository()),
                             offerProvider: offerProvider,
                             clickReporter: clickReporter)
    }

    /// **App Store guideline 4.2.2.** "Apps shouldn't primarily be marketing
    /// materials, advertisements, web clippings, content aggregators, or a collection
    /// of links." The plan is the product and offers are additive, so the plan must
    /// be whole without them — offline, with the service down, or with no affiliate
    /// account at all.
    @Test("A plan with no offer service is still a complete plan")
    func planIsCompleteWithoutOffers() async throws {
        let day = ticketedDay()
        let model = model(offerProvider: nil, day: day)
        model.startIfNeeded()
        try await eventually("the plan finishes") { model.phase == .ready }

        #expect(model.days.count == 1)
        #expect(model.phase == .ready)
        #expect(model.offersByItem.isEmpty)
        #expect(model.days.first?.itemCount == 2)
    }

    /// An offer that does not arrive must leave the plan reading exactly as it
    /// should. An error about a missing advertisement would be the app complaining it
    /// could not show the traveller an ad.
    @Test("A failing offer service is silent, not an error")
    func failingOfferServiceIsSilent() async throws {
        let model = model(offerProvider: FailingOffers(), day: ticketedDay())
        model.startIfNeeded()
        try await eventually("the plan finishes") { model.phase == .ready }

        #expect(model.phase == .ready)
        #expect(model.offersByItem.isEmpty)
        #expect(model.days.count == 1)
    }

    @Test("A ticketed stop gets its offer, an ordinary stop does not")
    func offersLandOnTheRightStop() async throws {
        let day = ticketedDay()
        let model = model(offerProvider: StubOfferProvider(), day: day)
        model.startIfNeeded()
        try await eventually("the ticket offer arrives") { !model.offersByItem.isEmpty }

        let ticketed = try #require(day.blocks[0].items.first)
        let ordinary = try #require(day.blocks[1].items.first)

        #expect(model.offers(for: ticketed).count == 1)
        #expect(model.offers(for: ticketed).first?.kind == .ticket)
        #expect(model.offers(for: ordinary).isEmpty)
    }

    @Test("Opening an offer presents it and reports the click")
    func openReportsTheClick() async throws {
        let reporter = RecordingClickReporter()
        let model = model(offerProvider: StubOfferProvider(),
                          clickReporter: reporter,
                          day: ticketedDay())
        let offer = BookableOffer(partner: .getYourGuide,
                                  kind: .ticket,
                                  url: URL(string: "https://www.getyourguide.com/s?q=Bologna")!)
        model.open(offer)

        #expect(model.presentedOffer == offer)
        try await eventually("the click is reported") { await reporter.clicked == [offer.id] }
    }

    /// A URL the client cannot open is a service bug. It must not become a crash in
    /// front of the traveller, and it must not be counted as a hand-off that happened.
    @Test("An offer with an unopenable scheme is refused and not counted")
    func unopenableSchemeIsRefused() async throws {
        let reporter = RecordingClickReporter()
        let model = model(offerProvider: StubOfferProvider(),
                          clickReporter: reporter,
                          day: ticketedDay())
        model.open(BookableOffer(partner: .booking,
                                 kind: .lodging,
                                 url: URL(string: "javascript:alert(1)")!))

        #expect(model.presentedOffer == nil)
        // Nothing to wait for, so give a real reporter time to wrongly fire.
        try await Task.sleep(for: .milliseconds(50))
        #expect(await reporter.clicked.isEmpty)
    }

    /// The marking is a legal obligation (§5a UWG) and a contractual one, so it must
    /// resolve to real words in every language the app ships.
    @Test("The paid-placement marker is localised, not a leaked key")
    func disclosureIsLocalised() {
        for language in ["de", "en"] {
            let locale = Locale(identifier: language)
            let text = localized(AffiliateDisclosure.labelKey, locale: locale)
            #expect(text != AffiliateDisclosure.labelKey, "\(language) has no disclosure string")
            #expect(!text.isEmpty)
        }
    }

    @Test("Every offer kind has a label in every language")
    func everyKindIsLocalised() {
        for kind in BookableOffer.Kind.allCases {
            for language in ["de", "en"] {
                let text = localized(kind.labelKey, locale: Locale(identifier: language))
                #expect(text != kind.labelKey, "\(kind.rawValue) has no \(language) label")
            }
        }
    }
}

/// Proves the *shipped* demo produces offers, which no unit test with a hand-made
/// fixture can. A booking surface that works against invented data and never fires
/// against the sample itinerary is a surface nobody will see.
@Suite("Offers against the shipped sample data")
@MainActor
struct SampleDataOfferTests {

    @Test("A generated Bologna plan surfaces at least one ticket offer")
    func sampleItineraryProducesOffers() async throws {
        let catalogue = PilotDestinationCatalogue()
        let brief = Fixture.brief(destination: "Bologna", nights: 3)
        let model = PlanViewModel(
            brief: brief,
            generateTrip: GenerateTrip(generator: StubTripGenerator(catalogue: catalogue),
                                       trips: InMemoryTripRepository(),
                                       wallets: StubWalletRepository()),
            offerProvider: StubOfferProvider()
        )

        model.startIfNeeded()
        try await eventually("the plan finishes") { model.phase == .ready }
        try await eventually("an offer arrives") { !model.offersByItem.isEmpty }

        let offers = model.offersByItem.values.flatMap { $0 }
        #expect(offers.allSatisfy { $0.kind == .ticket })
        #expect(offers.allSatisfy { $0.partner == .getYourGuide })

        // Every stop that carries an offer is one that genuinely needs a ticket.
        let ticketedIDs = Set(model.days
            .flatMap { $0.blocks.flatMap(\.items) }
            .filter(\.place.requiresTicket)
            .map(\.id))
        #expect(Set(model.offersByItem.keys).isSubset(of: ticketedIDs))
    }

    /// The budget has to do something real on the shipped data too — several Bologna
    /// stops carry an admission, so the breakdown cannot come back empty.
    @Test("A generated plan produces a non-empty budget")
    func sampleItineraryProducesABudget() async throws {
        let catalogue = PilotDestinationCatalogue()
        let brief = Fixture.brief(destination: "Bologna", nights: 3)
        let model = PlanViewModel(
            brief: brief,
            generateTrip: GenerateTrip(generator: StubTripGenerator(catalogue: catalogue),
                                       trips: InMemoryTripRepository(),
                                       wallets: StubWalletRepository())
        )

        model.startIfNeeded()
        try await eventually("the plan finishes") { model.phase == .ready }

        #expect(!model.budget.isEmpty)
        #expect(model.budget.total != nil)
        #expect(!model.packing.isEmpty)
    }
}

private struct FailingOffers: OfferProviding {
    func offers(for request: OfferRequest, context: OfferContext) async throws -> [BookableOffer] {
        throw DomainError.connectionFailed
    }
}

private actor RecordingClickReporter: OfferClickReporting {
    var clicked: [Identifier<BookableOffer>] = []
    func reportClick(on offer: BookableOffer) async {
        clicked.append(offer.id)
    }
}
