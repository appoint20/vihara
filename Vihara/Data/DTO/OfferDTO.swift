import Foundation

/// The offer service's wire format (`GET /v1/offers`).
///
/// A DTO rather than a `Codable` ``BookableOffer``, per
/// [ADR-003](../../../docs/adr/003-domain-purity.md). It earns its keep here more
/// than usual: the service is expected to grow partners and offer kinds faster than
/// the app ships, and this is where an unknown one is dropped instead of becoming a
/// decoding failure that empties the whole list.
struct OfferListDTO: Decodable, Sendable {
    let offers: [OfferDTO]
}

struct OfferDTO: Decodable, Sendable {
    let id: String
    /// Matches ``AffiliatePartner``'s raw values. A partner this build does not know
    /// is dropped, not an error.
    let partner: String
    let kind: String
    let priceLow: Decimal?
    let priceHigh: Decimal?
    let currency: String?
    /// Opaque, on the service's own origin, with no marker in it. The client opens
    /// it and parses nothing.
    let url: URL
}

extension OfferDTO {

    /// `nil` for anything this build cannot render honestly.
    ///
    /// Three ways to be dropped, and each is a real case rather than defensive
    /// padding. An unknown **partner** or **kind** means the service is ahead of the
    /// app — which it will be, because the service deploys in seconds and the app
    /// takes days through review. A non-`http(s)` **URL** means something built a
    /// link the client cannot open; `SFSafariViewController` traps on those, so the
    /// check belongs at the boundary and not at the crash site.
    var offer: BookableOffer? {
        guard let partner = AffiliatePartner(rawValue: partner),
              let kind = BookableOffer.Kind(rawValue: kind),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else { return nil }

        return BookableOffer(id: Identifier(id),
                             partner: partner,
                             kind: kind,
                             priceBand: priceBand,
                             url: url)
    }

    /// A band, or nothing. Never a single exact figure dressed up as one — see
    /// ``PriceBand``.
    private var priceBand: PriceBand? {
        guard let priceLow else { return nil }
        let low = Money(priceLow)
        guard let priceHigh, priceHigh > priceLow else { return PriceBand(low: low, high: nil) }
        return PriceBand(low: low, high: Money(priceHigh))
    }
}
