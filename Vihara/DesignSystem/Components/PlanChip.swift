import SwiftUI

/// A single fact about the trip, shown back to the traveller so they can correct it.
///
/// Chips are the intake UI (PRD 3.1): the parsed brief is mirrored as editable
/// values, never as a form. Tapping one advances it — which is why the caption and
/// the value are separate: the caption stays put while the value changes, so the eye
/// does not have to re-find the control it just used.
struct PlanChip: View {
    let caption: String
    let value: String
    /// A chip we could not fill in reads as an invitation, not as an error.
    var isUnset: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Theme.S.s05) {
                Text(caption)
                    .viharaText(Theme.Plan.F.blockLabel)
                    .foregroundStyle(Theme.C.textFaint)
                Text(value)
                    .viharaText(Theme.Plan.F.meta)
                    .foregroundStyle(isUnset ? Theme.C.textFaint : Theme.C.text)
            }
            .padding(.horizontal, Theme.Plan.S.s2)
            .padding(.vertical, Theme.Plan.S.s1 + 1)
            .frame(minHeight: Theme.S.tapTarget, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Theme.Plan.R.surface, style: .continuous)
                    .strokeBorder(isUnset ? Theme.C.accent : Theme.C.border,
                                  lineWidth: Theme.Size.hairline)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(caption): \(value)")
        .accessibilityHint("Zum Ändern antippen")
    }
}

#Preview {
    FlowLayout {
        PlanChip(caption: "Ziel", value: "Bologna") {}
        PlanChip(caption: "Dauer", value: "4 Nächte") {}
        PlanChip(caption: "Tempo", value: "Entspannt") {}
        PlanChip(caption: "Ernährung", value: "Vegetarisch") {}
        PlanChip(caption: "Budget", value: "Noch offen", isUnset: true) {}
    }
    .padding(Theme.Plan.S.screen)
    .background(Theme.C.bg)
}
