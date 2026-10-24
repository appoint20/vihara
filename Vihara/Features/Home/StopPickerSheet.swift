import SwiftUI

/// Adds a stop to the route.
///
/// Only offers what is left: a destination already on the route is not shown, because
/// a route cannot visit the same city twice and an option that does nothing is worse
/// than no option.
struct StopPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    let catalogue: any DestinationCatalogue
    let chosen: [Identifier<Destination>]
    let onPick: (Destination) -> Void

    @State private var available: [Destination] = []
    @State private var query = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.S.s4) {
            Text("home.stops.add")
                .viharaText(Theme.F.h3)
                .foregroundStyle(Theme.C.text)

            CitySearchField(text: $query,
                            placeholder: localized("home.sentence.label", locale: locale)) {
                Task { await search() }
            } onClear: {
                Task { await search() }
            }
            .onChange(of: query) { _, _ in Task { await search() } }

            ScrollView {
                VStack(spacing: Theme.S.s2) {
                    ForEach(available) { destination in
                        Button {
                            onPick(destination)
                            Haptics.commit()
                            dismiss()
                        } label: {
                            row(for: destination)
                        }
                        .buttonStyle(.plain)
                    }

                    if available.isEmpty {
                        Text("home.stops.empty")
                            .viharaText(Theme.F.small)
                            .foregroundStyle(Theme.C.textMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, Theme.S.s4)
                    }
                }
            }
        }
        .padding(Theme.S.screen)
        .background(Theme.C.bg.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task { await search() }
    }

    private func row(for destination: Destination) -> some View {
        HStack(spacing: Theme.S.s3) {
            AssetImage(name: destination.imageSlug)
                .frame(width: Theme.Size.compactThumb, height: Theme.Size.compactThumb)
                .clipShape(RoundedRectangle(cornerRadius: Theme.R.compactThumb, style: .continuous))

            VStack(alignment: .leading, spacing: Theme.S.s05) {
                Text(destination.name)
                    .viharaText(Theme.F.cardTitle)
                    .foregroundStyle(Theme.C.text)
                Text(destination.region)
                    .viharaText(Theme.Plan.F.meta)
                    .foregroundStyle(Theme.C.textMuted)
            }

            Spacer(minLength: Theme.S.s2)

            Text(destination.suggestedLengthLabel(locale: locale))
                .viharaText(Theme.Plan.F.meta)
                .foregroundStyle(Theme.C.textFaint)
        }
        .padding(Theme.S.s3)
        .frame(maxWidth: .infinity, minHeight: Theme.S.tapTarget, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: Theme.R.compactCard, style: .continuous)
                .fill(Theme.C.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.R.compactCard, style: .continuous)
                        .strokeBorder(Theme.C.border, lineWidth: Theme.Size.hairline)
                }
        }
        .contentShape(Rectangle())
    }

    private func search() async {
        let results = (try? await catalogue.search(query: query)) ?? []
        available = results.filter { !chosen.contains($0.id) }
    }
}

#Preview {
    StopPickerSheet(catalogue: PilotDestinationCatalogue(), chosen: []) { _ in }
        .environment(\.locale, Locale(identifier: "de"))
}
