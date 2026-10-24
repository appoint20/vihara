import Foundation

/// Something about the plan the traveller should know, phrased as a fact rather than
/// a correction.
///
/// Warnings exist because of a product rule: when an edit creates a conflict we
/// *say so* rather than silently reshuffling (F-06). Silent correction is the
/// trust-breaking behaviour the PRD calls out in competitors.
struct PlanWarning: Hashable, Sendable, Identifiable {
    let id: Identifier<PlanWarning>
    /// Which half-day the warning belongs to. Always known — warnings are produced
    /// per block — so the UI routes them without inspecting the case payload.
    let slot: DaySlot
    /// Set when the warning is about one item rather than the block as a whole.
    let itemID: Identifier<ItineraryItem>?
    let kind: Kind

    init(id: Identifier<PlanWarning> = .generate(),
         slot: DaySlot,
         itemID: Identifier<ItineraryItem>? = nil,
         kind: Kind) {
        self.id = id
        self.slot = slot
        self.itemID = itemID
        self.kind = kind
    }

    enum Kind: Hashable, Sendable {
        /// The visit does not fit inside the venue's opening hours.
        case closedAtPlannedTime(place: String)
        /// The block holds more than this pace allows.
        case blockOverfull(limit: Int)
        /// Two headline sights in one half-day.
        case competingHeadlines
        /// The traveller stated a diet and this block's meal cannot be verified.
        case mealNotVerifiedForDiet(place: String, diet: TripBrief.DietRequirement)
        /// A meal block with no meal in it.
        case missingMeal
        /// More walking inside one block than the pace allows.
        case excessiveWalking(minutes: Int, limit: Int)
    }
}

/// The composition constraints from PRD 3.1, in one testable place.
///
/// This is the half of reflow that does not need a model: after any edit the client
/// can name every conflict locally and instantly, and the server round trip is only
/// needed to *propose* fixes. It is also what keeps generation honest — a day that
/// fails these rules should never have been streamed.
struct ItineraryRules: Sendable {
    let brief: TripBrief

    init(brief: TripBrief) {
        self.brief = brief
    }

    /// Every conflict in a day, in reading order.
    func warnings(for day: TripDay) -> [PlanWarning] {
        day.blocks.flatMap(warnings(for:))
    }

    func warnings(for block: DayBlock) -> [PlanWarning] {
        var found: [PlanWarning] = []

        if block.items.count > brief.maxItemsPerBlock {
            found.append(PlanWarning(slot: block.slot,
                                     kind: .blockOverfull(limit: brief.maxItemsPerBlock)))
        }

        if block.items.filter(\.isHeadline).count > 1 {
            found.append(PlanWarning(slot: block.slot, kind: .competingHeadlines))
        }

        let meals = block.items.filter { $0.kind == .meal }
        if block.slot.expectsMeal, meals.isEmpty, !block.isEmpty {
            found.append(PlanWarning(slot: block.slot, kind: .missingMeal))
        }

        for meal in meals where !meal.place.dietSignal.satisfies(brief.diet) {
            found.append(PlanWarning(slot: block.slot,
                                     itemID: meal.id,
                                     kind: .mealNotVerifiedForDiet(place: meal.place.name,
                                                                   diet: brief.diet)))
        }

        for item in block.items {
            guard let hours = item.place.openingHours, let start = item.startsAt else { continue }
            if !hours.admits(start: start, duration: item.durationMinutes) {
                found.append(PlanWarning(slot: block.slot,
                                         itemID: item.id,
                                         kind: .closedAtPlannedTime(place: item.place.name)))
            }
        }

        let walking = block.items.compactMap(\.travelFromPrevious)
            .filter { $0.mode == .walk }
            .reduce(0) { $0 + $1.minutes }
        let walkingLimit = walkingMinuteLimit
        if walking > walkingLimit {
            found.append(PlanWarning(slot: block.slot,
                                     kind: .excessiveWalking(minutes: walking, limit: walkingLimit)))
        }

        return found
    }

    /// Whether an item may move into a block without creating a hard conflict.
    /// Drives whether a drop target lights up (F-05) before the drop happens.
    func canAccept(_ item: ItineraryItem, into block: DayBlock) -> Bool {
        guard block.items.count < brief.maxItemsPerBlock else { return false }
        if item.isHeadline, block.items.contains(where: \.isHeadline) { return false }
        return true
    }

    /// The pace's walking allowance expressed in minutes, at a normal 80 m/min.
    private var walkingMinuteLimit: Int {
        brief.maxWalkingDistanceInBlock / 80
    }
}
