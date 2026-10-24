import SwiftUI

/// A bookable offer, drawn as a line of text.
///
/// **Not a button, deliberately.** The plan surface allows one filled control and it
/// is the export action; a row of coloured CTAs under every stop would turn a plan
/// into a catalogue, which is both the wrong product and the thing guideline 4.2.2
/// rejects ("a collection of links"). So an offer looks like the "Route" and "Warum
/// hier?" links it sits beside, and earns attention by being relevant rather than by
/// being loud.
///
/// The disclosure is **not optional and has no initialiser that omits it.** German
/// advertising law and every affiliate contract require paid placement to be marked,
/// so the label is part of the component rather than a flag a call site can forget.
struct OfferLink: View {
    /// "Ticket" — what is being sold, already localised by the caller.
    let kindLabel: String
    /// "GetYourGuide". The partner's own spelling, never localised.
    let partnerName: String
    /// "ab 18 €". Nil when the partner gives no band.
    let priceLabel: String?
    /// "Anzeige" — the paid-placement marker, already localised.
    let disclosureLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Theme.Plan.S.s1) {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Plan.S.s2) {
                    Text(line)
                        .viharaText(Theme.Plan.F.meta)
                        .foregroundStyle(Theme.C.accentDeep)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)

                    // The marker rides on the same line as the offer, never in a
                    // footnote somewhere else on the screen: a disclosure the eye
                    // does not meet at the moment of the tap is not a disclosure.
                    Text(disclosureLabel)
                        .viharaText(Theme.Plan.F.blockLabel)
                        .foregroundStyle(Theme.C.textFaint)
                }
            }
            .viharaInlineHitTarget()
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(line), \(disclosureLabel)")
        .accessibilityAddTraits(.isLink)
    }

    private var line: String {
        [kindLabel, partnerName, priceLabel]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Theme.Plan.S.s3) {
        OfferLink(kindLabel: "Ticket",
                  partnerName: "GetYourGuide",
                  priceLabel: "18–32 €",
                  disclosureLabel: "Anzeige") {}
        OfferLink(kindLabel: "Zug",
                  partnerName: "Trainline",
                  priceLabel: "ab 14 €",
                  disclosureLabel: "Anzeige") {}
        OfferLink(kindLabel: "eSIM",
                  partnerName: "Airalo",
                  priceLabel: nil,
                  disclosureLabel: "Anzeige") {}
    }
    .padding(Theme.Plan.S.screen)
    .background(Theme.C.bg)
}
