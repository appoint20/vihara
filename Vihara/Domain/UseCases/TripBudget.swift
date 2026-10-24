import Foundation

/// What the trip will cost, composed from the plan (F-11).
///
/// Wanderlog makes the traveller type every cost in by hand, with no conversion and
/// no estimates — one of the gaps in `docs/COMPETITION.md`. The plan already knows
/// the stops, their admissions, the party and the dates, so the budget should compose
/// itself.
///
/// **It distinguishes what it knows from what it assumes**, the same way
/// ``DietSignal`` separates *bestätigt* from *wahrscheinlich*. An admission price
/// came from a provider; a meal price is a band this type made up from an assumption.
/// Printing them as one number would be the dishonest convenience the rest of this
/// app refuses.
struct TripBudget: Sendable {

    /// The figures this type invents, named and injectable rather than buried as
    /// literals — so they can be tuned per region, and so a test can state the
    /// assumption it is about.
    struct Assumptions: Hashable, Sendable {
        /// One evening meal, per person.
        let mealPerPerson: PriceBand

        /// Plausible for the Italian pilot and wrong for Oslo or Hanoi, which is
        /// exactly why it is a named assumption and the UI says "geschätzt".
        static let pilot = Assumptions(mealPerPerson: .between(15, 35))
    }

    let brief: TripBrief
    let assumptions: Assumptions

    init(brief: TripBrief, assumptions: Assumptions = .pilot) {
        self.brief = brief
        self.assumptions = assumptions
    }

    func estimate(for days: [TripDay]) -> BudgetEstimate {
        var admissions: [PriceBand] = []
        var unpriced = 0
        var meals: [PriceBand] = []
        var transfers: [PriceBand] = []

        for day in days {
            for item in day.blocks.flatMap(\.items) {
                switch item.kind {
                case .sight, .activity:
                    if let cost = brief.party.admissionCost(for: item.place) {
                        admissions.append(PriceBand(low: cost, high: nil))
                    } else if item.place.requiresTicket {
                        // Known to cost something, amount unknown. Counting it as
                        // zero would understate the trip; hiding it would too.
                        unpriced += 1
                    }
                case .meal:
                    meals.append(assumptions.mealPerPerson.multiplied(by: brief.party.size))
                case .lodging:
                    // Deliberately not counted. The plan does not know what they paid
                    // for a bed, and an invented nightly rate would dominate the
                    // total while being the one figure we have no basis for.
                    break
                }
            }

            if let cheapest = day.arrivalTransfer?.options.map(\.priceBand).min(by: { $0.low.amount < $1.low.amount }) {
                transfers.append(cheapest.multiplied(by: brief.party.size))
            }
        }

        var lines: [BudgetEstimate.Line] = []
        if let band = PriceBand.sum(admissions) {
            lines.append(BudgetEstimate.Line(category: .admissions, band: band, isEstimate: false))
        }
        if let band = PriceBand.sum(meals) {
            lines.append(BudgetEstimate.Line(category: .meals, band: band, isEstimate: true))
        }
        if let band = PriceBand.sum(transfers) {
            lines.append(BudgetEstimate.Line(category: .transfers, band: band, isEstimate: false))
        }

        return BudgetEstimate(lines: lines,
                              currency: .eur,
                              unpricedStopCount: unpriced)
    }
}

/// A budget, broken down and honest about its own gaps.
struct BudgetEstimate: Hashable, Sendable {
    let lines: [Line]
    let currency: Money.Currency
    /// Stops known to cost money whose price we do not have. Shown as a caveat on
    /// the total, never folded into it.
    let unpricedStopCount: Int

    struct Line: Hashable, Sendable, Identifiable {
        let category: Category
        let band: PriceBand
        /// True when this line came from ``TripBudget/Assumptions`` rather than from
        /// provider data. Drives whether the row says "geschätzt".
        let isEstimate: Bool

        var id: Category { category }
    }

    enum Category: String, CaseIterable, Hashable, Sendable {
        case admissions
        case meals
        case transfers
    }

    var isEmpty: Bool { lines.isEmpty }

    /// `nil` when there is nothing to total.
    var total: PriceBand? {
        PriceBand.sum(lines.map(\.band))
    }

    /// Whether any part of the total was assumed rather than looked up. If so the
    /// whole total is an estimate — one invented line makes the sum invented.
    var isEstimate: Bool {
        lines.contains { $0.isEstimate } || unpricedStopCount > 0
    }

    /// Converts every line, or returns `nil` if the rate is unknown.
    ///
    /// All-or-nothing on purpose: a breakdown with some rows converted and some not
    /// is a breakdown that adds up to nothing.
    func converted(to currency: Money.Currency, rate: Decimal) -> BudgetEstimate {
        guard currency != self.currency else { return self }
        return BudgetEstimate(
            lines: lines.map {
                Line(category: $0.category,
                     band: $0.band.converted(to: currency, rate: rate),
                     isEstimate: $0.isEstimate)
            },
            currency: currency,
            unpricedStopCount: unpricedStopCount
        )
    }
}

extension PriceBand {

    /// Adds bands. An open-ended band ("ab 9 €") keeps the sum open-ended, because a
    /// total with an unknown component has no upper bound.
    static func sum(_ bands: [PriceBand]) -> PriceBand? {
        guard !bands.isEmpty else { return nil }
        let currency = bands[0].low.currency
        let low = bands.reduce(Decimal(0)) { $0 + $1.low.amount }
        let anyOpen = bands.contains { $0.high == nil }
        guard !anyOpen else { return PriceBand(low: Money(low, currency), high: nil) }
        let high = bands.reduce(Decimal(0)) { $0 + ($1.high?.amount ?? $1.low.amount) }
        return PriceBand(low: Money(low, currency), high: Money(high, currency))
    }

    func multiplied(by factor: Int) -> PriceBand {
        let n = Decimal(max(factor, 1))
        return PriceBand(low: Money(low.amount * n, low.currency),
                         high: high.map { Money($0.amount * n, $0.currency) })
    }

    func converted(to currency: Money.Currency, rate: Decimal) -> PriceBand {
        PriceBand(low: low.converted(to: currency, rate: rate),
                  high: high?.converted(to: currency, rate: rate))
    }
}
