import Foundation

/// Finds the places named in a shared caption (COMPETITION.md wedge 3).
///
/// **It matches against a vocabulary; it does not understand anything.** That is a
/// deliberate ceiling, not a stopgap. A caption that says "this little place near the
/// market" names a restaurant no vocabulary holds, and a resolver that guessed would
/// put a place in a plan that nobody can visit — the exact failure
/// ``Place``'s validation gate exists to prevent. What it *can* do reliably is spot
/// the city, which is the thing a trip is actually planned around.
///
/// Pure Foundation and synchronous, so every matching rule below is a test rather
/// than a claim.
struct ResolveCapture: Sendable {
    private let vocabulary: PlaceVocabulary

    init(vocabulary: PlaceVocabulary) {
        self.vocabulary = vocabulary
    }

    /// Places named in the text, best first.
    ///
    /// "Best" is longest-match-first: a caption mentioning "San Sebastián" should
    /// resolve to San Sebastián and not to "San". Plannable destinations are then
    /// lifted above the rest, for the same reason the search field lifts them — a
    /// mention we can act on is worth more than one we can only acknowledge.
    func mentions(in text: String) -> [PlaceMention] {
        let tokens = Self.tokenise(text)
        guard !tokens.isEmpty else { return [] }

        var found: [PlaceMention] = []
        var seen: Set<String> = []

        for entry in vocabulary.entries {
            guard !seen.contains(entry.name) else { continue }
            for term in entry.terms {
                let termTokens = Self.tokenise(term)
                guard !termTokens.isEmpty, Self.contains(tokens, termTokens) else { continue }
                found.append(PlaceMention(name: entry.name,
                                          matched: term,
                                          destinationID: entry.destinationID))
                seen.insert(entry.name)
                break
            }
        }

        return found.sorted { lhs, rhs in
            if lhs.isPlannable != rhs.isPlannable { return lhs.isPlannable }
            let lhsLength = Self.tokenise(lhs.matched).count
            let rhsLength = Self.tokenise(rhs.matched).count
            if lhsLength != rhsLength { return lhsLength > rhsLength }
            return lhs.name < rhs.name
        }
    }

    /// Splits into comparable words.
    ///
    /// Everything that is not a letter or a digit is a separator, which is what makes
    /// `#bologna`, `Bologna,` and `bologna!` all match Bologna — hashtags are how
    /// captions name places, so treating `#` as punctuation is the whole trick.
    /// Diacritics and case are folded in German, matching the search field so the two
    /// surfaces cannot disagree about whether "Munchen" is München.
    static func tokenise(_ text: String) -> [String] {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive],
                                  locale: Locale(identifier: "de_DE"))
        return folded
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    /// Whether `needle` appears as a consecutive run inside `haystack`.
    ///
    /// Run-based rather than substring-based on purpose: a substring search finds
    /// "Rom" inside "Romantik", and a caption about a romantic weekend is not a
    /// caption about Rome.
    static func contains(_ haystack: [String], _ needle: [String]) -> Bool {
        guard !needle.isEmpty, needle.count <= haystack.count else { return false }
        for start in 0...(haystack.count - needle.count) {
            if Array(haystack[start..<(start + needle.count)]) == needle { return true }
        }
        return false
    }
}
