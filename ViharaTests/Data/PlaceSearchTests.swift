import Testing
import Foundation
@testable import Vihara

@Suite("Searching for somewhere to go")
struct PlaceSearchTests {

    private let catalogue = PilotDestinationCatalogue()

    @Test("The catalogue's own results are marked plannable")
    func curatedResultsArePlannable() async throws {
        let search = CataloguePlaceSearch(catalogue: catalogue)
        let results = try await search.suggestions(for: "Bol")

        #expect(results.map(\.name) == ["Bologna"])
        #expect(results.first?.isPlannable == true)
        #expect(results.first?.destinationID == Identifier("bologna"))
    }

    /// The ordering is the product rule: a traveller typing "Bo" must see Bologna,
    /// which we can plan, above anything we cannot.
    @Test("Curated places come first, and remote ones follow")
    func curatedFirst() async throws {
        let search = CombinedPlaceSearch(
            curated: CataloguePlaceSearch(catalogue: catalogue),
            remote: FakeRemote(results: [
                PlaceSuggestion(id: "g1", name: "Bordeaux", region: "Nouvelle-Aquitaine"),
                PlaceSuggestion(id: "g2", name: "Boston", region: "Massachusetts"),
            ])
        )
        let results = try await search.suggestions(for: "Bo")

        #expect(results.map(\.name) == ["Bologna", "Bordeaux", "Boston"])
        #expect(results.first?.isPlannable == true)
        #expect(results.dropFirst().allSatisfy { !$0.isPlannable })
    }

    @Test("A place we already curate is not offered twice")
    func deduplicates() async throws {
        let search = CombinedPlaceSearch(
            curated: CataloguePlaceSearch(catalogue: catalogue),
            remote: FakeRemote(results: [
                PlaceSuggestion(id: "g1", name: "bologna", region: "Italy"),
            ])
        )
        let results = try await search.suggestions(for: "Bologna")

        #expect(results.count == 1)
        #expect(results.first?.isPlannable == true)
    }

    /// A search field that empties itself when the network hiccups is worse than one
    /// that finds less.
    @Test("A failing remote search degrades to the catalogue rather than to nothing")
    func remoteFailureDegrades() async throws {
        let search = CombinedPlaceSearch(curated: CataloguePlaceSearch(catalogue: catalogue),
                                         remote: FailingRemote())
        let results = try await search.suggestions(for: "Bologna")

        #expect(results.map(\.name) == ["Bologna"])
    }

    @Test("A one-character query is not worth a billed request")
    func tooShortToSearch() async throws {
        // The guard lives in GooglePlacesSearch, which needs no network to refuse.
        let search = GooglePlacesSearch(apiKey: "unused")
        #expect(try await search.suggestions(for: "B").isEmpty)
        #expect(try await search.suggestions(for: " ").isEmpty)
    }

    /// The key is passed in, never read from the bundle: a test that asserted on
    /// ambient configuration printed a real API key into its own failure output.
    @Test("Without a key the app still searches, through the catalogue and the corpus")
    func fallbackWithoutAKey() async throws {
        let search = AppDependencies.placeSearch(catalogue: catalogue, apiKey: nil,
                                                 corpus: FakeRemote(results: []))
        let results = try await search.suggestions(for: "Ravenna")
        #expect(results.map(\.name) == ["Ravenna"])
        #expect(results.first?.isPlannable == true)
    }

    /// The keyless path used to answer three cities, so "Lissabon" returned silence —
    /// which a traveller cannot tell apart from a broken field.
    @Test("Without a key, somewhere we cannot plan is still found by name")
    func corpusAnswersWhereTheCatalogueCannot() async throws {
        let search = AppDependencies.placeSearch(
            catalogue: catalogue,
            apiKey: nil,
            corpus: BundledCityCatalogue(cities: [Fixture.city(id: "lisbon", name: "Lissabon")])
        )
        let results = try await search.suggestions(for: "Lissabon")

        #expect(results.map(\.name) == ["Lissabon"])
        // Found, and honestly marked as somewhere we cannot plan.
        #expect(results.first?.isPlannable == false)
    }

    @Test("With a key, curated results still come first")
    func combinedWhenKeyed() async throws {
        let search = AppDependencies.placeSearch(catalogue: catalogue, apiKey: "test-key")
        #expect(search is CombinedPlaceSearch)
    }
}

private struct FakeRemote: PlaceSearching {
    let results: [PlaceSuggestion]
    func suggestions(for query: String) async throws -> [PlaceSuggestion] { results }
}

private struct FailingRemote: PlaceSearching {
    func suggestions(for query: String) async throws -> [PlaceSuggestion] {
        throw DomainError.connectionFailed
    }
}

@Suite("Picking a date range")
struct DateRangeSelectionTests {

    private let calendar = Fixture.calendar

    private func day(_ number: Int) -> Date { Fixture.date(2026, 9, number) }

    @Test("First tap arrives, second departs")
    func twoTaps() {
        var selection = DateRangeSelection()
        selection.tap(day(10), calendar: calendar)
        #expect(selection.start == day(10))
        #expect(selection.end == nil)

        selection.tap(day(14), calendar: calendar)
        #expect(selection.end == day(14))
        #expect(selection.nights(in: calendar) == 4)
        #expect(selection.isComplete)
    }

    @Test("A third tap starts over")
    func thirdTapRestarts() {
        var selection = DateRangeSelection()
        selection.tap(day(10), calendar: calendar)
        selection.tap(day(14), calendar: calendar)
        selection.tap(day(20), calendar: calendar)

        #expect(selection.start == day(20))
        #expect(selection.end == nil)
    }

