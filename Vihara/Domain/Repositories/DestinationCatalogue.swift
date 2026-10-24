import Foundation

/// What the traveller can browse and plan.
///
/// Behind a protocol from day one because the catalogue moves server-side the moment
/// a second region ships — and the screens must not notice when it does.
protocol DestinationCatalogue: Sendable {
    func destinations(in category: DestinationCategory) async throws -> [Destination]
    /// The "Beliebt gerade" rail.
    func popular() async throws -> [Destination]
    /// Resolves free text from intake to a destination we actually cover.
    /// Returns `nil` for anywhere not yet curated — which is the honest answer, and
    /// better than generating a plan we cannot stand behind.
    func destination(matching text: String) async throws -> Destination?

    /// Searches destinations matching the given query for autocomplete suggestions.
    func search(query: String) async throws -> [Destination]

    /// Every place a plan for this destination could draw on.
    ///
    /// The travel-party step needs these *before* composition runs: it cannot say
    /// what a party changes without knowing what it is changing, and "Torre degli
    /// Asinelli fällt raus" is only sayable if the tower was a candidate in the first
    /// place.
    func candidatePlaces(for destination: Identifier<Destination>) async throws -> [Place]
}

