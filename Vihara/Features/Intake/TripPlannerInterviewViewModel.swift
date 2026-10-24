import Foundation

/// The interview, six steps deep.
///
/// It no longer starts from nothing: the home surface has already taken a sentence, a
/// route and a date range, so this picks up at whatever is still outstanding. Every
/// step writes a draft on the way through, so closing it four questions in does not
/// throw four questions away.
@MainActor
@Observable
final class TripPlannerInterviewViewModel {

    enum Step: Int, CaseIterable, Identifiable, Comparable {
        case destination = 0
        case datesAndDuration = 1
        case styleAndPace = 2
        /// Inserted before budget, because it changes more than budget does — an age
        /// limit removes a stop, and a nap removes a window.
        case travelParty = 3
        case budgetAndDiet = 4
        case summary = 5

        var id: Int { rawValue }

        var titleKey: String {
            switch self {
            case .destination:      "interview.step.destination.title"
            case .datesAndDuration: "interview.step.dates.title"
            case .styleAndPace:     "interview.step.pace.title"
            case .travelParty:      "interview.step.party.title"
            case .budgetAndDiet:    "interview.step.budget.title"
            case .summary:          "interview.step.summary.title"
            }
        }

        var subtitleKey: String {
            switch self {
            case .destination:      "interview.step.destination.subtitle"
            case .datesAndDuration: "interview.step.dates.subtitle"
            case .styleAndPace:     "interview.step.pace.subtitle"
            case .travelParty:      "interview.step.party.subtitle"
            case .budgetAndDiet:    "interview.step.budget.subtitle"
            case .summary:          "interview.step.summary.subtitle"
            }
        }

        static func < (lhs: Step, rhs: Step) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    private let catalogue: any DestinationCatalogue
    private let drafts: (any InterviewDraftStore)?
    private let calendar: Calendar

    // MARK: - State

    var currentStep: Step = .destination {
        didSet { saveDraft() }
    }
    var searchQuery: String = ""
    private(set) var searchResults: [Destination] = []
    private(set) var popularDestinations: [Destination] = []
    private(set) var isLoadingDestinations: Bool = false
    private(set) var candidatePlaces: [Place] = []

    // Brief values
    var destinationName: String = ""
    var selectedDestination: Destination? = nil
    var startDate: Date
    var nights: Int = 3
    var travelStyle: TripBrief.TravelStyle = .cityBreak
    var budget: TripBrief.BudgetBand = .middle
    var diet: TripBrief.DietRequirement = .none
    var party: TravelParty = .couple

    /// Pace as a bucket, or the traveller's own numbers.
    ///
    /// One choice with two shapes, mirroring the card stack: the three preset cards
    /// set `pace` and clear the override, and the "Eigene Werte" card sets the
    /// override. Whichever is live is what composition reads.
    var pace: TripBrief.Pace = .balanced
    var paceOverride: TripBrief.PaceOverride?

    var isCustomPace: Bool { paceOverride != nil }

    init(catalogue: any DestinationCatalogue,
         drafts: (any InterviewDraftStore)? = nil,
         preselectedDestination: Destination? = nil,
         initialCity: String? = nil,
         seed: TripBrief? = nil,
         resumingAt step: Int? = nil,
         calendar: Calendar = .current) {
        self.catalogue = catalogue
        self.drafts = drafts
        self.calendar = calendar

        let defaultStart = calendar.date(byAdding: .day, value: 21, to: calendar.startOfDay(for: .now)) ?? .now
        self.startDate = defaultStart

        // Everything the home surface already knows, so the interview asks only what
        // is left. A question already answered and asked again reads as not listening.
        if let seed {
            if !seed.destination.isEmpty { destinationName = seed.destination }
            startDate = seed.startDate
            nights = seed.nights
            travelStyle = seed.travelStyle
            pace = seed.pace
            budget = seed.budget
            diet = seed.diet
            party = seed.party
            paceOverride = seed.paceOverride
            searchQuery = seed.destination
        }

        if let preselectedDestination {
            selectedDestination = preselectedDestination
            destinationName = preselectedDestination.name
            nights = preselectedDestination.suggestedNights
            currentStep = .datesAndDuration
        } else if let initialCity, !initialCity.isEmpty {
            destinationName = initialCity
            searchQuery = initialCity
        }

        if let step, let resumed = Step(rawValue: step) {
            currentStep = resumed
        } else if seed?.destination.isEmpty == false, currentStep == .destination {
            // A destination arrived with the seed, so that question is answered.
            currentStep = .datesAndDuration
        }
    }

    // MARK: - Lifecycle & Search

    func load() async {
        isLoadingDestinations = true
        defer { isLoadingDestinations = false }

        if let popular = try? await catalogue.popular() {
            popularDestinations = popular
        }
        await updateSearch()
        await loadCandidates()
    }

    func updateSearch() async {
        guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = popularDestinations
            return
        }
        searchResults = (try? await catalogue.search(query: searchQuery)) ?? []
    }

