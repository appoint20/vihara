import SwiftUI

/// What to take, and why (F-12).
///
/// Every line that has a reason shows it. A checklist the traveller has to trust is a
/// checklist they will ignore; one that says "60 Min. zu Fuß an einem Tag" is one
/// they can agree or disagree with.
struct PackingSheet: View {
    let sections: [PackingSection]

    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss
    /// Ticking a box is per-device and per-trip and belongs nowhere near the plan
    /// record — a packed bag is not part of the itinerary.
    @State private var packed: Set<String> = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Plan.S.block) {
                    ForEach(sections) { section in
                        VStack(alignment: .leading, spacing: Theme.Plan.S.s2) {
                            Text(localized(section.category.labelKey, locale: locale))
                                .viharaText(Theme.Plan.F.blockLabel)
                                .foregroundStyle(Theme.C.textFaint)

                            ForEach(section.items) { item in
                                row(item)
                            }
                        }
                    }
                }
                .padding(Theme.Plan.S.screen)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Theme.C.bg.ignoresSafeArea())
            .navigationTitle(Text("packing.title"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.done") { dismiss() }
                }
            }
        }
    }

    private func row(_ item: PackingItem) -> some View {
        let isPacked = packed.contains(item.key)
        return Button {
            if isPacked { packed.remove(item.key) } else { packed.insert(item.key) }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Plan.S.s3) {
                // A glyph rather than a drawn box: the plan surface has no boxes.
                Text(isPacked ? "✓" : "·")
                    .viharaText(Theme.Plan.F.item)
                    .foregroundStyle(isPacked ? Theme.C.accentDeep : Theme.C.textFaint)
                    .frame(width: Theme.Plan.S.s4, alignment: .leading)

                VStack(alignment: .leading, spacing: Theme.Plan.S.s1) {
                    Text(localized(item.key, locale: locale))
                        .viharaText(Theme.Plan.F.item)
                        .foregroundStyle(isPacked ? Theme.C.textFaint : Theme.C.text)
                        .strikethrough(isPacked, color: Theme.C.textFaint)
                        .fixedSize(horizontal: false, vertical: true)

                    if let reasonKey = item.reasonKey {
                        Text(reasonText(reasonKey, argument: item.reasonArgument))
                            .viharaText(Theme.Plan.F.meta)
                            .foregroundStyle(Theme.C.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isPacked ? [.isSelected] : [])
    }

    private func reasonText(_ key: String, argument: String?) -> String {
        if let argument {
            return localized(key, argument, locale: locale)
        }
        return localized(key, locale: locale)
    }
}
