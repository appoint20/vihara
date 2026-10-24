import SwiftUI

/// The posts the traveller shared in, and what we found in them.
///
/// Reached from a line on Home that only exists when there is something to show —
/// inert chrome for an empty inbox would be the "Tab-Bar-Zoo" the design rules refuse.
struct CaptureInboxSheet: View {
    @Bindable var model: CaptureInboxViewModel
    /// Adding a place puts it on the route, through exactly the path the search
    /// field uses.
    let onAdd: (PlaceSuggestion) -> Void

    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Plan.S.block) {
                    if model.items.isEmpty {
                        Text("inbox.empty")
                            .viharaText(Theme.Plan.F.item)
                            .foregroundStyle(Theme.C.textFaint)
                    } else {
                        ForEach(model.items) { item in
                            row(item)
                        }
                    }
                }
                .padding(Theme.Plan.S.screen)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Theme.C.bg.ignoresSafeArea())
            .navigationTitle(Text("inbox.title"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.done") { dismiss() }
                }
            }
        }
        .task { await model.load() }
    }

    private func row(_ item: CaptureInboxViewModel.Resolved) -> some View {
        VStack(alignment: .leading, spacing: Theme.Plan.S.s2) {
            Text(localized("inbox.source.\(item.capture.source.rawValue)", locale: locale))
                .viharaText(Theme.Plan.F.blockLabel)
                .foregroundStyle(Theme.C.textFaint)

            if item.isUnresolved {
                Text("inbox.nothingFound")
                    .viharaText(Theme.Plan.F.item)
                    .foregroundStyle(Theme.C.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
                // Instagram is the common case and the traveller deserves the real
                // reason rather than a shrug.
                if item.capture.source == .instagram {
                    Text("inbox.instagramNote")
                        .viharaText(Theme.Plan.F.meta)
                        .foregroundStyle(Theme.C.textFaint)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                ForEach(item.mentions) { mention in
                    Button {
                        Task {
                            if let suggestion = await model.suggestion(for: mention) {
                                onAdd(suggestion)
                            }
                        }
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: Theme.Plan.S.s2) {
                            Text(mention.name)
                                .viharaText(Theme.Plan.F.item)
                                .foregroundStyle(Theme.C.text)
                            // The same distinction the search field keeps: naming a
                            // place and being able to plan it are different things.
                            if !mention.isPlannable {
                                Text("inbox.notPlannable")
                                    .viharaText(Theme.Plan.F.blockLabel)
                                    .foregroundStyle(Theme.C.textFaint)
                            }
                            Spacer(minLength: 0)
                            Text("inbox.add")
                                .viharaText(Theme.Plan.F.meta)
                                .foregroundStyle(Theme.C.accentDeep)
                        }
                        .viharaInlineHitTarget()
                    }
                    .buttonStyle(.plain)
                }
            }

            // The caption we read it from. Shown because a place that appeared from
            // nowhere is a place nobody trusts.
            if !item.text.isEmpty {
                Text(item.text)
                    .viharaText(Theme.Plan.F.meta)
                    .foregroundStyle(Theme.C.textFaint)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                model.dismiss(item.id)
            } label: {
                Text("inbox.remove")
                    .viharaText(Theme.Plan.F.meta)
                    .foregroundStyle(Theme.C.textMuted)
                    .viharaInlineHitTarget()
            }
            .buttonStyle(.plain)
        }
    }
}
