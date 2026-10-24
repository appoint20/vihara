import SwiftUI

/// A stop on the route: what it is called, how long you stay, and a way to drop it.
///
/// Ordered, and the order is the route — which is why the chip carries a drag handle
/// rather than a position number. A number would describe the order; the handle lets
/// the traveller change it.
struct TokenChip: View {
    let title: String
    let detail: String
    /// Accessibility wording for the remove control, already localized.
    let removeLabel: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: Theme.S.s2) {
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .viharaText(Theme.F.chip)
                    .foregroundStyle(Theme.C.text)
                Text(detail)
                    .viharaText(Theme.Plan.F.blockLabel)
                    .foregroundStyle(Theme.C.textFaint)
            }

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: Theme.Plan.F.blockLabel.size, weight: .semibold))
                    .foregroundStyle(Theme.C.textMuted)
                    .viharaInlineHitTarget()
            }
            .buttonStyle(.plain)
            .accessibilityLabel(removeLabel)
        }
        .padding(.leading, Theme.S.s3)
        .padding(.trailing, Theme.S.s2)
        .padding(.vertical, Theme.S.s2)
        .frame(minHeight: Theme.S.tapTarget)
        .background {
            RoundedRectangle(cornerRadius: Theme.R.pill, style: .continuous)
                .fill(Theme.C.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.R.pill, style: .continuous)
                        .strokeBorder(Theme.C.border, lineWidth: Theme.Size.hairline)
                }
        }
    }
}

