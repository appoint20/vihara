import Testing
import Foundation
@testable import Vihara

@Suite("Talking to the offer service")
struct RemoteOfferServiceTests {

    private let date = Fixture.date(2026, 4, 14)

    // MARK: - What we ask for

    /// ADR-006: the request carries facts about the plan and never names a partner,
    /// a marker or a URL shape. Those are the service's decisions, which is what
    /// lets a programme be swapped without a release.
    @Test("A place request sends plan facts and nothing else")
    func placeQuery() {
        let query = RemoteOfferService.query(
            for: .place(providerPlaceID: "poi:bologna:asinelli",
                        name: "Torre degli Asinelli",
                        city: "Bologna",
                        requiresTicket: true,
                        on: date),
            context: OfferContext(tripID: Identifier("t1"), slot: .afternoon)
        )

        #expect(query["type"] == "place")
        #expect(query["place"] == "poi:bologna:asinelli")
        #expect(query["requires_ticket"] == "1")
        #expect(query["trip"] == "t1")
        #expect(query["slot"] == "afternoon")
        // No partner, no marker, no template.
        #expect(query["partner"] == nil)
        #expect(!query.values.contains { $0.contains("getyourguide") })
    }

    /// The traveller's Tuesday, not Greenwich's. Formatting a locally-constructed
    /// midnight in UTC moves the date back a day for everyone east of Greenwich,
    /// which would ask the service for tickets on the wrong day — this test caught
    /// exactly that.
    @Test("The date goes over as the traveller's own calendar day")
    func dateFormatting() {
        let query = RemoteOfferService.query(
            for: .place(providerPlaceID: "p", name: "n", city: "c", requiresTicket: false, on: date),
            context: .none,
            timeZone: TimeZone(identifier: "Europe/Berlin")!
        )
        #expect(query["date"] == "2026-04-14")
    }

    @Test("The same instant is a different calendar day on the other side of the date line")
    func dateIsZoneDependent() {
        func day(_ zone: String) -> String? {
            RemoteOfferService.query(
                for: .place(providerPlaceID: "p", name: "n", city: "c",
                            requiresTicket: false, on: date),
                context: .none,
                timeZone: TimeZone(identifier: zone)!
            )["date"]
        }
        #expect(day("Europe/Berlin") == "2026-04-14")
        #expect(day("UTC") == "2026-04-13")
    }

    @Test("Transfer and trip requests carry their own facts")
    func otherQueries() {
        let transfer = RemoteOfferService.query(
            for: .transfer(origin: "Bologna", destination: "Ravenna"), context: .none
        )
        #expect(transfer["type"] == "transfer")
        #expect(transfer["destination"] == "Ravenna")

        let trip = RemoteOfferService.query(for: .trip(city: "Bologna", nights: 3), context: .none)
        #expect(trip["type"] == "trip")
        #expect(trip["nights"] == "3")
    }

    @Test("A surface with nothing to attribute still asks")
    func contextIsOptional() {
        let query = RemoteOfferService.query(for: .trip(city: "Bologna", nights: 2), context: .none)
        #expect(query["trip"] == nil)
        #expect(query["slot"] == nil)
        #expect(query["type"] == "trip")
    }

    // MARK: - What we accept back

    private func dto(partner: String = "getYourGuide",
                     kind: String = "ticket",
                     low: Decimal? = 18,
                     high: Decimal? = 32,
                     url: String = "https://offers.vihara.app/go/abc") -> OfferDTO {
        OfferDTO(id: "getYourGuide:ticket:sub1", partner: partner, kind: kind,
                 priceLow: low, priceHigh: high, currency: "EUR", url: URL(string: url)!)
    }

    @Test("A well-formed offer maps to the domain")
    func mapsAnOffer() throws {
        let offer = try #require(dto().offer)

        #expect(offer.partner == .getYourGuide)
        #expect(offer.kind == .ticket)
        #expect(offer.priceBand?.low.amount == 18)
        #expect(offer.priceBand?.high?.amount == 32)
        #expect(offer.url.absoluteString == "https://offers.vihara.app/go/abc")
    }

    /// The service deploys in seconds; the app takes days through review. It *will*
    /// be ahead, and one unknown partner must not empty the whole list.
    @Test("A partner or kind this build does not know is dropped, not fatal")
    func unknownsAreDropped() {
        #expect(dto(partner: "someNewPartner").offer == nil)
        #expect(dto(kind: "helicopter").offer == nil)
        // The known ones in the same response still come through.
        let list = [dto(partner: "someNewPartner"), dto()]
        #expect(list.compactMap(\.offer).count == 1)
    }

    /// `SFSafariViewController` traps on a scheme it cannot load, so the check
    /// belongs at the boundary rather than at the crash site.
    @Test("A URL the client cannot open is refused")
    func refusesUnopenableURLs() {
        #expect(dto(url: "javascript:alert(1)").offer == nil)
        #expect(dto(url: "vihara://offer").offer == nil)
        #expect(dto(url: "http://offers.vihara.app/go/abc").offer != nil)
    }

    @Test("A price band collapses to open-ended when there is no upper figure")
    func priceBands() throws {
        #expect(try #require(dto(low: 9, high: nil).offer).priceBand?.high == nil)
        // A high that is not above the low is not a band.
        #expect(try #require(dto(low: 9, high: 9).offer).priceBand?.high == nil)
        #expect(dto(low: nil, high: nil).offer?.priceBand == nil)
    }

    /// The whole point of the service: what comes back is opaque and carries no
    /// marker. A response that did would mean the service had been written wrong.
    @Test("Nothing in a decoded offer carries an affiliate marker")
    func noMarkersComeBack() throws {
        let offer = try #require(dto().offer)
        let text = offer.url.absoluteString.lowercased()
        for marker in ["aid=", "partner_id=", "pid=", "awc=", "utm_source="] {
            #expect(!text.contains(marker))
        }
    }

    @Test("The response envelope decodes with the client's own decoder")
    func decodesTheEnvelope() throws {
        let json = """
        {"offers":[{"id":"a","partner":"booking","kind":"lodging","price_low":68,
                    "price_high":null,"currency":"EUR","url":"https://offers.vihara.app/go/x"}]}
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let list = try decoder.decode(OfferListDTO.self, from: Data(json.utf8))

        #expect(list.offers.count == 1)
        let offer = try #require(list.offers.first?.offer)
        #expect(offer.partner == .booking)
        #expect(offer.priceBand?.low.amount == 68)
    }
}
