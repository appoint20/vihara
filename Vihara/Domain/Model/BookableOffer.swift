import Foundation

/// Something in the plan the traveller can book, on which Vihara earns a commission.
///
/// **The client cannot construct a payable link.** `url` arrives opaque, minted by
/// the offer service, and there is deliberately no affiliate id, marker or URL
/// template anywhere in this target — see
/// [ADR-006](../../../docs/adr/006-affiliate-links-server-authoritative.md). The
/// structural reason is the same one behind ``Wallet``: a value the client can build
/// is a value the client can be made to build wrongly, and here "wrongly" means
/// either an unpaid booking or a dead link that survives until the next release
/// clears App Review.
///
/// **An offer is never persisted.** It carries a price and a link, both of which go
/// stale — a cached fare is a Preisangabenverordnung problem as much as a conversion
/// one, and a rotated marker earns nothing. Offers are resolved at render time and
/// live beside the ``Trip``, never inside it, which is why ``ItineraryItem`` has no
/// `offers` property.
struct BookableOffer: Hashable, Sendable, Identifiable {
    let id: Identifier<BookableOffer>
    let partner: AffiliatePartner
    let kind: Kind
    /// What the partner is charging, as a band. Never an exact cached number.
    let priceBand: PriceBand?
    /// Opaque. Built by the service, opened by the client, parsed by nobody.
    let url: URL

    init(id: Identifier<BookableOffer> = .generate(),
         partner: AffiliatePartner,
         kind: Kind,
         priceBand: PriceBand? = nil,
         url: URL) {
        self.id = id
        self.partner = partner
        self.kind = kind
        self.priceBand = priceBand
        self.url = url
    }

    /// What is being sold. Ordered by how well it fits a *day planner*, which is not
    /// the same as by commission rate — see `docs/MONETISATION.md` §2. A ticket for a
    /// place already in the plan is the most relevant thing this app can sell; a
    /// flight is the least, which is why there is no case for one.
    enum Kind: String, CaseIterable, Hashable, Sendable {
        /// Skip-the-line entry to a place in the plan. The best fit there is.
        case ticket
        /// A guided tour or experience in the destination.
        case activity
        /// Somewhere to stay. Only ever offered at intake — by the time a day plan
        /// exists the traveller has already booked, so a bed sold next to
        /// "Vormittag: Uffizien" is sold to nobody.
        case lodging
        /// Getting between two cities on the trip.
        case transfer
        /// A seat on a specific train.
        case rail
        /// Data for the trip. Cheap, late, and the highest-converting thing here.
        case esim
        case insurance
    }
}

/// Who gets handed the booking.
///
/// A closed set, because each case is a signed contract with disclosure obligations
/// and brand-term rules attached — not a string a CMS can invent.
enum AffiliatePartner: String, CaseIterable, Hashable, Sendable {
    case booking
    case getYourGuide
    case viator
    case klook
    case trainline
    case omio
    case discoverCars
    case welcomePickups
    case airalo

    /// The partner's own name, as the contract requires it to be written. Not
    /// localised: "GetYourGuide" is "GetYourGuide" in every market.
    var displayName: String {
        switch self {
        case .booking:        "Booking.com"
        case .getYourGuide:   "GetYourGuide"
        case .viator:         "Viator"
        case .klook:          "Klook"
        case .trainline:      "Trainline"
        case .omio:           "Omio"
        case .discoverCars:   "DiscoverCars"
        case .welcomePickups: "Welcome Pickups"
        case .airalo:         "Airalo"
        }
    }
}
