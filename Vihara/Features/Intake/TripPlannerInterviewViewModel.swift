import Foundation
import SwiftUI

/// Manages the state and step-by-step interview flow for the Wanderlog-style Trip Planner.
///
/// Converts a structured interview into a valid ``TripBrief`` ready for plan generation.
@MainActor
@Observable
final class TripPlannerInterviewViewModel {

    enum Step: Int, CaseIterable, Identifiable, Comparable {
        case destination = 0
        case datesAndDuration = 1
        case styleAndPace = 2
        case budgetAndDiet = 3
        case summary = 4

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .destination:      return "Wohin möchtest du?"
            case .datesAndDuration: return "Wann & wie lange?"
            case .styleAndPace:     return "Reisestil & Tempo"
            case .budgetAndDiet:    return "Budget & Ernährung"
            case .summary:          return "Dein Reise-Setup"
            }
        }

        var subtitle: String {
            switch self {
            case .destination:      return "Wähle eine kuratierte Region oder gib deine Wunschstadt ein."
            case .datesAndDuration: return "Reisedatum und Dauer für deine maßgeschneiderte Route."
            case .styleAndPace:     return "Wie viele Stationen und Highlights möchtest du pro Tag?"
            case .budgetAndDiet:    return "Passgenaue Empfehlungen für Restaurants und Aktivitäten."
            case .summary:          return "Alles bereit. Wir erstellen deinen Tagesplan in Echtzeit."
            }
        }

        static func < (lhs: Step, rhs: Step) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    private let catalogue: any DestinationCatalogue
    private let calendar: Calendar

    // MARK: - State

    var currentStep: Step = .destination
    var searchQuery: String = ""
    private(set) var searchResults: [Destination] = []
    private(set) var popularDestinations: [Destination] = []
    private(set) var isLoadingDestinations: Bool = false

    // Brief values
    var destinationName: String = ""
    var selectedDestination: Destination? = nil
    var startDate: Date
    var nights: Int = 3
    var travelStyle: TripBrief.TravelStyle = .cityBreak
    var pace: TripBrief.Pace = .balanced
    var budget: TripBrief.BudgetBand = .middle
    var diet: TripBrief.DietRequirement = .none

    init(catalogue: any DestinationCatalogue,
         preselectedDestination: Destination? = nil,
         initialCity: String? = nil,
         calendar: Calendar = .current) {
        self.catalogue = catalogue
        self.calendar = calendar

        let defaultStart = calendar.date(byAdding: .day, value: 21, to: calendar.startOfDay(for: .now)) ?? .now
        self.startDate = defaultStart

        if let preselectedDestination {
            self.selectedDestination = preselectedDestination
            self.destinationName = preselectedDestination.name
            self.nights = preselectedDestination.suggestedNights
            self.currentStep = .datesAndDuration
        } else if let initialCity, !initialCity.isEmpty {
            self.destinationName = initialCity
            self.searchQuery = initialCity
        }
    }

    // MARK: - Lifecycle & Search

    func load() async {
        isLoadingDestinations = true
        defer { isLoadingDestinations = false }

        if let popular = try? await catalogue.popular() {
            self.popularDestinations = popular
        }
        await updateSearch()
    }

    func updateSearch() async {
        guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = popularDestinations
            return
        }

        if let results = try? await catalogue.search(query: searchQuery) {
            self.searchResults = results
        } else {
            self.searchResults = []
        }
    }

    func selectDestination(_ destination: Destination) {
        self.selectedDestination = destination
        self.destinationName = destination.name
        self.searchQuery = destination.name
        self.nights = destination.suggestedNights
    }

    func applyCustomDestination(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        self.selectedDestination = nil
        self.destinationName = trimmed
    }

    // MARK: - Dates & Duration

    var earliestStartDate: Date {
        calendar.startOfDay(for: .now)
    }

    func setQuickDate(daysFromNow: Int) {
        let today = calendar.startOfDay(for: .now)
        if let newDate = calendar.date(byAdding: .day, value: daysFromNow, to: today) {
            self.startDate = newDate
        }
    }

    func setNights(_ count: Int) {
        self.nights = max(1, min(count, 30))
    }

    func adjustNights(by delta: Int) {
        setNights(nights + delta)
    }

    // MARK: - Navigation

    var canProceed: Bool {
        switch currentStep {
        case .destination:
            return !destinationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .datesAndDuration, .styleAndPace, .budgetAndDiet, .summary:
            return true
        }
    }

    var isLastStep: Bool {
        currentStep == .summary
    }

    func nextStep() {
        guard canProceed else { return }
        if let next = Step(rawValue: currentStep.rawValue + 1) {
            currentStep = next
        }
    }

    func previousStep() {
        if let prev = Step(rawValue: currentStep.rawValue - 1) {
            currentStep = prev
        }
    }

    func goTo(step: Step) {
        currentStep = step
    }

    // MARK: - Brief Synthesis

    var brief: TripBrief {
        TripBrief(
            destination: destinationName.trimmingCharacters(in: .whitespacesAndNewlines),
            startDate: startDate,
            nights: nights,
            travelStyle: travelStyle,
            pace: pace,
            budget: budget,
            diet: diet,
            sourceText: synthesizedSentence
        )
    }

    var formattedStartDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "d. MMMM yyyy"
        return formatter.string(from: startDate)
    }

    var synthesizedSentence: String {
        var parts: [String] = []
        let days = nights + 1
        parts.append("\(days) Tage \(destinationName.isEmpty ? "Reise" : destinationName)")

        if diet != .none {
            parts.append(diet.label.lowercased())
        }
        parts.append("\(pace.label.lowercased())es Tempo")
        if travelStyle == .roundTrip {
            parts.append("Rundreise")
        }
        return parts.joined(separator: ", ")
    }
}
