import Foundation

/// Discover's state: category filtering, featured & popular rails, and the centered city search
/// with Wanderlog-style trip planner interview triggers.
@MainActor
@Observable
final class DiscoverViewModel {
    let catalogue: any DestinationCatalogue

    /// Opens on the rail the pilot region is strongest in. `.coast` was the default
    /// while the catalogue still served two uncurated Spanish destinations; now that
    /// it serves only Emilia-Romagna, opening on `.coast` would greet everyone with
    /// the empty-rail message.
    private(set) var selectedCategory: DestinationCategory = .food
    private(set) var featured: [Destination] = []
    private(set) var popular: [Destination] = []
    private(set) var isLoading = true

    // Search & Interview state
    var searchQuery: String = ""
    private(set) var searchResults: [Destination] = []
    var isSearching: Bool = false
    var isInterviewPresented: Bool = false
    var interviewTargetDestination: Destination? = nil
    var interviewTargetCity: String? = nil

    init(catalogue: any DestinationCatalogue) {
        self.catalogue = catalogue
    }

    func load() async {
        async let featured = destinations(in: selectedCategory)
        async let popular = try? catalogue.popular()
        self.featured = await featured
        self.popular = await popular ?? []
        self.searchResults = self.popular
        isLoading = false
    }

    func select(_ category: DestinationCategory) async {
        guard category != selectedCategory else { return }
        selectedCategory = category
        featured = await destinations(in: category)
    }

    func updateSearch(query: String) async {
        searchQuery = query
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = popular
            isSearching = false
            return
        }
        isSearching = true
        if let results = try? await catalogue.search(query: trimmed) {
            searchResults = results
        } else {
            searchResults = []
        }
    }

    func clearSearch() {
        searchQuery = ""
        searchResults = popular
        isSearching = false
    }

    func launchInterview(destination: Destination? = nil, city: String? = nil) {
        interviewTargetDestination = destination
        interviewTargetCity = city ?? destination?.name ?? (searchQuery.isEmpty ? nil : searchQuery)
        isInterviewPresented = true
    }

    /// A category we have not curated yet returns nothing, and the screen says so.
    var featuredIsEmpty: Bool { !isLoading && featured.isEmpty }

    private func destinations(in category: DestinationCategory) async -> [Destination] {
        (try? await catalogue.destinations(in: category)) ?? []
    }
}
