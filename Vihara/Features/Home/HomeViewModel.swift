import Foundation

/// The home surface's state.
///
/// One screenful, in the order the questions matter: who you are, where you are
/// going, when, what kind of trip, and then the two ways on. Nothing below the fold,
/// because there is no fold — the screen does not scroll, so anything that will not
/// fit does not belong here.
///
/// The rails and moods that used to sit underneath are gone. Browsing is what you do
/// when you have not decided, and someone who opened a trip planner has decided.
@MainActor
@Observable
final class HomeViewModel {

    /// One leg of the route. Order is the route — see ``move(from:to:)``.
    ///
    /// Holds a ``PlaceSuggestion`` rather than a ``Destination`` because the search
    /// service reaches further than the catalogue does: a traveller can put Lisbon on
    /// their route, and the screen has to be able to say we cannot plan it yet
    /// rather than refuse to show it.
    struct Stop: Identifiable, Hashable {
        let suggestion: PlaceSuggestion
        var nights: Int
        var id: String { suggestion.id }

        var name: String { suggestion.name }
        var isPlannable: Bool { suggestion.isPlannable }
    }

    /// What the traveller has said so far about the kind of trip they want.
    ///
    /// Every field optional, and the optionality is load-bearing: `nil` means "not
    /// asked yet", which is what the interview's remaining-question count reads, and
    /// what stops a default masquerading as an answer.
    struct Preferences: Hashable {
        var pace: TripBrief.Pace?
        var diet: TripBrief.DietRequirement?
        var budget: TripBrief.BudgetBand?

        /// Typed, not cycled — and children get their own field.
        ///
        /// Held as text because that is what a keypad produces, and because "" and
        /// "0" are different answers: nothing typed is an unanswered question, while
        /// a typed zero is somebody telling us they are travelling without children.
        /// An `Int?` cannot hold that distinction.
        var adultsText = ""
        var childrenText = ""

        var adults: Int? { Int(adultsText) }
        var children: Int? { Int(childrenText) }

        /// The party the rest of the app plans against.
        ///
        /// A child's age defaults to seven — old enough for most things, young enough
        /// that the interview's own age question still matters. The interview asks
        /// properly; this only has to be a defensible starting point.
        var party: TravelParty? {
            guard let adults else { return nil }
            return TravelParty(adults: adults,
                               childAges: Array(repeating: Self.assumedChildAge,
                                                count: children ?? 0))
        }

        static let assumedChildAge = 7

        var answeredCount: Int {
            [pace != nil, diet != nil, budget != nil, adults != nil].filter { $0 }.count
        }

        static let slotCount = 4
    }

    let catalogue: any DestinationCatalogue
    private let placeSearch: any PlaceSearching
    private let drafts: any InterviewDraftStore
    private let calendar: Calendar

    /// Handed to the interview so it can save its own progress. The home screen does
    /// not write drafts; it only offers back the ones it finds.
    var draftStore: any InterviewDraftStore { drafts }

    // MARK: - Route

    private(set) var stops: [Stop] = []

    /// What the field currently holds, mirrored for the "is anything typed" check.
    ///
    /// The field itself keeps its text in local view state and calls ``search(for:)``.
    /// Binding a `TextField` straight into an `@Observable` invalidated the whole
    /// screen on every character — including fourteen calendar cells, each formatting
    /// two dates — which is what made typing lag.
    private(set) var query: String = ""
    private(set) var suggestions: [PlaceSuggestion] = []
    private(set) var isSearching = false
    private(set) var searchFailed = false
    private var searchTask: Task<Void, Never>?

    // MARK: - Dates

    var selection = DateRangeSelection()
    private(set) var stripDays: [Date] = []
    var isCalendarPresented = false

    // MARK: - Preferences

    var preferences = Preferences()

    // MARK: - Sheets

    var isInterviewPresented = false
    var isSettingsPresented = false
    private(set) var interviewSeed: TripBrief?
    private(set) var resumeAtStep: Int?
    private(set) var openDrafts: [InterviewDraft] = []

    init(catalogue: any DestinationCatalogue,
         placeSearch: any PlaceSearching,
         drafts: any InterviewDraftStore,
         calendar: Calendar = .current) {
        self.catalogue = catalogue
        self.placeSearch = placeSearch
        self.drafts = drafts
        self.calendar = calendar
        self.stripDays = Self.nextTwoWeeks(from: .now, calendar: calendar)
    }

    // MARK: - Loading

    func load() async {
        openDrafts = await drafts.drafts()

        // Seed the route with the strongest curated region, so the screen opens on
        // something plannable rather than on an empty box. One tap removes it.
        if stops.isEmpty,
           let first = try? await catalogue.destinations(in: .food).first {
            stops = [Stop(suggestion: PlaceSuggestion(id: first.id.rawValue,
                                                      name: first.name,
                                                      region: first.region,
                                                      destinationID: first.id),
                          nights: first.suggestedNights)]
        }
    }

    func refreshDrafts() async {
        openDrafts = await drafts.drafts()
    }

    // MARK: - Searching for somewhere to go

