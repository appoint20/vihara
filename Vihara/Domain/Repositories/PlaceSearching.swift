import Foundation

/// A place the traveller can add to a route, before we know anything else about it.
///
/// Not a ``Destination``: a destination is a region we have curated and can plan a
/// whole trip in, and there are three of those. This is anywhere a search service can
/// name — which is most of the world, and none of it validated. The distinction is
/// the product's central honesty: searching is not the same as being able to plan.
struct PlaceSuggestion: Hashable, Sendable, Identifiable {
    /// The provider's id, or the curated destination's id when it came from us.
    let id: String
    /// "Bologna"
    let name: String
    /// "Emilia-Romagna, Italien"
    let region: String
    let coordinate: Coordinate?
    /// Set when this suggestion *is* one of our curated destinations, which is what
    /// lets the route say "we can plan this" rather than only "we found this".
    let destinationID: Identifier<Destination>?

    var isPlannable: Bool { destinationID != nil }

    init(id: String,
         name: String,
         region: String,
         coordinate: Coordinate? = nil,
         destinationID: Identifier<Destination>? = nil) {
        self.id = id
        self.name = name
        self.region = region
        self.coordinate = coordinate
        self.destinationID = destinationID
    }
}

/// Searching for somewhere to go.
///
/// Behind a protocol so the screen never learns whether the answer came from Google,
/// from our own catalogue, or from whatever replaces either — and so the search field
/// can be built and tested without a network or an API key.
protocol PlaceSearching: Sendable {
    /// Suggestions for a partial query. Returns `[]` for a query too short to be
    /// worth a request rather than firing one per keystroke.
    func suggestions(for query: String) async throws -> [PlaceSuggestion]
}
