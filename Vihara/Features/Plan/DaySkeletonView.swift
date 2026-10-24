import SwiftUI

/// The day currently being composed.
///
/// One skeleton, never a queue of them, and no shimmer: motion here would be
/// decorative, and the rule is states rather than spinners (PRD 5.1, rule 7). The
/// line of text does the communicating, and it changes as each day lands — which is
/// the only movement the screen needs.
struct DaySkeletonView: View {
    @Environment(\.locale) private var locale
    let dayNumber: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Plan.S.block) {
            Text(localized("plan.skeleton", dayNumber, locale: locale))
                .viharaText(Theme.Plan.F.dayTitle)
                .foregroundStyle(Theme.C.textFaint)

            ForEach(DaySlot.allCases, id: \.self) { slot in
                VStack(alignment: .leading, spacing: Theme.Plan.S.s2) {
                    Text(slot.label)
                        .viharaText(Theme.Plan.F.blockLabel)
                        .foregroundStyle(Theme.C.textFaint)
                    bar(widthFraction: slot == .evening ? 0.5 : 0.72)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(localized("plan.skeleton", dayNumber, locale: locale))
    }

    private func bar(widthFraction: CGFloat) -> some View {
        GeometryReader { proxy in
            RoundedRectangle(cornerRadius: Theme.Plan.R.surface, style: .continuous)
                .fill(Theme.C.border)
                .frame(width: proxy.size.width * widthFraction)
        }
        .frame(height: Theme.Plan.S.s4)
    }
}

#Preview {
    DaySkeletonView(dayNumber: 3)
        .padding(Theme.Plan.S.screen)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.C.bg)
}
