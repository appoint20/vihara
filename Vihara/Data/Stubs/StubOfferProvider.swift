import Foundation

/// Offers, mocked.
///
/// Stands in for the offer service so the booking surface can be built, demoed and
/// reviewed before a single affiliate programme has approved anything — which
/// matters, because approval has weeks of lead time and may be refused pre-launch
/// (`docs/MONETISATION.md` §4).
///
/// **These links carry no affiliate marker and therefore earn nothing.** They point
/// at each partner's ordinary public search page, so the hand-off can be walked
/// end-to-end without inventing a tracking parameter that would not work and would
/// misrepresent an account we do not yet hold. Real links are minted by the service,
/// per [ADR-006](../../../docs/adr/006-affiliate-links-server-authoritative.md); when
/// it exists, this type is replaced rather than edited.
struct StubOfferProvider: OfferProviding {

    init() {}

    func offers(for request: OfferRequest, context: OfferContext) async throws -> [BookableOffer] {
        switch request {
        case let .place(_, name, city, requiresTicket, _):
            // A ticketed place is the clearest case in the product: `Place`
            // documents `requiresTicket` as "surfaced as a warning, not a booking
            // button", and this is that warning turning into an offer.
            guard requiresTicket else { return [] }
            let query = city.isEmpty ? name : "\(name) \(city)"
            return [
                BookableOffer(partner: .getYourGuide,
                              kind: .ticket,
                              priceBand: .between(18, 32),
                              url: Self.search(.getYourGuide, query)),
            ]

        case let .transfer(origin, destination):
            return [
                BookableOffer(partner: .trainline,
                              kind: .rail,
                              priceBand: .from(14),
                              url: Self.search(.trainline, "\(origin) \(destination)")),
                BookableOffer(partner: .welcomePickups,
                              kind: .transfer,
                              priceBand: .between(45, 70),
                              url: Self.search(.welcomePickups, destination)),
            ]

        case let .trip(city, nights):
            // Lodging is offered here and nowhere else: a bed sold beside a day plan
            // is sold to somebody who booked one weeks ago.
            var offers = [
                BookableOffer(partner: .booking,
                              kind: .lodging,
                              priceBand: .from(Decimal(68 * max(nights, 1))),
                              url: Self.search(.booking, city)),
            ]
            // Cheap, late and decided on the way to the airport — the best-converting
            // thing in the catalogue.
            offers.append(BookableOffer(partner: .airalo,
                                        kind: .esim,
                                        priceBand: .from(9),
                                        url: Self.search(.airalo, city)))
            return offers
        }
    }

    /// A partner's ordinary public search page. No marker, no commission, no
    /// pretence of one.
    private static func search(_ partner: AffiliatePartner, _ query: String) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        switch partner {
        case .getYourGuide:
            components.host = "www.getyourguide.com"
            components.path = "/s"
            components.queryItems = [URLQueryItem(name: "q", value: query)]
        case .booking:
            components.host = "www.booking.com"
            components.path = "/searchresults.html"
            components.queryItems = [URLQueryItem(name: "ss", value: query)]
        case .trainline:
            components.host = "www.thetrainline.com"
            components.path = "/search"
            components.queryItems = [URLQueryItem(name: "q", value: query)]
        case .welcomePickups:
            components.host = "www.welcomepickups.com"
            components.path = "/\(Self.slug(query))/"
        case .airalo:
            components.host = "www.airalo.com"
            components.path = "/search"
            components.queryItems = [URLQueryItem(name: "q", value: query)]
        case .viator, .klook, .omio, .discoverCars:
            components.host = "www.google.com"
            components.path = "/search"
            components.queryItems = [
                URLQueryItem(name: "q", value: "\(partner.displayName) \(query)"),
            ]
        }
        // A URL this type builds from its own components cannot fail to parse; the
        // fallback exists so the signature does not have to be optional.
        return components.url ?? URL(string: "https://www.google.com")!
    }

    private static func slug(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive], locale: Locale(identifier: "en_US"))
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
    }
}

/// Click reporting that goes nowhere.
///
/// The real reporter posts to `POST /v1/clicks`, which is how EPC per surface becomes
/// measurable. Until then the calls are made and dropped — so the call sites, the
/// ordering and the "never block the hand-off" rule are all exercised and tested now
/// rather than retrofitted around a live endpoint.
struct StubOfferClickReporter: OfferClickReporting {
    func reportClick(on offer: BookableOffer) async {}
}
