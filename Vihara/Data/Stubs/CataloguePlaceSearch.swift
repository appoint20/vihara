import Foundation

/// Place search over the curated catalogue.
///
/// What runs when there is no Places key, and — more importantly — what runs
/// *alongside* Places when there is one. See ``CombinedPlaceSearch``: the catalogue
/// is the only source that knows which places we can actually plan, so it always gets
/// asked.
struct CataloguePlaceSearch: PlaceSearching {
    private let catalogue: any DestinationCatalogue

    init(catalogue: any DestinationCatalogue) {
        self.catalogue = catalogue
    }

    func suggestions(for query: String) async throws -> [PlaceSuggestion] {
        try await catalogue.search(query: query).map { destination in
            PlaceSuggestion(id: destination.id.rawValue,
                            name: destination.name,
                            region: destination.region,
                            destinationID: destination.id)
        }
    }
}

/// The curated catalogue first, then everywhere else.
///
/// Order is the whole point. A traveller typing "Bo" should see Bologna — which we
/// can plan a real trip in — above Bordeaux, which we cannot. Google returns the
/// world in popularity order and has no idea which three cities we have curated, so
/// merging on top of the catalogue rather than replacing it is what keeps the
/// plannable answers reachable.
///
/// A failing remote search degrades to the catalogue alone rather than to an error:
/// a search field that goes blank when the network hiccups is worse than one that
/// finds less.
struct CombinedPlaceSearch: PlaceSearching {
    private let curated: any PlaceSearching
    private let remote: any PlaceSearching

    init(curated: any PlaceSearching, remote: any PlaceSearching) {
        self.curated = curated
        self.remote = remote
    }

    func suggestions(for query: String) async throws -> [PlaceSuggestion] {
        let ours = (try? await curated.suggestions(for: query)) ?? []
        let theirs = (try? await remote.suggestions(for: query)) ?? []

        // De-duplicate by name: Google will also return Bologna, and showing it twice
        // — once plannable, once not — would be actively confusing.
        let curatedNames = Set(ours.map { $0.name.lowercased() })
        return ours + theirs.filter { !curatedNames.contains($0.name.lowercased()) }
    }
}
