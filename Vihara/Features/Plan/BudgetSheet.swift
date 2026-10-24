import SwiftUI

/// The trip's cost, broken down (F-11).
///
/// A sheet rather than a section on the plan: "the plan is the product and everything
/// else is one tap away from it" (PRD 5.1). A budget panel permanently under the last
/// day would be the cockpit the design rules forbid.
struct BudgetSheet: View {
    let estimate: BudgetEstimate
    let currency: Money.Currency
    let onCurrency: (Money.Currency) -> Void

    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss

    /// The handful worth offering. The full ISO list in a picker is a directory, and
    /// a German-first app's travellers are not converting into Kenyan shillings to
    /// decide whether to go.
    private static let offered: [Money.Currency] = [.eur, .usd, .gbp, .chf]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Plan.S.s4) {
                    if estimate.isEmpty {
                        Text("budget.empty")
                            .viharaText(Theme.Plan.F.item)
                            .foregroundStyle(Theme.C.textFaint)
                    } else {
                        ForEach(estimate.lines) { line in
                            row(label: localized("budget.line.\(line.category.rawValue)", locale: locale),
                                band: line.band,
                                note: line.isEstimate ? localized("budget.estimated", locale: locale) : nil)
                        }

                        Divider().overlay(Theme.C.border)

                        if let total = estimate.total {
                            row(label: localized("budget.total", locale: locale),
                                band: total,
                                note: nil,
                                emphasised: true)
                        }

                        // Every caveat the number carries, stated under it rather
                        // than in a tooltip nobody opens.
                        VStack(alignment: .leading, spacing: Theme.Plan.S.s1) {
                            if estimate.isEstimate {
                                Text("budget.caveat.estimate")
                                    .viharaText(Theme.Plan.F.meta)
                                    .foregroundStyle(Theme.C.price)
                            }
                            if estimate.unpricedStopCount > 0 {
                                Text(localized("budget.caveat.unpriced",
                                               estimate.unpricedStopCount,
                                               locale: locale))
                                    .viharaText(Theme.Plan.F.meta)
                                    .foregroundStyle(Theme.C.price)
                            }
                            // Named, because a total that silently excluded the
                            // biggest line item would be the dishonest kind.
                            Text("budget.caveat.lodging")
                                .viharaText(Theme.Plan.F.meta)
                                .foregroundStyle(Theme.C.textMuted)
                        }
                        .fixedSize(horizontal: false, vertical: true)

                        currencyPicker
                    }
                }
                .padding(Theme.Plan.S.screen)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Theme.C.bg.ignoresSafeArea())
            .navigationTitle(Text("budget.title"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.done") { dismiss() }
                }
            }
        }
    }

    private func row(label: String,
                     band: PriceBand,
                     note: String?,
                     emphasised: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Plan.S.s2) {
            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .viharaText(emphasised ? Theme.Plan.F.action : Theme.Plan.F.item)
                    .foregroundStyle(Theme.C.text)
                if let note {
                    Text(note)
                        .viharaText(Theme.Plan.F.blockLabel)
                        .foregroundStyle(Theme.C.textFaint)
                }
            }
            Spacer(minLength: Theme.Plan.S.s2)
            Text(band.label(locale: locale))
                .viharaText(emphasised ? Theme.Plan.F.action : Theme.Plan.F.item)
                .foregroundStyle(emphasised ? Theme.C.text : Theme.C.textMuted)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    private var currencyPicker: some View {
        HStack(spacing: Theme.Plan.S.s3) {
            ForEach(Self.offered, id: \.self) { option in
                Button {
                    onCurrency(option)
                } label: {
                    Text(option.rawValue.uppercased())
                        .viharaText(Theme.Plan.F.meta)
                        .foregroundStyle(option == currency ? Theme.C.accentDeep : Theme.C.textMuted)
                        .viharaInlineHitTarget()
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(option == currency ? [.isSelected] : [])
            }
            Spacer(minLength: 0)
        }
        .padding(.top, Theme.Plan.S.s2)
    }
}

extension PriceBand {
    /// "15–35 €", localised. The band form is the honest one — see ``PriceBand``.
    func label(locale: Locale) -> String {
        guard let high, high.amount != low.amount else {
            return localized("budget.from", low.label(locale: locale), locale: locale)
        }
        return "\(low.label(locale: locale))–\(high.label(locale: locale))"
    }
}
