import SwiftUI

/// One destination in the floating navigation.
///
/// A value rather than a pair of parallel arrays, so a symbol and its label cannot
/// drift out of step when somebody inserts an item in the middle.
struct NavItem: Identifiable {
    let id: String
    let symbol: String
    let label: LocalizedStringKey

    init(id: String, symbol: String, label: LocalizedStringKey) {
        self.id = id
        self.symbol = symbol
        self.label = label
    }
}

/// The floating navigation capsule: a symbol above a small uppercase label.
///
/// The labels used to carry the whole burden, which meant four German compounds
/// competing for a 375pt capsule. A symbol is recognised before it is read, so the
/// label can drop to a caption size and the row stops fighting for width — and the
/// type rule survives, because the label is still serif and the symbol is not type.
///
/// If Dynamic Type pushes the row past the available width it scrolls rather than
/// truncating: a reader who asked for larger text gets larger text.
struct BottomNav: View {
    let items: [NavItem]
    @Binding var selected: Int

    var body: some View {
        // Four items with icons *and* labels have to fit a 375pt capsule, so the
        // width is divided rather than negotiated: every item takes an equal share
        // and its label shrinks inside that share if the language is long. A
        // scrolling tab bar hides destinations, and a truncated one lies about their
        // names — an honestly smaller label beats both.
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                self.item(item, at: index)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(Theme.S.s1)
        .background(
            Theme.C.surface,
            in: RoundedRectangle(cornerRadius: Theme.R.pill, style: .continuous)
        )
        .viharaShadow(Theme.Shadow.floatingNav)
    }

    private func item(_ item: NavItem, at index: Int) -> some View {
        let isActive = index == selected
        return Button {
            withAnimation(Theme.Motion.navPill) { selected = index }
        } label: {
            VStack(spacing: Theme.S.s05) {
                Image(systemName: item.symbol)
                    .font(.system(size: Theme.Size.tabIcon, weight: isActive ? .semibold : .regular))
                    .symbolVariant(isActive ? .fill : .none)

                Text(item.label)
                    .viharaText(Theme.F.tabLabel)
                    .lineLimit(1)
                    // "Einstellungen" is thirteen characters and the share of a
                    // 375pt capsule is not thirteen characters wide. Scaling is the
                    // last resort and only ever applies to the longest label.
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(isActive ? Theme.C.surface : Theme.C.textMuted)
            .padding(.vertical, Theme.S.s2)
            .padding(.horizontal, Theme.S.s1)
            .frame(maxWidth: .infinity, minHeight: Theme.S.tapTarget)
            .background {
                // Always present, so the fill animates rather than popping.
                RoundedRectangle(cornerRadius: Theme.R.pill, style: .continuous)
                    .fill(Theme.C.text)
                    .opacity(isActive ? 1 : 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
    }
}

extension NavItem {
    /// The app's four destinations, in one place so the tab bar and whatever switches
    /// on it cannot disagree about the order.
    static let plan = NavItem(id: "plan", symbol: "safari", label: "tab.plan")
    static let trips = NavItem(id: "trips", symbol: "book.closed", label: "tab.trips")
    static let saved = NavItem(id: "saved", symbol: "bookmark", label: "tab.saved")
    static let settings = NavItem(id: "settings", symbol: "gearshape", label: "tab.settings")

    static let all: [NavItem] = [.plan, .trips, .saved, .settings]
}

#Preview("Deutsch") {
    @Previewable @State var selected = 0
    return BottomNav(items: NavItem.all, selected: $selected)
        .padding(.horizontal, Theme.S.screen)
        .frame(maxHeight: .infinity)
        .background(Theme.C.bg)
        .environment(\.locale, Locale(identifier: "de"))
}

#Preview("English") {
    @Previewable @State var selected = 2
    return BottomNav(items: NavItem.all, selected: $selected)
        .padding(.horizontal, Theme.S.screen)
        .frame(maxHeight: .infinity)
        .background(Theme.C.bg)
        .environment(\.locale, Locale(identifier: "en"))
}
