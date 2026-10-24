import Foundation

/// A place named in shared text.
///
/// A *mention*, not a ``Place``: it is a string somebody wrote in a caption, matched
/// against a vocabulary. Nothing about it has been validated, which is why it cannot
/// become a `Place` without going through the catalogue — the invariant `Place`
/// documents ("if it is in the model, it resolved") is exactly what a caption cannot
/// supply.
struct PlaceMention: Hashable, Sendable, Identifiable {
    /// The vocabulary entry's display name: "Bologna", not "#bologna".
    let name: String
    /// The text that actually matched, as written. Shown so the traveller can see
    /// why we think this Reel was about Bologna.
    let matched: String
    /// Set when this is somewhere we can plan a whole trip. The same honesty the
    /// search field keeps: naming a place and being able to plan it are different.
    let destinationID: Identifier<Destination>?

    var id: String { name }
    var isPlannable: Bool { destinationID != nil }
}

/// What the resolver knows how to recognise.
///
/// Supplied rather than looked up, so matching is testable without a catalogue and
/// so the vocabulary can grow — POI names, neighbourhoods, a curated list of
/// restaurant names — without the matching logic changing at all.
struct PlaceVocabulary: Sendable {
    struct Entry: Sendable {
        let name: String
        /// Every spelling that should match, including the name itself.
        let terms: [String]
        let destinationID: Identifier<Destination>?

        init(name: String, terms: [String] = [], destinationID: Identifier<Destination>? = nil) {
            self.name = name
            self.terms = ([name] + terms)
            self.destinationID = destinationID
        }
    }

    let entries: [Entry]

    init(entries: [Entry]) {
        self.entries = entries
    }
}
