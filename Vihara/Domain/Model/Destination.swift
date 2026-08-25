import Foundation

/// A place we are prepared to plan a trip to.
///
/// A destination exists in this catalogue only once its POI index has been curated
/// and passes the validation gate — quality gate, not marketing gate (PRD 10.2).
/// Nothing reachable from the UI is a region we cannot plan well.
struct Destination: Hashable, Sendable, Identifiable {
    let id: Identifier<Destination>
    let name: String
    /// "Emilia-Romagna, Italien" — what sits under the name on a card.
    let region: String
    let categories: Set<DestinationCategory>
    /// Aggregate traveller rating, already rounded for display.
    let rating: Double
    /// What we would plan if the traveller does not say.
    let suggestedNights: Int
    /// Content key for the hero photograph. An asset name today, a CDN key once
    /// photography is served rather than bundled.
    let imageSlug: String
}

/// The Discover rails. A closed set — new categories are a product decision, not a
/// string someone types into a CMS.
enum DestinationCategory: String, CaseIterable, Hashable, Sendable, Identifiable {
    case food
    case coast
    case mountains
    case cities
    case nature

    var id: String { rawValue }
}
