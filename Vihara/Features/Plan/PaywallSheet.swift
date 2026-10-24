import SwiftUI

/// The two paywalls from PRD 4.1 (F-09).
///
/// Which one appears is decided by ``ExportOutlook``, which ``Wallet`` computes in
/// the server's own order — so the traveller is shown the sheet they are about to
/// get, with no flicker between tap and answer.
///
/// **It never blocks the door.** The watermarked preview is already rendered and
/// shareable from this sheet; the purchase removes the watermark and the truncation.
/// A paywall that hides what was bought is a paywall people refuse on principle.
struct PaywallSheet: View {
    let outlook: ExportOutlook
    /// The preview the server already granted. Shareable from here, unbought.
    let preview: PlanDocument?
    let prices: [PurchasableProduct: String]
    let isPurchasing: Bool
    let notice: String?
    let onPurchase: (PurchasableProduct) -> Void
    let onRestore: () -> Void

    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss

    /// Only what the outlook offers. Variant B never shows the subscription — the
    /// traveller already has it, and selling it again reads as a bug.
    private var offered: [PurchasableProduct] {
        PurchasableProduct.allCases
            .filter { $0.isOffered(for: outlook) }
            .filter { prices[$0] != nil }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Plan.S.s4) {
                    Text(headline)
                        .viharaText(Theme.Plan.F.dayTitle)
                        .foregroundStyle(Theme.C.text)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(message)
                        .viharaText(Theme.Plan.F.item)
                        .foregroundStyle(Theme.C.textMuted)
                        .fixedSize(horizontal: false, vertical: true)

                    if offered.isEmpty {
                        // No prices means the store did not answer. Saying so is
                        // better than an empty sheet with a Done button.
                        Text("paywall.unavailable")
                            .viharaText(Theme.Plan.F.meta)
                            .foregroundStyle(Theme.C.price)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        VStack(spacing: Theme.Plan.S.s2) {
                            ForEach(offered) { product in
                                button(for: product)
                            }
                        }
                    }

                    if let notice {
                        Text(notice)
                            .viharaText(Theme.Plan.F.meta)
                            .foregroundStyle(Theme.C.price)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let preview {
                        Divider().overlay(Theme.C.border)

                        Text("paywall.preview.note")
                            .viharaText(Theme.Plan.F.meta)
                            .foregroundStyle(Theme.C.textMuted)
                            .fixedSize(horizontal: false, vertical: true)

                        ShareLink(item: ExportedPlan(document: preview),
                                  preview: SharePreview(preview.fileNameStem)) {
                            Text("export.share.preview")
                                .viharaText(Theme.Plan.F.meta)
                                .foregroundStyle(Theme.C.accentDeep)
                                .viharaInlineHitTarget()
                        }
                    }

                    Button(action: onRestore) {
                        Text("paywall.restore")
                            .viharaText(Theme.Plan.F.meta)
                            .foregroundStyle(Theme.C.textMuted)
                            .viharaInlineHitTarget()
                    }
                    .buttonStyle(.plain)
                    .disabled(isPurchasing)
                }
                .padding(Theme.Plan.S.screen)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Theme.C.bg.ignoresSafeArea())
            .navigationTitle(Text("paywall.title"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("paywall.notNow") { dismiss() }
                }
            }
        }
        .interactiveDismissDisabled(isPurchasing)
    }

    private func button(for product: PurchasableProduct) -> some View {
        Button {
            onPurchase(product)
        } label: {
            HStack(spacing: Theme.Plan.S.s3) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(localized("paywall.product.\(product.rawValue)", locale: locale))
                        .viharaText(Theme.Plan.F.action)
                    Text(localized("paywall.detail.\(product.rawValue)", locale: locale))
                        .viharaText(Theme.Plan.F.blockLabel)
                        .opacity(0.8)
                }
                Spacer(minLength: 0)
                // The price is never behind a tap. A button that reveals its cost
                // only after it is pressed is the pattern App Review rejects.
                Text(prices[product] ?? "")
                    .viharaText(Theme.Plan.F.action)
                    .monospacedDigit()
            }
            .foregroundStyle(Theme.C.bg)
            .padding(.horizontal, Theme.Plan.S.s4)
            .frame(maxWidth: .infinity, minHeight: Theme.S.tapTarget + Theme.Plan.S.s2,
                   alignment: .leading)
            .background(Theme.C.text,
                        in: RoundedRectangle(cornerRadius: Theme.Plan.R.surface, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isPurchasing)
        .opacity(isPurchasing ? 0.6 : 1)
    }

    private var headline: String {
        switch outlook {
        case .needsTopUp: localized("paywall.headline.topUp", locale: locale)
        default:          localized("paywall.headline.purchase", locale: locale)
        }
    }

    private var message: String {
        switch outlook {
        case let .needsTopUp(refillsOn):
            if let refillsOn {
                return localized("paywall.body.topUp.refills",
                                 refillsOn.formatted(.dateTime.day().month(.wide).locale(locale)),
                                 locale: locale)
            }
            return localized("paywall.body.topUp", locale: locale)
        default:
            return localized("paywall.body.purchase", locale: locale)
        }
    }
}
