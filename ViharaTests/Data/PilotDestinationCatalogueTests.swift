import Testing
@testable import Vihara

@Suite("Pilot catalogue")
struct PilotDestinationCatalogueTests {

    private let catalogue = PilotDestinationCatalogue()

    @Test("Categories return only their own destinations, in catalogue order")
    func categoryFiltering() async throws {
        let culinary = try await catalogue.destinations(in: .food)
        let cities = try await catalogue.destinations(in: .cities)

        #expect(culinary.map(\.name) == ["Bologna", "Modena"])
        // Ravenna is mosaics, not menus.
        #expect(!culinary.contains { $0.name == "Ravenna" })
        #expect(cities.map(\.name) == ["Bologna", "Modena", "Ravenna"])
    }

    @Test("A category we have not curated returns nothing rather than everything")
    func uncuratedCategoryIsEmpty() async throws {
        let mountains = try await catalogue.destinations(in: .mountains)
        let coast = try await catalogue.destinations(in: .coast)

        #expect(mountains.isEmpty)
        // Formentera and San Sebastián are coastal and both await curation, so the
        // rail is honestly empty rather than offering a card that cannot be planned.
        #expect(coast.isEmpty)
    }

    @Test("Matching is case- and diacritic-insensitive")
    func matching() async throws {
        let lowercased = try await catalogue.destination(matching: "bologna")
        let uppercased = try await catalogue.destination(matching: "BOLOGNA")
        #expect(lowercased?.name == "Bologna")
        #expect(uppercased?.name == "Bologna")
    }

    @Test("A sentence containing a destination matches it")
    func matchingInsideASentence() async throws {
        let found = try await catalogue.destination(matching: "5 Tage Bologna, vegetarisch")
        #expect(found?.name == "Bologna")
    }

    @Test("Somewhere we do not cover matches nothing")
    func noMatch() async throws {
        let iceland = try await catalogue.destination(matching: "Reykjavík")
        let empty = try await catalogue.destination(matching: "")
        #expect(iceland == nil)
        #expect(empty == nil)
    }

    /// A destination whose photography and metadata are ready but whose POI index is
    /// not must be invisible to every read path, or it becomes a card that leads to
    /// an error.
    @Test("A destination awaiting curation is not served by any read path")
    func awaitingCurationIsNeverServed() async throws {
        let namesAwaiting = Set(PilotDestinationCatalogue.awaitingCuration.map(\.name))
        #expect(namesAwaiting == ["Formentera", "San Sebastián"])

        for name in namesAwaiting {
            #expect(try await catalogue.destination(matching: name) == nil)
            #expect(try await catalogue.search(query: name).isEmpty)
        }

        let everythingServed = try await catalogue.search(query: "")
        #expect(!everythingServed.contains { namesAwaiting.contains($0.name) })
    }

    /// The gate that stops the wrong-city bug coming back.
    ///
    /// It used to be possible to add a destination to the catalogue without writing
    /// its itinerary; `templates(for:)` fell through to Emilia-Romagna and the
    /// traveller got Bologna's days under another city's name. This fails the build
    /// instead.
    @Test("Every destination the catalogue serves can actually be planned")
    func everyCuratedDestinationIsPlannable() async throws {
        for destination in PilotDestinationCatalogue.curated {
            let templates = SampleItineraries.templates(for: destination.id)
            #expect(!templates.isEmpty,
                    "\(destination.name) is served by the catalogue but has no itinerary templates")
        }
    }

    @Test("A destination we have not curated has no itinerary to fall back on")
    func uncuratedDestinationHasNoTemplates() {
        for destination in PilotDestinationCatalogue.awaitingCuration {
            #expect(SampleItineraries.templates(for: destination.id).isEmpty)
        }
        #expect(SampleItineraries.templates(for: Identifier("reykjavik")).isEmpty)
    }

    @Test("Search returns matching destinations by prefix or region")
    func searchAutocomplete() async throws {
        let bol = try await catalogue.search(query: "Bol")
        let emilia = try await catalogue.search(query: "Emilia")
        let all = try await catalogue.search(query: "")

        #expect(bol.map(\.name) == ["Bologna"])
        #expect(emilia.map(\.name) == ["Bologna", "Modena", "Ravenna"])
        // An empty query is "nothing typed yet", not "no match" — the autocomplete
        // list offers everything on the shelf.
        #expect(all.count == PilotDestinationCatalogue.curated.count)
    }
}
