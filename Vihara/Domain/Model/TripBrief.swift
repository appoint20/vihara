import Foundation

/// What the traveller asked for — the structured result of intake (F-01).
///
/// The free-text sentence ("5 Tage Emilia-Romagna, vegetarisch, entspanntes Tempo")
/// is parsed into this by ``TripBriefParsing`` and mirrored back to the traveller as
/// editable chips. Generation never reads the raw sentence; it reads this.
struct TripBrief: Hashable, Sendable {
    var destination: String
    var startDate: Date
    /// Nights away. Day count is `nights + 1`.
    var nights: Int
    var travelStyle: TravelStyle
    var pace: Pace
    var budget: BudgetBand
    var diet: DietRequirement

    /// The sentence the traveller typed, kept for support and for re-parsing after an
    /// intake-model change. Never an input to composition.
    var sourceText: String?

    init(destination: String,
         startDate: Date,
         nights: Int,
         travelStyle: TravelStyle = .cityBreak,
         pace: Pace = .balanced,
         budget: BudgetBand = .middle,
         diet: DietRequirement = .none,
         sourceText: String? = nil) {
        self.destination = destination
        self.startDate = startDate
        self.nights = nights
        self.travelStyle = travelStyle
        self.pace = pace
        self.budget = budget
        self.diet = diet
        self.sourceText = sourceText
    }

    var dayCount: Int { nights + 1 }

    /// A brief is only complete enough to generate from once it names somewhere to go
    /// and how long for. Everything else has a defensible default.
    var isGeneratable: Bool {
        !destination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && nights >= 1
    }
}

extension TripBrief {

    enum TravelStyle: String, CaseIterable, Hashable, Sendable {
        case cityBreak
        case roundTrip
    }

    /// Drives how many items a block may hold and how far apart they may sit.
    enum Pace: String, CaseIterable, Hashable, Sendable {
        case relaxed
        case balanced
        case packed

        /// Upper bound on items per block. A block holds nought to three (PRD 3.2).
        var maxItemsPerBlock: Int {
            switch self {
            case .relaxed:  1
            case .balanced: 2
            case .packed:   3
            }
        }

        /// How far the traveller will walk within one block, in metres.
        var maxWalkingDistanceInBlock: Int {
            switch self {
            case .relaxed:  900
            case .balanced: 1400
            case .packed:   2000
            }
        }
    }

    enum BudgetBand: String, CaseIterable, Hashable, Sendable {
        case thrifty
        case middle
        case premium
    }

    enum DietRequirement: String, CaseIterable, Hashable, Sendable {
        case none
        case vegetarian
        case vegan

        /// Whether a meal must carry a diet signal at all.
        var requiresSignal: Bool { self != .none }
    }
}
