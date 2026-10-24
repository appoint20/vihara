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
    /// Who is going. Feeds composition directly — see ``TravelParty``.
    var party: TravelParty
    /// Set when the traveller chose "Eigene Werte" instead of a pace bucket.
    ///
    /// The three named paces are buckets, and a bucket is a guess about somebody. The
    /// override exists so the interview's last card can be an actual answer rather
    /// than the nearest available approximation — and so composition reads the same
    /// numbers either way, through ``maxItemsPerBlock`` and friends below.
    var paceOverride: PaceOverride?

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
         party: TravelParty = .couple,
         paceOverride: PaceOverride? = nil,
         sourceText: String? = nil) {
        self.destination = destination
        self.startDate = startDate
        self.nights = nights
        self.travelStyle = travelStyle
        self.pace = pace
        self.budget = budget
        self.diet = diet
        self.party = party
        self.paceOverride = paceOverride
        self.sourceText = sourceText
    }

    var dayCount: Int { nights + 1 }

    // MARK: - What composition actually reads
    //
    // Always through these, never through `pace` directly: a caller that reaches for
    // `pace.maxItemsPerBlock` silently ignores the traveller's own numbers.

    /// Upper bound on items per block.
    var maxItemsPerBlock: Int {
        paceOverride?.itemsPerBlock ?? pace.maxItemsPerBlock
    }

    /// How far the traveller will walk within one block, in metres.
    var maxWalkingDistanceInBlock: Int {
        paceOverride?.walkingMetres ?? pace.maxWalkingDistanceInBlock
    }

    /// When the day starts. Only an override can move it; the buckets all start at 9.
    var dayStartsAt: MinuteOfDay {
        paceOverride?.dayStartsAt ?? MinuteOfDay(hour: 9)
    }

    /// Roughly how many building blocks this brief produces.
    ///
    /// Three blocks a day, each holding up to the pace's allowance — which is what
    /// the interview's expanded cards report back as "Ergibt 12 Bausteine über 4
    /// Tage". An estimate, and honest about it: the real number depends on how many
    /// candidates survive validation and the party's age limits.
    var estimatedBlockCount: Int {
        dayCount * DaySlot.allCases.count * maxItemsPerBlock
    }

    /// A brief is only complete enough to generate from once it names somewhere to go
    /// and how long for. Everything else has a defensible default.
    var isGeneratable: Bool {
        !destination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && nights >= 1
    }
}

extension TripBrief {

    /// The traveller's own numbers, replacing a pace bucket.
    struct PaceOverride: Hashable, Sendable {
        /// One to three. The day has three blocks and a block holds nought to three
        /// items (PRD 3.2), so this is the whole range there is.
        var itemsPerBlock: Int
        var walkingMetres: Int
        var dayStartsAt: MinuteOfDay

        init(itemsPerBlock: Int = 2,
             walkingMetres: Int = 1400,
             dayStartsAt: MinuteOfDay = MinuteOfDay(hour: 9)) {
            self.itemsPerBlock = min(3, max(1, itemsPerBlock))
            self.walkingMetres = walkingMetres
            self.dayStartsAt = dayStartsAt
        }
    }

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
