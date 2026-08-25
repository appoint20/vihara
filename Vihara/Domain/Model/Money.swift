import Foundation

/// An amount in a single currency.
///
/// `Decimal`, not `Double`: these are prices, and prices that drift by a cent in
/// floating point turn into support tickets.
struct Money: Hashable, Sendable {
    let amount: Decimal
    let currency: Currency

    init(_ amount: Decimal, _ currency: Currency = .eur) {
        self.amount = amount
        self.currency = currency
    }

    enum Currency: String, Hashable, Sendable {
        case eur
    }
}

/// A range rather than a fare. The plan answers "train or car?", which does not need
/// a live price — and live pricing is expensive to licence (PRD 3.4).
struct PriceBand: Hashable, Sendable {
    let low: Money
    let high: Money?

    /// "ab 9 €" — an open-ended band.
    static func from(_ low: Decimal) -> PriceBand {
        PriceBand(low: Money(low), high: nil)
    }

    static func between(_ low: Decimal, _ high: Decimal) -> PriceBand {
        PriceBand(low: Money(low), high: Money(high))
    }
}