    /// Runs ~300 ms behind the finger.
    ///
    /// Debounced because Places bills per request and a request per keystroke is both
    /// slower and more expensive than one per pause. Each keystroke cancels the
    /// pending search, so only the last one is paid for.
    func search(for text: String) {
        searchTask?.cancel()
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        self.query = query

        guard query.count >= 2 else {
            suggestions = []
            isSearching = false
            searchFailed = false
            return
        }

        isSearching = true
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled, let self else { return }

            do {
                let found = try await self.placeSearch.suggestions(for: query)
                guard !Task.isCancelled else { return }
                self.suggestions = found.filter { found in
                    !self.stops.contains { $0.id == found.id }
                }
                self.searchFailed = false
            } catch {
                guard !Task.isCancelled else { return }
                self.suggestions = []
                self.searchFailed = true
            }
            self.isSearching = false
        }
    }

    func add(_ suggestion: PlaceSuggestion) {
        guard !stops.contains(where: { $0.id == suggestion.id }) else { return }
        stops.append(Stop(suggestion: suggestion, nights: Self.defaultNights))
        query = ""
        suggestions = []
        syncSelectionToStops()
    }

    func remove(_ stop: Stop) {
        stops.removeAll { $0.id == stop.id }
        syncSelectionToStops()
    }

    /// Reordering *is* editing the route, not rearranging a list.
    func move(from source: IndexSet, to destination: Int) {
        stops.move(fromOffsets: source, toOffset: destination)
    }

    var totalNights: Int { stops.reduce(0) { $0 + $1.nights } }

    /// True when the route holds somewhere we cannot yet plan, so the screen can say
    /// so once rather than decorating every chip with a warning.
    var hasUnplannableStop: Bool { stops.contains { !$0.isPlannable } }

    private static let defaultNights = 3

    // MARK: - Dates

    func tapDay(_ day: Date) {
        selection.tap(day, calendar: calendar)
        Haptics.pickUp()
        syncSelectionToStops()
    }

    func applyDateRange(_ range: DateRangeSelection) {
        selection = range
        syncSelectionToStops()
        if let start = range.start {
            stripDays = Self.nextTwoWeeks(from: start, calendar: calendar)
        }
    }

    /// Keeps the chosen range and the route's night counts telling one story.
    ///
    /// Nights are what generation actually uses, so a chosen range is spread across
    /// the stops — evenly, remainder to the first, because the first city is where an
    /// extra night is least likely to be wrong.
    private func syncSelectionToStops() {
        guard let nights = selection.nights(in: calendar), nights > 0, !stops.isEmpty else { return }
        let each = nights / stops.count
        let remainder = nights % stops.count
        for index in stops.indices {
            stops[index].nights = max(1, each + (index < remainder ? 1 : 0))
        }
    }

    private static func nextTwoWeeks(from date: Date, calendar: Calendar) -> [Date] {
        let start = calendar.startOfDay(for: date)
        return (0..<14).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    // MARK: - Preferences
    //
    // Each control writes its own value directly. Nothing cycles: reaching an answer
    // should cost one interaction whatever the answer is, and a count is not an
    // enumeration at all.

    func setPace(_ value: TripBrief.Pace?) { preferences.pace = value }
    func setDiet(_ value: TripBrief.DietRequirement?) { preferences.diet = value }
    func setBudget(_ value: TripBrief.BudgetBand?) { preferences.budget = value }

    // MARK: - Going on

    /// What the interview still has to ask: the four preferences, plus a destination
    /// and dates if those are still open.
    var outstandingQuestions: Int {
        var open = Preferences.slotCount - preferences.answeredCount
        if stops.isEmpty { open += 1 }
        if selection.start == nil { open += 1 }
        return open
    }

    /// Everything the home screen already knows, handed to whatever comes next.
    var briefSoFar: TripBrief {
        TripBrief(destination: stops.first?.name ?? "",
                  startDate: selection.start ?? defaultStart,
                  nights: max(1, totalNights),
                  pace: preferences.pace ?? .balanced,
                  budget: preferences.budget ?? .middle,
                  diet: preferences.diet ?? .none,
                  party: preferences.party ?? .couple)
    }

    private var defaultStart: Date {
        calendar.date(byAdding: .day, value: 21, to: calendar.startOfDay(for: .now)) ?? .now
    }

    func startInterview(resumingAt step: Int? = nil) {
        interviewSeed = briefSoFar
        resumeAtStep = step
        isInterviewPresented = true
    }

    func resume(_ draft: InterviewDraft) {
        startInterview(resumingAt: draft.step)
    }

    /// The quick way on: take what we have, fill the rest from defaults, generate.
    ///
    /// Not a shortcut past the questions so much as an admission that our defaults are
    /// defensible — each one is a real product decision, and a traveller who does not
    /// want to answer six questions still deserves a plan.
    var quickBrief: TripBrief { briefSoFar }

    /// Only a route we can actually plan may go straight to generation. Somewhere we
    /// have not curated needs the interview, where it can be said out loud.
    var canGenerate: Bool {
        briefSoFar.isGeneratable && stops.first?.isPlannable == true
    }
}
