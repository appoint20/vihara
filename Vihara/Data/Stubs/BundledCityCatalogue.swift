import Foundation

/// Place search over a bundled corpus of 285 cities.
///
/// What stands in for Google Places autocomplete. It exists so the search field can
/// be built, demoed, reviewed and tested with **no API key, no network and no
/// per-request bill** — and so a device in airplane mode still finds somewhere to go.
///
/// It is a stub in the same sense ``StubTripGenerator`` is: the shape of the answer is
/// real, the data behind it is not validated. Every suggestion it returns reports
/// `isPlannable == false`, which is not a limitation of the mock — it is true of the
/// real thing too, because a city is plannable only once its POI index is curated.
///
/// The corpus is regenerated, not edited:
///
///     Scripts/generate-cities.py
struct BundledCityCatalogue: PlaceSearching {

    /// Shorter than this and we return nothing rather than matching half the world
    /// on one letter. ``PlaceSearching`` documents the contract.
    static let minimumQueryLength = 2
    /// An autocomplete list is a glance, not a directory.
    static let resultLimit = 12

    private let cities: [CityDTO]

    /// Takes the parsed corpus rather than reading it, so ranking is testable
    /// without a bundle — the same reason ``AppDependencies/placeSearch(catalogue:apiKey:)``
    /// takes the key instead of fetching it.
    init(cities: [CityDTO]) {
        self.cities = cities
    }

    init(data: Data) throws {
        self.cities = try JSONDecoder().decode(CityCorpusDTO.self, from: data).cities
    }

    /// The corpus as shipped, loaded once.
    ///
    /// A missing or unreadable resource yields an **empty** catalogue rather than a
    /// crash. Search degrading to the three curated destinations is a worse search;
    /// a launch-time trap over a suggestion list is a worse app. `check-resources`
    /// in CI is what catches the file going missing, not the traveller.
    static let bundled: BundledCityCatalogue = {
        guard let url = Bundle.main.url(forResource: "Cities", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let parsed = try? BundledCityCatalogue(data: data) else {
            return BundledCityCatalogue(cities: [])
        }
        return parsed
    }()

    var count: Int { cities.count }

    /// The corpus itself, for callers that need the rows rather than a search over
    /// them — ``CatalogueVocabulary`` builds the caption vocabulary from these.
    var rows: [CityDTO] { cities }

    func suggestions(for query: String) async throws -> [PlaceSuggestion] {
        let needle = Self.fold(query)
        guard needle.count >= Self.minimumQueryLength else { return [] }

        var matches: [Match] = []
        for city in cities {
            if let rank = Self.rank(city, against: needle) {
                matches.append(Match(city: city, rank: rank, sortName: Self.fold(city.name)))
            }
        }

        // Rank first, then alphabetically inside a rank. Stable and explainable:
        // "Flor" must put Florenz above Florida, and the corpus carries no popularity
        // signal to break the tie any other way.
        matches.sort { lhs, rhs in
            if lhs.rank != rhs.rank { return lhs.rank.rawValue < rhs.rank.rawValue }
            return lhs.sortName < rhs.sortName
        }

        return matches.prefix(Self.resultLimit).map { $0.city.suggestion }
    }

    /// Spelled out rather than a tuple: the chained version of this function took the
    /// type checker past its time limit and failed the build.
    private struct Match {
        let city: CityDTO
        let rank: Rank
        let sortName: String
    }

    /// How well a city answers a query. Lower is better.
    ///
    /// Ordered by what a traveller typing into a search field means. Someone typing
    /// "Rom" wants Rom, not Rotterdam — so a whole-name match outranks a prefix, a
    /// prefix outranks a match in the middle of a word, and a match on the *region*
    /// comes last because "Italien" naming forty cities is a weaker intent than
    /// "Rimini" naming one.
    enum Rank: Int {
        case exactName = 0
        case prefixName = 1
        case prefixAlias = 2
        case withinName = 3
        case withinAlias = 4
        case withinRegion = 5
    }

    static func rank(_ city: CityDTO, against needle: String) -> Rank? {
        let name = fold(city.name)
        if name == needle { return .exactName }
        if name.hasPrefix(needle) { return .prefixName }

        let aliases = ([city.localName] + city.aliases).map(fold)
        if aliases.contains(where: { $0 == needle || $0.hasPrefix(needle) }) { return .prefixAlias }
        if name.contains(needle) { return .withinName }
        if aliases.contains(where: { $0.contains(needle) }) { return .withinAlias }
        if fold(city.region).contains(needle) { return .withinRegion }
        return nil
    }

    /// Diacritic- and case-insensitive, in German — so "Munchen" finds München and
    /// "Zurich" finds Zürich. Deliberately identical to
    /// ``PilotDestinationCatalogue/fold(_:)``: two search surfaces that fold
    /// differently would rank the same query differently.
    static func fold(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive],
                     locale: Locale(identifier: "de_DE"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
