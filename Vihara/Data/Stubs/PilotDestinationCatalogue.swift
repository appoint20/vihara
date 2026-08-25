import Foundation

/// The Italy pilot, hard-coded.
///
/// One region, curated by hand — the cheap-launch lever from PRD 9.1. When the
/// catalogue moves behind `GET /v1/destinations`, this type is replaced, not edited.
struct PilotDestinationCatalogue: DestinationCatalogue {

    /// What the catalogue serves.
    ///
    /// **Only destinations we can actually plan.** ``Destination`` documents this as
    /// an invariant — "a destination exists in this catalogue only once its POI index
    /// has been curated" — and until this split existed the invariant was prose. A
    /// destination with no itinerary behind it used to fall through to Emilia-Romagna
    /// and hand the traveller Bologna's days under another city's name.
    ///
    /// The gate is enforced, not remembered: `everyCuratedDestinationIsPlannable`
    /// fails the build if anything here has no template set in ``SampleItineraries``.
    static let curated: [Destination] = [
        Destination(id: Identifier("bologna"),
                    name: "Bologna",
                    region: "Emilia-Romagna, Italien",
                    categories: [.food, .cities],
                    rating: 4.8,
                    suggestedNights: 3,
                    imageSlug: "dest_bologna"),
        Destination(id: Identifier("modena"),
                    name: "Modena",
                    region: "Emilia-Romagna, Italien",
                    categories: [.food, .cities],
                    rating: 4.6,
                    suggestedNights: 2,
                    imageSlug: "top_modena"),
        Destination(id: Identifier("ravenna"),
                    name: "Ravenna",
                    region: "Emilia-Romagna, Italien",
                    categories: [.cities],
                    rating: 4.6,
                    suggestedNights: 2,
                    imageSlug: "top_ravenna"),
    ]

    /// Metadata and photography are ready; the POI index is not.
    ///
    /// Kept rather than deleted because the expensive half of adding a region is the
    /// curation, not this record — promoting one is a matter of writing its templates
    /// and moving the line up. Nothing serves this list, and nothing should: offering
    /// a card that cannot produce a plan is worse than not offering it.
    static let awaitingCuration: [Destination] = [
        Destination(id: Identifier("formentera"),
                    name: "Formentera",
                    region: "Balearen, Spanien",
                    categories: [.coast, .nature],
                    rating: 4.9,
                    suggestedNights: 4,
                    imageSlug: "dest_formentera"),
        Destination(id: Identifier("san-sebastian"),
                    name: "San Sebastián",
                    region: "Baskenland, Spanien",
                    categories: [.food, .coast],
                    rating: 4.7,
                    suggestedNights: 3,
                    imageSlug: "dest_sansebastian"),
    ]

    func destinations(in category: DestinationCategory) async throws -> [Destination] {
        Self.curated.filter { $0.categories.contains(category) }
    }

    func popular() async throws -> [Destination] {
        Self.curated.filter { $0.suggestedNights <= 2 }
    }

    /// **Resolution.** Turns free text into the one destination we will plan, or
    /// `nil`. Matches name or region, case- and diacritic-insensitively, so
    /// "Emilia-Romagna" finds Bologna. Empty text resolves to nothing, because
    /// "anywhere" is not a destination.
    func destination(matching text: String) async throws -> Destination? {
        let needle = Self.fold(text)
        guard !needle.isEmpty else { return nil }
        return Self.curated.first { candidate in
            let name = Self.fold(candidate.name)
            let region = Self.fold(candidate.region)
            return needle.contains(name) || name.contains(needle) || needle.contains(region)
                || region.split(separator: ",").contains { needle.contains(Self.fold(String($0))) }
        }
    }

    /// **Suggestion.** Feeds an autocomplete list, so an empty query is not "no
    /// match" but "nothing typed yet" and returns everything on offer — deliberately
    /// the opposite of ``destination(matching:)`` above, which resolves rather than
    /// suggests. The two read alike and answer different questions; that is why both
    /// carry this note.
    func search(query: String) async throws -> [Destination] {
        let needle = Self.fold(query)
        guard !needle.isEmpty else { return Self.curated }
        return Self.curated.filter { candidate in
            let name = Self.fold(candidate.name)
            let region = Self.fold(candidate.region)
            return name.contains(needle) || region.contains(needle)
        }
    }

    static func fold(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "de_DE"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