    /// The places a plan for this destination could hold.
    ///
    /// Needed by the travel-party step, which cannot say what a party changes without
    /// knowing what it is changing.
    private func loadCandidates() async {
        guard let destination = try? await catalogue.destination(matching: destinationName) else {
            candidatePlaces = []
            return
        }
        candidatePlaces = (try? await catalogue.candidatePlaces(for: destination.id)) ?? []
    }

    func selectDestination(_ destination: Destination) {
        selectedDestination = destination
        destinationName = destination.name
        searchQuery = destination.name
        nights = destination.suggestedNights
        Task { await loadCandidates() }
    }

    func applyCustomDestination(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        selectedDestination = nil
        destinationName = trimmed
    }

    // MARK: - Dates & duration

    var earliestStartDate: Date { calendar.startOfDay(for: .now) }

    func setQuickDate(daysFromNow: Int) {
        let today = calendar.startOfDay(for: .now)
        if let newDate = calendar.date(byAdding: .day, value: daysFromNow, to: today) {
            startDate = newDate
        }
    }

    func setNights(_ count: Int) { nights = max(1, min(count, 30)) }
    func adjustNights(by delta: Int) { setNights(nights + delta) }

    // MARK: - Pace

    func selectPace(_ value: TripBrief.Pace) {
        pace = value
        paceOverride = nil
    }

    /// Switching to the custom card seeds it from whichever bucket was live, so the
    /// first thing the traveller sees is what they already had — not a reset.
    func selectCustomPace() {
        guard paceOverride == nil else { return }
        paceOverride = TripBrief.PaceOverride(itemsPerBlock: pace.maxItemsPerBlock,
                                              walkingMetres: pace.maxWalkingDistanceInBlock,
                                              dayStartsAt: MinuteOfDay(hour: 9))
    }

    // MARK: - Party

    func applyPreset(_ preset: TravelParty) {
        party = preset
    }

    func setAdults(_ count: Int) { party.adults = max(1, min(count, 9)) }

    /// Adding a child appends a default age rather than opening a picker straight
    /// away: a stepper that popped a modal on every tap would be unusable, and the
    /// age chip beneath is right there.
    func setChildren(_ count: Int) {
        let count = max(0, min(count, 6))
        if count > party.childAges.count {
            party.childAges.append(contentsOf: Array(repeating: Self.defaultChildAge,
                                                     count: count - party.childAges.count))
        } else if count < party.childAges.count {
            party.childAges.removeLast(party.childAges.count - count)
        }
    }

    func setAge(_ age: Int, forChildAt index: Int) {
        guard party.childAges.indices.contains(index) else { return }
        party.childAges[index] = max(0, min(age, 17))
    }

    func toggle(_ accommodation: TravelParty.Accommodation) {
        if party.accommodations.contains(accommodation) {
            party.accommodations.remove(accommodation)
        } else {
            party.accommodations.insert(accommodation)
        }
    }

    /// What the party changes, computed from the same values composition uses.
    var partyEffects: [TravelPartyEffect] {
        TravelPartyEffects(party: party).summary(against: candidatePlaces)
    }

    private static let defaultChildAge = 7

    // MARK: - Navigation

    var canProceed: Bool {
        switch currentStep {
        case .destination:
            !destinationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .datesAndDuration, .styleAndPace, .travelParty, .budgetAndDiet, .summary:
            true
        }
    }

    var isLastStep: Bool { currentStep == .summary }
    var stepCount: Int { Step.allCases.count }

    func nextStep() {
        guard canProceed, let next = Step(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = next
        if next == .travelParty { Task { await loadCandidates() } }
    }

    func previousStep() {
        guard let previous = Step(rawValue: currentStep.rawValue - 1) else { return }
        currentStep = previous
    }

    func goTo(step: Step) { currentStep = step }

    // MARK: - Drafts

    private func saveDraft() {
        guard let drafts, !destinationName.isEmpty, !isLastStep else { return }
        let draft = InterviewDraft(destination: destinationName,
                                   step: currentStep.rawValue,
                                   totalSteps: stepCount,
                                   nights: nights)
        Task { await drafts.save(draft) }
    }

    /// Called once the plan is generated: a draft for a trip that now exists is
    /// clutter offering to redo work already done.
    func clearDraft() {
        guard let drafts, !destinationName.isEmpty else { return }
        let id = destinationName.lowercased()
        Task { await drafts.delete(id: id) }
    }

    // MARK: - Brief

    var brief: TripBrief {
        TripBrief(destination: destinationName.trimmingCharacters(in: .whitespacesAndNewlines),
                  startDate: startDate,
                  nights: nights,
                  travelStyle: travelStyle,
                  pace: pace,
                  budget: budget,
                  diet: diet,
                  party: party,
                  paceOverride: paceOverride,
                  sourceText: nil)
    }
}
