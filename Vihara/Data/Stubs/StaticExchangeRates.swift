import Foundation

/// Exchange rates, mocked.
///
/// **A static table, and therefore wrong.** Rates move daily; these were plausible
/// mid-2026 figures and are stale by definition. They exist so the budget surface can
/// be built and tested without a rates provider, in the same way
/// ``StubOfferProvider`` stands in for the offer service.
///
/// Shipping this to travellers would be a Preisangabenverordnung problem, which is
/// why ``isAuthoritative`` is `false` and the budget prints an estimate rather than a
/// price. The real implementation reads `GET /v1/rates` — cached, dated, and
/// replacing this type rather than editing it.
struct StaticExchangeRates: ExchangeRates {

    /// Units of the currency per 1 EUR.
    private static let perEuro: [Money.Currency: Decimal] = [
        .eur: 1, .usd: 1.08, .gbp: 0.85, .chf: 0.95, .isk: 150,
        .sek: 11.3, .nok: 11.6, .dkk: 7.46, .pln: 4.30, .czk: 25.1,
        .huf: 395, .ron: 4.97, .bgn: 1.96, .tryx: 38.5,
        .cad: 1.47, .aud: 1.63, .nzd: 1.78,
        .jpy: 165, .krw: 1_460, .cny: 7.80, .thb: 38.5, .sgd: 1.45,
        .myr: 4.80, .idr: 17_200, .vnd: 27_500, .inr: 91, .lkr: 325,
        .aed: 3.97, .qar: 3.93, .ils: 4.00, .mad: 10.8, .egp: 53,
        .zar: 19.8, .kes: 140,
        .brl: 5.90, .mxn: 19.8, .ars: 1_100, .clp: 1_020, .cop: 4_300,
        .pen: 4.05, .uyu: 43,
    ]

    /// Always false here. The budget reads this to decide whether it may print a
    /// converted figure as a price or only as an estimate.
    let isAuthoritative = false

    func rate(from: Money.Currency, to: Money.Currency) async -> Decimal? {
        guard from != to else { return 1 }
        guard let fromRate = Self.perEuro[from], let toRate = Self.perEuro[to],
              fromRate > 0 else { return nil }
        return toRate / fromRate
    }
}