/// The dashed chip that adds another stop.
///
/// Dashed rather than solid because it is not a thing yet — it is the outline of one.
/// The same reasoning applies to a recognition chip whose slot is still empty.
struct AddChip: View {
    let title: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.S.s1) {
                Image(systemName: "plus")
                    .font(.system(size: Theme.F.chip.size, weight: .semibold))
                Text(title)
                    .viharaText(Theme.F.chip)
            }
            .foregroundStyle(Theme.C.accentDeep)
            .padding(.horizontal, Theme.S.s3)
            .padding(.vertical, Theme.S.s2)
            .frame(minHeight: Theme.S.tapTarget)
            .background {
                RoundedRectangle(cornerRadius: Theme.R.pill, style: .continuous)
                    .strokeBorder(Theme.C.accent,
                                  style: StrokeStyle(lineWidth: Theme.Size.hairline,
                                                     dash: Theme.Size.dash))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// One slot of the brief, as the sentence field fills it in.
///
/// Two states and no third: filled carries a tick on an accent tint, empty is a
/// dashed grey outline. The set of them is the feedback loop for the sentence field —
/// a traveller typing watches slots land, and the ones still dashed are exactly what
/// the interview will otherwise have to ask about.
struct RecognitionChip: View {
    let caption: LocalizedStringKey
    /// The parsed value, or `nil` while the slot is still empty.
    let value: String?

    private var isFilled: Bool { value != nil }

    var body: some View {
        HStack(spacing: Theme.S.s1) {
            if isFilled {
                Image(systemName: "checkmark")
                    .font(.system(size: Theme.Plan.F.blockLabel.size, weight: .bold))
                    .foregroundStyle(Theme.C.accentDeep)
            }

            Text(caption)
                .viharaText(Theme.Plan.F.blockLabel)
                .foregroundStyle(isFilled ? Theme.C.accentDeep : Theme.C.textFaint)

            if let value {
                Text(value)
                    .viharaText(Theme.F.chip)
                    .foregroundStyle(Theme.C.text)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, Theme.S.s3)
        .padding(.vertical, Theme.S.s2)
        .background {
            let shape = RoundedRectangle(cornerRadius: Theme.R.pill, style: .continuous)
            if isFilled {
                shape.fill(Theme.C.accent.opacity(Theme.O.glassFill))
            } else {
                shape.strokeBorder(Theme.C.border,
                                   style: StrokeStyle(lineWidth: Theme.Size.hairline,
                                                      dash: Theme.Size.dash))
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// A chip that is either on or off: a mood, a consideration, a preset.
struct SelectChip: View {
    let title: LocalizedStringKey
    var symbol: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.S.s1) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: Theme.F.chip.size, weight: .medium))
                }
                Text(title)
                    .viharaText(Theme.F.chip)
            }
            .foregroundStyle(isSelected ? Theme.C.surface : Theme.C.text)
            .padding(.horizontal, Theme.S.s4)
            .padding(.vertical, Theme.S.s2)
            .frame(minHeight: Theme.S.tapTarget)
            .background {
                let shape = RoundedRectangle(cornerRadius: Theme.R.pill, style: .continuous)
                if isSelected {
                    shape.fill(Theme.C.text)
                } else {
                    shape.fill(Theme.C.surface)
                        .overlay {
                            shape.strokeBorder(Theme.C.border, lineWidth: Theme.Size.hairline)
                        }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .animation(Theme.Motion.tab, value: isSelected)
    }
}

/// An accent-tinted aside: what a set of numbers produces, what a party changes, what
/// a date range implies.
///
/// Accent rather than `price`, because none of these are warnings — they are the
/// planner showing its working. Conflicts and costs use `price`, and the two must not
/// blur together.
struct NotePanel<Content: View>: View {
    var title: LocalizedStringKey? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.S.s2) {
            if let title {
                Text(title)
                    .viharaText(Theme.Plan.F.blockLabel)
                    .foregroundStyle(Theme.C.accentDeep)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.S.s3)
        .background {
            RoundedRectangle(cornerRadius: Theme.R.compactThumb, style: .continuous)
                .fill(Theme.C.accent.opacity(Theme.O.glassFill))
        }
    }
}

#Preview("Chips · Deutsch") {
    ScrollView {
        VStack(alignment: .leading, spacing: Theme.S.s5) {
            FlowLayout {
                TokenChip(title: "Bologna", detail: "3 Nächte", removeLabel: "Bologna entfernen") {}
                TokenChip(title: "Ravenna", detail: "1 Nacht", removeLabel: "Ravenna entfernen") {}
                AddChip(title: "home.stops.add") {}
            }

            FlowLayout {
                RecognitionChip(caption: "slot.destination", value: "Bologna")
                RecognitionChip(caption: "slot.nights", value: "4 Nächte")
                RecognitionChip(caption: "slot.diet", value: nil)
                RecognitionChip(caption: "slot.party", value: nil)
            }

            FlowLayout {
                SelectChip(title: "mood.food", symbol: "fork.knife", isSelected: true) {}
                SelectChip(title: "mood.art", symbol: "building.columns", isSelected: false) {}
                SelectChip(title: "mood.slow", symbol: "tortoise", isSelected: false) {}
            }

            NotePanel(title: "party.effects.title") {
                Text("Torre degli Asinelli fällt raus: erst ab 12 Jahren, euer Jüngstes ist 4.")
                    .viharaText(Theme.Plan.F.meta)
                    .foregroundStyle(Theme.C.text)
            }
        }
        .padding(Theme.S.screen)
    }
    .background(Theme.C.bg)
    .environment(\.locale, Locale(identifier: "de"))
}

#Preview("Chips · English") {
    ScrollView {
        VStack(alignment: .leading, spacing: Theme.S.s5) {
            FlowLayout {
                TokenChip(title: "Bologna", detail: "3 nights", removeLabel: "Remove Bologna") {}
                AddChip(title: "home.stops.add") {}
            }
            FlowLayout {
                RecognitionChip(caption: "slot.destination", value: "Bologna")
                RecognitionChip(caption: "slot.diet", value: nil)
            }
        }
        .padding(Theme.S.screen)
    }
    .background(Theme.C.bg)
    .environment(\.locale, Locale(identifier: "en"))
}
