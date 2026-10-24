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

    /// The currencies the app can show a price in.
    ///
    /// A closed set, and every case is an ISO 4217 code lowercased — `label(locale:)`
    /// upper-cases it straight into `FormatStyle.Currency`, so a case that is not a
    /// real code would format as mojibake rather than fail to compile.
    ///
    /// Wanderlog's budget has no currency conversion at all, which is one of the
    /// gaps in `docs/COMPETITION.md`. Having more than one case here is the first
    /// half of closing it; ``ExchangeRates`` is the second.
    enum Currency: String, CaseIterable, Hashable, Sendable {
        case eur, usd, gbp, chf
        case sek, nok, dkk, pln, czk, huf, ron, bgn
        case tryx = "try"
        case cad, aud, nzd
        case jpy, krw, cny, thb, sgd, myr, idr, vnd, inr, lkr
        case aed, qar, ils, mad, egp, zar, kes
        case brl, mxn, ars, clp, cop, pen, uyu
        case isk

        /// Currencies conventionally written without decimals. Formatting them with
        /// two would print "¥1.200,00", which is not how a yen price is ever shown.
        var hasNoMinorUnit: Bool {
            switch self {
            case .jpy, .krw, .clp, .isk, .vnd: true
            default: false
            }
        }
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

extension Money {

    /// Converts into another currency at the given rate.
    ///
    /// Takes the rate rather than fetching it: a value type that reached for a
    /// network would be untestable, and conversion has to work offline — the
    /// traveller holding the phone is standing in the destination.
    func converted(to currency: Money.Currency, rate: Decimal) -> Money {
        guard currency != self.currency else { return self }
        return Money(amount * rate, currency)
    }
}

/// What one currency is worth in another.
///
/// Behind a protocol because the rates have to come from somewhere real eventually,
/// and because the budget must be computable in a test without inventing a network.
/// Rates are a **display** concern: the plan's own prices stay in the currency the
/// provider quoted, and conversion happens at the edge.
protocol ExchangeRates: Sendable {
    /// `nil` when the pair is unknown — which the budget must render as "not
    /// converted" rather than as zero. A missing rate silently becoming 0 would show
    /// a traveller a free holiday.
    func rate(from: Money.Currency, to: Money.Currency) async -> Decimal?
}

