import Foundation

/// What the plan is asking for offers about.
///
/// A request names *facts about the plan*, never a partner and never a URL shape.
/// Which partners can answer, and what link they get, is the service's decision —
/// [ADR-006](../../../docs/adr/006-affiliate-links-server-authoritative.md). That is
/// what lets a programme be swapped, or dropped, without a release.
enum OfferRequest: Hashable, Sendable {
    /// Entry to a place already in the plan, on the day it is planned for. The
    /// highest-relevance thing this app can sell.
    ///
    /// `name` and `city` are redundant for a service that holds the POI index — it
    /// has them against `providerPlaceID` already — and necessary for one that does
    /// not, which is every mock. They are facts about the plan, so carrying them
    /// breaks no rule in ADR-006; a *partner* or a URL shape in this payload would.
    case place(providerPlaceID: String,
               name: String,
               city: String,
               requiresTicket: Bool,
               on: Date)
    /// Getting between two cities on the trip (F-07).
    case transfer(origin: String, destination: String)
    /// The trip as a whole: a bed, data, cover. Asked at intake, because by the time
    /// a day plan exists the bed is already booked.
    case trip(city: String, nights: Int)
}

/// Which part of the plan an offer is being asked for.
///
/// Not part of ``OfferRequest`` because it is not part of the *question* — it is who
/// is asking, and it exists for exactly one reason: the service hashes it into a
/// sub-id so earnings can be attributed back to the block that produced them
/// ([ADR-006](../../../docs/adr/006-affiliate-links-server-authoritative.md)).
/// Without it the ranking in `docs/MONETISATION.md` §2 stays a guess.
///
/// It carries no identity. The service salts and hashes these before they reach a
/// partner, and `none` is a supported state — a surface that cannot say where it is
/// still gets offers, it just cannot be measured apart from the others.
struct OfferContext: Hashable, Sendable {
    let tripID: Identifier<Trip>?
    let slot: DaySlot?

    static let none = OfferContext(tripID: nil, slot: nil)

    init(tripID: Identifier<Trip>? = nil, slot: DaySlot? = nil) {
        self.tripID = tripID
        self.slot = slot
    }
}

/// Where offers come from.
///
/// Behind a protocol so the plan screen never learns which partner answered, and so
/// the whole surface can be built and tested with no affiliate account, no approval
/// and no network.
protocol OfferProviding: Sendable {
    func offers(for request: OfferRequest, context: OfferContext) async throws -> [BookableOffer]
}

extension OfferProviding {
    /// For callers with nothing to attribute — previews, and tests about matching
    /// rather than about measurement.
    func offers(for request: OfferRequest) async throws -> [BookableOffer] {
        try await offers(for: request, context: .none)
    }
}

/// Click reporting, which is how earnings per surface stop being a guess.
///
/// Separate from ``OfferProviding`` because it is a write to a different place for a
/// different reason: the service logs the click so revenue can be attributed back to
/// the block that produced it, without an analytics SDK in the app.
///
/// Reporting is **best-effort and must never block the hand-off.** A traveller
/// tapping a ticket link waits for the partner's page, not for our bookkeeping.
protocol OfferClickReporting: Sendable {
    func reportClick(on offer: BookableOffer) async
}
