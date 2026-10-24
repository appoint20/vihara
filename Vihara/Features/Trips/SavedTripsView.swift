import SwiftUI

/// The plans already on this device.
///
/// Opens a saved plan rather than regenerating it — see ``PlanViewModel/init(trip:)``.
/// Regenerating would spend a free generation and could quietly return something
/// other than what the traveller saved.
struct SavedTripsView: View {
    @Environment(\.locale) private var locale
    @Environment(Router.self) private var router
    @State private var model: SavedTripsViewModel

    init(model: SavedTripsViewModel) {
        _model = State(wrappedValue: model)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if model.isEmpty {
                empty
            } else {
                list
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task { await model.load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.S.s1) {
            Text("trips.subtitle")
                .viharaText(Theme.F.small)
                .foregroundStyle(Theme.C.textMuted)
            Text("trips.title")
                .viharaText(Theme.F.h2)
                .foregroundStyle(Theme.C.text)
        }
        .padding(.horizontal, Theme.S.screen)
        .padding(.top, Theme.S.s2)
    }

    private var empty: some View {
        Text("trips.empty")
            .viharaText(Theme.F.body)
            .foregroundStyle(Theme.C.textMuted)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Theme.S.screen)
            .padding(.top, Theme.S.sectionTop)
    }

    private var list: some View {
        VStack(spacing: Theme.S.s3) {
            ForEach(model.saved) { trip in
                Button {
                    router.push(.savedTrip(trip))
                } label: {
                    row(for: trip)
                }
                .buttonStyle(.plain)
                .accessibilityHint(Text(localized("trips.open", trip.brief.destination, locale: locale)))
                .contextMenu {
                    Button(role: .destructive) {
                        Task { await model.delete(trip) }
                    } label: {
                        Label { Text("trips.delete") } icon: { Image(systemName: "trash") }
                    }
                }
            }
        }
        .padding(.horizontal, Theme.S.screen)
        .padding(.top, Theme.S.s5)
    }

    private func row(for trip: Trip) -> some View {
        HStack(spacing: Theme.S.s3) {
            VStack(alignment: .leading, spacing: Theme.S.s05) {
                Text(trip.brief.destination)
                    .viharaText(Theme.F.cardTitle)
                    .foregroundStyle(Theme.C.text)

                Text(trip.summaryLabel(locale: locale))
                    .viharaText(Theme.Plan.F.meta)
                    .foregroundStyle(Theme.C.textMuted)

                Text(trip.sizeLabel(locale: locale))
                    .viharaText(Theme.Plan.F.meta)
                    .foregroundStyle(Theme.C.textFaint)
            }

            Spacer(minLength: Theme.S.s3)

            Image(systemName: "chevron.right")
                .viharaText(Theme.F.chevron)
                .foregroundStyle(Theme.C.textFaint)
        }
        .padding(Theme.S.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
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
}

#Preview("Mit gespeicherten Reisen") {
    let brief = TripBrief(destination: "Bologna",
                          startDate: .now,
                          nights: 3,
                          diet: .vegetarian)
    let trips = InMemoryTripRepository(seed: [
        Trip(brief: brief, days: [TripDay(date: .now, city: "Bologna")]),
    ])
    return ScrollView {
        SavedTripsView(model: SavedTripsViewModel(trips: trips))
    }
    .background(Theme.C.bg)
    .environment(Router())
}

#Preview("Leer") {
    ScrollView {
        SavedTripsView(model: SavedTripsViewModel(trips: InMemoryTripRepository()))
    }
    .background(Theme.C.bg)
    .environment(Router())
}
