import Testing
import Foundation
@testable import Vihara

@Suite("The bundled city corpus")
struct BundledCityCatalogueTests {

    private let corpus = BundledCityCatalogue(cities: [
        Fixture.city(id: "rome", name: "Rom", localName: "Roma",
                     region: "Latium, Italien", aliases: ["Rome"]),
        // Shares the query's prefix without being it — which is what makes the
        // exact-match rank observable at all.
        Fixture.city(id: "romford", name: "Romford",
                     region: "Vereinigtes Königreich"),
        Fixture.city(id: "florence", name: "Florenz", localName: "Firenze",
                     region: "Toskana, Italien", aliases: ["Florence"]),
        Fixture.city(id: "munich", name: "München", localName: "München",
                     region: "Bayern, Deutschland", aliases: ["Munich"]),
        Fixture.city(id: "mumbai", name: "Mumbai", region: "Indien",
                     aliases: ["Bombay"]),
    ])

    @Test("A whole-name match outranks a city that merely starts the same way")
    func exactNameWins() async throws {
        let results = try await corpus.suggestions(for: "Rom")
        #expect(results.map(\.name) == ["Rom", "Romford"])
    }

    /// Alphabetical inside a rank, so the same query always returns the same order.
    @Test("Equally good matches are ordered predictably")
    func stableWithinARank() async throws {
        let corpus = BundledCityCatalogue(cities: [
            Fixture.city(id: "b", name: "Testberg"),
            Fixture.city(id: "a", name: "Testanger"),
        ])
        #expect(try await corpus.suggestions(for: "Test").map(\.name) == ["Testanger", "Testberg"])
    }

    /// Someone typing into a German app types German, and types it without the
    /// umlaut as often as with one.
    @Test("Diacritics are optional both ways")
    func foldsDiacritics() async throws {
        #expect(try await corpus.suggestions(for: "Munchen").map(\.name) == ["München"])
        #expect(try await corpus.suggestions(for: "münch").map(\.name) == ["München"])
    }

    @Test("The endonym and the English name both find the city")
    func aliasesResolve() async throws {
        #expect(try await corpus.suggestions(for: "Firenze").map(\.name) == ["Florenz"])
        #expect(try await corpus.suggestions(for: "Florence").map(\.name) == ["Florenz"])
        #expect(try await corpus.suggestions(for: "Bombay").map(\.name) == ["Mumbai"])
    }

    /// "Italien" naming forty cities is a weaker intent than "Rimini" naming one, so
    /// a region match must never displace a name match.
    @Test("A region match comes last")
    func regionRanksLast() async throws {
        let results = try await corpus.suggestions(for: "Toskana")
        #expect(results.map(\.name) == ["Florenz"])

        let italian = try await corpus.suggestions(for: "Italien")
        #expect(Set(italian.map(\.name)) == ["Rom", "Florenz"])
    }

    @Test("A one-character query matches nothing rather than half the world")
    func tooShort() async throws {
        #expect(try await corpus.suggestions(for: "R").isEmpty)
        #expect(try await corpus.suggestions(for: " ").isEmpty)
        #expect(try await corpus.suggestions(for: "").isEmpty)
    }

    @Test("Nothing in the corpus claims to be plannable")
    func nothingIsPlannable() async throws {
        let results = try await corpus.suggestions(for: "Rom")
        #expect(!results.isEmpty)
        #expect(results.allSatisfy { !$0.isPlannable })
        #expect(results.allSatisfy { $0.destinationID == nil })
    }

    @Test("Every suggestion carries a coordinate")
    func coordinates() async throws {
        let results = try await corpus.suggestions(for: "Rom")
        #expect(results.allSatisfy { $0.coordinate != nil })
    }

    @Test("A suggestion list stays a glance, not a directory")
    func resultsAreCapped() async throws {
        let many = (0..<40).map { Fixture.city(id: "c\($0)", name: "Teststadt \($0)") }
        let results = try await BundledCityCatalogue(cities: many).suggestions(for: "Teststadt")
        #expect(results.count == BundledCityCatalogue.resultLimit)
    }

    @Test("An unreadable corpus yields an empty search, not a crash")
    func malformedDataThrows() {
        #expect(throws: (any Error).self) {
            try BundledCityCatalogue(data: Data("not json".utf8))
        }
    }
}

/// Guards the shipped file itself, not the ranking over it. The resource is loaded
/// through `Bundle.main`, which in an app-hosted test target is the app bundle — so
/// if `Cities.json` ever stops being copied, this fails rather than the search
/// quietly going empty in front of a traveller.
@Suite("The corpus as shipped")
struct ShippedCityCorpusTests {

    @Test("Cities.json is in the bundle and parses")
    func corpusIsBundled() throws {
        let url = try #require(Bundle.main.url(forResource: "Cities", withExtension: "json"),
                               "Cities.json is missing from the app bundle")
        let corpus = try BundledCityCatalogue(data: try Data(contentsOf: url))
        #expect(corpus.count >= 200, "the corpus should cover at least 200 cities")
    }

    @Test("Every row is usable: an id, a name, a region and a sane coordinate")
    func everyRowIsWellFormed() throws {
        let url = try #require(Bundle.main.url(forResource: "Cities", withExtension: "json"))
        let decoded = try JSONDecoder().decode(CityCorpusDTO.self, from: try Data(contentsOf: url))

        #expect(decoded.version == 1)
        for city in decoded.cities {
            #expect(!city.id.isEmpty)
            #expect(!city.name.isEmpty)
            #expect(!city.region.isEmpty)
            #expect((-90...90).contains(city.latitude), "\(city.id) latitude")
            #expect((-180...180).contains(city.longitude), "\(city.id) longitude")
            // The rails are a closed set; a typo here would silently drop a city.
            #expect(Set(city.categories).isSubset(of: Set(DestinationCategory.allCases.map(\.rawValue))),
                    "\(city.id) has an unknown category")
        }
    }

    @Test("Ids are unique, so a suggestion identifies exactly one city")
    func idsAreUnique() throws {
        let url = try #require(Bundle.main.url(forResource: "Cities", withExtension: "json"))
        let decoded = try JSONDecoder().decode(CityCorpusDTO.self, from: try Data(contentsOf: url))
        #expect(Set(decoded.cities.map(\.id)).count == decoded.cities.count)
    }

    /// The pilot region's three curated cities must also be findable by search, or a
    /// traveller can browse to Bologna but not type their way to it.
    @Test("The curated destinations are reachable through the corpus too")
    func curatedCitiesArePresent() throws {
        let url = try #require(Bundle.main.url(forResource: "Cities", withExtension: "json"))
        let decoded = try JSONDecoder().decode(CityCorpusDTO.self, from: try Data(contentsOf: url))
        let names = Set(decoded.cities.map { BundledCityCatalogue.fold($0.name) })

        for curated in PilotDestinationCatalogue.curated {
            #expect(names.contains(BundledCityCatalogue.fold(curated.name)),
                    "\(curated.name) is curated but not in the corpus")
        }
    }
}
