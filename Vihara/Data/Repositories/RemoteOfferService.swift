import Foundation

/// Offers from the link service (`docs/MONETISATION.md` step 2).
///
/// This is what replaces ``StubOfferProvider`` when the service is up, and the whole
/// of [ADR-006](../../../docs/adr/006-affiliate-links-server-authoritative.md) in
/// practice: the client sends facts about the plan and receives opaque URLs on the
/// service's own origin. There is no partner name in the request, no marker in the
/// response, and no URL template anywhere in this file — `check-layers.sh` fails the
/// build if one appears.
struct RemoteOfferService: OfferProviding {
    private let client: any HTTPClient

    init(client: any HTTPClient) {
        self.client = client
    }

    func offers(for request: OfferRequest, context: OfferContext) async throws -> [BookableOffer] {
        let response = try await client.send(
            APIRequest(.get, "/v1/offers", query: Self.query(for: request, context: context)),
            expecting: OfferListDTO.self
        )
        // Unknown partners and kinds are dropped here rather than failing the
        // response — see ``OfferDTO/offer``.
        return response.offers.compactMap(\.offer)
    }

    /// The request, as facts about the plan.
    ///
    /// Note what is *not* here: which partner should answer, what the link should
    /// look like, or how much commission it carries. Those are the service's
    /// decisions, which is what lets a programme be swapped without a release.
    static func query(for request: OfferRequest,
                      context: OfferContext,
                      timeZone: TimeZone = .current) -> [String: String] {
        var query: [String: String] = [:]
        if let tripID = context.tripID { query["trip"] = tripID.rawValue }
        if let slot = context.slot { query["slot"] = slot.rawValue }

        switch request {
        case let .place(providerPlaceID, name, city, requiresTicket, date):
            query["type"] = "place"
            query["place"] = providerPlaceID
            query["name"] = name
            query["city"] = city
            query["requires_ticket"] = requiresTicket ? "1" : "0"
            query["date"] = Self.day(in: timeZone).string(from: date)
        case let .transfer(origin, destination):
            query["type"] = "transfer"
            query["origin"] = origin
            query["destination"] = destination
        case let .trip(city, nights):
            query["type"] = "trip"
            query["city"] = city
            query["nights"] = String(nights)
        }
        return query
    }

    /// Dates go over as plain calendar days, formatted in the **traveller's own**
    /// time zone.
    ///
    /// Not UTC, which is the mistake a test caught here: a `TripDay` is built at
    /// midnight local, so formatting it in UTC turns a Tuesday in Bologna into the
    /// Monday before it for everyone east of Greenwich — and asks the service for
    /// tickets on the wrong day. The day is a calendar fact in the traveller's terms,
    /// and that is the zone it has to be read in.
    private static func day(in timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}

/// Reports a tap to the service (`POST /v1/clicks`).
///
/// The tap and the arrival are different events, and the gap between them is the
/// attribution leak: a partner's universal link can open that partner's installed app
/// and drop the cookie, so a traveller who tapped never arrives at a page we can
/// count. The service logs arrivals at `/go/:token`; this logs the tap, and the
/// difference is the measurement ADR-006 says to take before paying an SDK to close
/// it.
///
/// **Failures are swallowed on purpose.** A traveller waiting on a ticket page must
/// never wait on our bookkeeping, and a bookkeeping error is not something they can
/// act on.
struct RemoteClickReporter: OfferClickReporting {
    private let client: any HTTPClient

    init(client: any HTTPClient) {
        self.client = client
    }

    func reportClick(on offer: BookableOffer) async {
        // Only what describes the surface. The offer id already carries the service's
        // own sub-id; nothing here identifies a person.
        let body: [String: String] = [
            "partner": offer.partner.rawValue,
            "kind": offer.kind.rawValue,
            "sub": offer.id.rawValue,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return }
        _ = try? await client.send(APIRequest(.post, "/v1/clicks", body: data),
                                   expecting: EmptyResponse.self)
    }
}

/// `POST /v1/clicks` answers 204 with no body. ``HTTPClient/send(_:expecting:)``
/// always decodes something, so this is what it decodes.
private struct EmptyResponse: Decodable {
    init(from decoder: any Decoder) throws {}
}
