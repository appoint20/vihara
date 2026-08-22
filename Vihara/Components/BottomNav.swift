import SwiftUI

/// The floating navigation capsule. No icons — the serif labels are the chrome.
///
/// At the designed type size the four labels distribute across the capsule. If
/// Dynamic Type pushes them past the available width, the row becomes scrollable
/// rather than truncating.
struct BottomNav: View {
    let items: [String]
    @Binding var selected: Int

    var body: some View {
        ViewThatFits(in: .horizontal) {
            // Preferred: labels distributed across the full capsule.
            row(spread: true, step: Theme.F.navLabel)
            // Then: the same row pulled tight to its minimum gaps.
            row(spread: false, step: Theme.F.navLabel)
            // Then: one type step down, which is what a 375pt device needs to show
            // all four German labels at all.
            row(spread: false, step: Theme.F.navLabelCompact)
            // Last resort (large Dynamic Type): scroll at the designed size rather
            // than shrink type for a reader who asked for bigger type.
            ScrollView(.horizontal, showsIndicators: false) {
                row(spread: false, step: Theme.F.navLabel)
            }
        }
        .padding(Theme.S.s2)
        .background(
            Theme.C.surface,
            in: RoundedRectangle(cornerRadius: Theme.R.pill, style: .continuous)
        )
        .viharaShadow(Theme.Shadow.floatingNav)
    }

    /// `spread` interleaves spacers so the labels distribute across the capsule.
    /// Either way the stack spacing guarantees the same minimum gap, so adjacent
    /// labels never run together — spacing applies on both sides of each spacer.
    private func row(spread: Bool, step: Theme.TextSpec) -> some View {
        HStack(spacing: spread ? Theme.S.s1 : Theme.S.s2) {
            ForEach(items.indices, id: \.self) { index in
                item(at: index, step: step)
                if spread, index < items.count - 1 {
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func item(at index: Int, step: Theme.TextSpec) -> some View {
        let isActive = index == selected
        return Button {
            withAnimation(Theme.Motion.navPill) { selected = index }
        } label: {
            Text(items[index])
                .viharaText(step)
                .fixedSize()
                .foregroundStyle(isActive ? Theme.C.surface : Theme.C.textMuted)
                .padding(.vertical, isActive ? Theme.S.s3 : 0)
                // Inactive labels carry no horizontal padding of their own: four German
                // words plus the active pill already fill the capsule at the designed
                // size, and the gaps come from the distribution spacers instead.
                .padding(.horizontal, isActive ? Theme.S.s5 : 0)
                .background {
                    // Always present, so the fill animates rather than popping.
                    RoundedRectangle(cornerRadius: Theme.R.pill, style: .continuous)
                        .fill(Theme.C.text)
                        .opacity(isActive ? 1 : 0)
                }
                .viharaHitTarget()
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
    }
}

#Preview {
    @Previewable @State var selected = 0
    BottomNav(items: ["Entdecken", "Meine Reisen", "Merkliste", "Profil"],
              selected: $selected)
        .padding(.horizontal, Theme.S.screen)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .background(Theme.C.bg)
}
