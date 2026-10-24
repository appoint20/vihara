import Foundation

/// "Meine Reisen" — the plans already on the device.
///
/// The other half of F-14. Persisting plans nobody can find again is not persistence,
/// and until this screen existed the second tab of the navigation was a label with
/// nothing behind it.
@MainActor
@Observable
final class SavedTripsViewModel {
    private let trips: any TripRepository

    private(set) var saved: [Trip] = []
    private(set) var isLoading = true

    init(trips: any TripRepository) {
        self.trips = trips
    }

    /// Reloads every time the tab is shown rather than once: a plan generated in this
    /// session has to appear here without a relaunch.
    func load() async {
        saved = (try? await trips.allTrips()) ?? []
        isLoading = false
    }

    func delete(_ trip: Trip) async {
        try? await trips.delete(id: trip.id)
        await load()
    }

    var isEmpty: Bool { !isLoading && saved.isEmpty }
}

extension Trip {
    /// "3 Nächte · ab Di, 14. Apr." — enough to tell two Bologna trips apart.
    func summaryLabel(locale: Locale) -> String {
        [brief.nightsLabel(locale: locale),
         localized("trips.from", brief.startDateLabel(locale: locale), locale: locale)]
            .joined(separator: " · ")
    }

    /// "12 Bausteine" — what the plan actually contains, which is the thing a
    /// traveller scanning a list of saved plans is looking for.
    func sizeLabel(locale: Locale) -> String {
        itemCount == 1 ? localized("trips.blocks.one", locale: locale)
                       : localized("trips.blocks", itemCount, locale: locale)
    }
}