    /// Somebody who taps the 3rd after the 10th has changed their mind about
    /// arriving, not asked to travel backwards.
    @Test("Tapping before the arrival re-chooses the arrival")
    func earlierTapMovesTheStart() {
        var selection = DateRangeSelection()
        selection.tap(day(10), calendar: calendar)
        selection.tap(day(3), calendar: calendar)

        #expect(selection.start == day(3))
        #expect(selection.end == nil)
    }

    @Test("Tapping the arrival again clears it")
    func tappingStartClears() {
        var selection = DateRangeSelection()
        selection.tap(day(10), calendar: calendar)
        selection.tap(day(10), calendar: calendar)

        #expect(selection.start == nil)
        #expect(!selection.isComplete)
    }

    @Test("Days are drawn by where they sit in the range")
    func positions() {
        var selection = DateRangeSelection()
        selection.tap(day(10), calendar: calendar)
        #expect(selection.position(of: day(10), calendar: calendar) == .only)

        selection.tap(day(13), calendar: calendar)
        #expect(selection.position(of: day(10), calendar: calendar) == .start)
        #expect(selection.position(of: day(11), calendar: calendar) == .inside)
        #expect(selection.position(of: day(13), calendar: calendar) == .end)
        #expect(selection.position(of: day(14), calendar: calendar) == .plain)
    }

    @Test("The range enumerates every day it covers, ends included")
    func enumeratesDays() {
        var selection = DateRangeSelection()
        selection.tap(day(10), calendar: calendar)
        selection.tap(day(13), calendar: calendar)

        #expect(selection.days(in: calendar).count == 4)
        #expect(selection.contains(day(11), calendar: calendar))
        #expect(!selection.contains(day(14), calendar: calendar))
    }

    /// Most Italian museums shut on Mondays, which is a real composition risk in the
    /// pilot region rather than a generic caution.
    @Test("A Monday inside the range is found so the sheet can name it")
    func mondayIsFound() {
        var selection = DateRangeSelection()
        // 7 September 2026 is a Monday.
        selection.tap(day(5), calendar: calendar)
        selection.tap(day(9), calendar: calendar)

        let monday = HomeDisplay.mondayInRange(selection, calendar: calendar)
        #expect(monday == day(7))
    }

    @Test("A range with no Monday reports none")
    func noMonday() {
        var selection = DateRangeSelection()
        selection.tap(day(8), calendar: calendar)
        selection.tap(day(11), calendar: calendar)
        #expect(HomeDisplay.mondayInRange(selection, calendar: calendar) == nil)
    }
}

@Suite("Handing a day to a maps app")
struct MapHandoffTests {

    private let bologna = Coordinate(latitude: 44.4938, longitude: 11.3467)
    private let modena = Coordinate(latitude: 44.6462, longitude: 10.9256)

    @Test("A coordinate is written to six decimal places")
    func coordinateFormatting() {
        #expect(MapHandoff.point(bologna) == "44.493800,11.346700")
    }

    @Test("A multi-stop route becomes a Google directions URL")
    func wholeDayURL() {
        let urls = MapHandoff.googleMapsURLs(through: [bologna, modena, bologna])

        let web = urls.web.absoluteString
        #expect(web.hasPrefix("https://www.google.com/maps/dir/"))
        #expect(web.contains("44.493800,11.346700"))
        #expect(web.contains("44.646200,10.925600"))

        let app = try? #require(urls.app).absoluteString
        #expect(app?.hasPrefix("comgooglemaps://") == true)
        // Walking, always: every distance in the plan is a walking distance.
        #expect(app?.contains("directionsmode=walking") == true)
        #expect(app?.contains("waypoints=") == true)
    }

    @Test("A single stop asks for directions to it")
    func singleStopURL() {
        let urls = MapHandoff.googleMapsURLs(to: bologna)
        #expect(urls.web.absoluteString.contains("destination=44.493800,11.346700"))
        #expect(urls.app?.absoluteString.contains("daddr=44.493800") == true)
    }

    @Test("Apple Maps gets a walking URL too")
    func appleURLs() {
        #expect(MapHandoff.appleMapsURL(to: bologna).absoluteString.contains("dirflg=w"))
        let route = MapHandoff.appleMapsURL(through: [bologna, modena]).absoluteString
        #expect(route.contains("daddr=44.646200,10.925600"))
        #expect(route.contains("saddr=44.493800,11.346700"))
    }

    @Test("An empty day produces a URL rather than a crash")
    func emptyDay() {
        #expect(MapHandoff.appleMapsURL(through: []).absoluteString.contains("maps.apple.com"))
        #expect(MapHandoff.googleMapsURLs(through: []).web.absoluteString.contains("google.com/maps"))
    }

    @Test("A day reports its stops in order and its walking total")
    func dayRouteAndWalking() {
        let day = TripDay(date: Fixture.date(2026, 4, 14), city: "Bologna", blocks: [
            DayBlock(slot: .morning, items: [
                ItineraryItem(place: Fixture.place("A"), kind: .sight),
                ItineraryItem(place: Fixture.place("B"), kind: .sight,
                              travelFromPrevious: TravelLeg(mode: .walk, minutes: 7)),
            ]),
            DayBlock(slot: .afternoon),
            DayBlock(slot: .evening, items: [
                ItineraryItem(place: Fixture.place("C"), kind: .meal,
                              travelFromPrevious: TravelLeg(mode: .transit, minutes: 20)),
            ]),
        ])

        #expect(day.routeCoordinates.count == 3)
        // Transit minutes are not walking minutes.
        #expect(day.walkingMinutes == 7)
    }
}
