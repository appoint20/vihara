import Foundation

/// What to take, derived from the plan (F-12).
///
/// The plan already knows the month, the nights, who is going, how far they walk and
/// whether anything needs a ticket. A packing list the traveller fills in by hand is a
/// list the app had the information to write.
///
/// **Every line carries its reason.** "Regenjacke" on its own is a guess the
/// traveller has to trust; "Regenjacke — im April regnet es in Bologna" is one they
/// can judge. This is the same move as "Warum hier?" on a stop, and it is what stops
/// the list from being the generic checklist every travel blog already has.
struct PackingList: Sendable {
    let brief: TripBrief
    private let calendar: Calendar

    init(brief: TripBrief, calendar: Calendar = .current) {
        self.brief = brief
        self.calendar = calendar
    }

    func sections(for days: [TripDay]) -> [PackingSection] {
        PackingSection.Category.allCases.compactMap { category in
            let items = self.items(in: category, days: days)
            return items.isEmpty ? nil : PackingSection(category: category, items: items)
        }
    }

    private func items(in category: PackingSection.Category, days: [TripDay]) -> [PackingItem] {
        switch category {
        case .documents: documents(days: days)
        case .clothing:  clothing(days: days)
        case .gear:      gear(days: days)
        case .health:    health()
        }
    }

    // MARK: - Rules

    private func documents(days: [TripDay]) -> [PackingItem] {
        var items = [
            PackingItem(key: "packing.item.id", reasonKey: nil),
            PackingItem(key: "packing.item.card", reasonKey: nil),
        ]
        // A ticket bought ahead is a ticket that has to be reachable at the door,
        // and the door is where there is no signal.
        if days.flatMap({ $0.blocks.flatMap(\.items) }).contains(where: \.place.requiresTicket) {
            items.append(PackingItem(key: "packing.item.tickets",
                                     reasonKey: "packing.why.tickets"))
        }
        if brief.party.hasChildren {
            items.append(PackingItem(key: "packing.item.childID",
                                     reasonKey: "packing.why.childID"))
        }
        return items
    }

    private func clothing(days: [TripDay]) -> [PackingItem] {
        var items: [PackingItem] = []

        switch season(of: days.first?.date ?? Date()) {
        case .summer:
            items.append(PackingItem(key: "packing.item.sunHat", reasonKey: "packing.why.summer"))
            items.append(PackingItem(key: "packing.item.lightLayers", reasonKey: nil))
        case .winter:
            items.append(PackingItem(key: "packing.item.warmCoat", reasonKey: "packing.why.winter"))
        case .shoulder:
            items.append(PackingItem(key: "packing.item.rainJacket",
                                     reasonKey: "packing.why.shoulder"))
            items.append(PackingItem(key: "packing.item.lightLayers", reasonKey: nil))
        }

        // The plan counts its own walking, so this is a fact about their days rather
        // than generic advice to wear comfortable shoes.
        let walking = days.reduce(0) { $0 + $1.walkingMinutes }
        if walking >= 60 {
            items.append(PackingItem(key: "packing.item.walkingShoes",
                                     reasonKey: "packing.why.walking",
                                     reasonArgument: "\(walking)"))
        }

        // Below four nights most people pack enough and wash nothing.
        if brief.nights > 4 {
            items.append(PackingItem(key: "packing.item.laundryBag", reasonKey: nil))
        }
        return items
    }

    private func gear(days: [TripDay]) -> [PackingItem] {
        var items = [PackingItem(key: "packing.item.charger", reasonKey: nil)]

        // Offline is free in this app, and a plan read on a street corner is read on
        // a battery that has been navigating all day.
        if days.count > 1 {
            items.append(PackingItem(key: "packing.item.powerBank",
                                     reasonKey: "packing.why.powerBank"))
        }
        if brief.party.hasChildren {
            items.append(PackingItem(key: "packing.item.snacks",
                                     reasonKey: "packing.why.snacks"))
        }
        if brief.party.accommodations.contains(where: \.requiresStepFreeAccess) {
            items.append(PackingItem(key: "packing.item.stepFreeNote",
                                     reasonKey: "packing.why.stepFree"))
        }
        return items
    }

    private func health() -> [PackingItem] {
        var items = [PackingItem(key: "packing.item.medication", reasonKey: nil)]
        if brief.diet.requiresSignal {
            // A plan can only promise what it verified; a long travel day is exactly
            // where the verified options run out.
            items.append(PackingItem(key: "packing.item.dietSnacks",
                                     reasonKey: "packing.why.dietSnacks"))
        }
        return items
    }

    // MARK: - Season

    enum Season: Sendable { case summer, winter, shoulder }

    /// Northern-hemisphere seasons, which is where the pilot region is. A southern
    /// destination needs this inverted, and that is a real gap rather than a detail —
    /// it is noted in the docs rather than quietly wrong here.
    func season(of date: Date) -> Season {
        switch calendar.component(.month, from: date) {
        case 6, 7, 8:        .summer
        case 12, 1, 2:       .winter
        default:             .shoulder
        }
    }
}

struct PackingSection: Hashable, Sendable, Identifiable {
    let category: Category
    let items: [PackingItem]

    var id: Category { category }

    enum Category: String, CaseIterable, Hashable, Sendable {
        case documents
        case clothing
        case gear
        case health

        var labelKey: String { "packing.section.\(rawValue)" }
    }
}

struct PackingItem: Hashable, Sendable, Identifiable {
    /// Localization key for the thing itself.
    let key: String
    /// Localization key for why it is on the list. `nil` for the things nobody needs
    /// a reason for — an ID, a charger.
    let reasonKey: String?
    /// Substituted into the reason, where it takes one.
    let reasonArgument: String?

    var id: String { key }

    init(key: String, reasonKey: String?, reasonArgument: String? = nil) {
        self.key = key
        self.reasonKey = reasonKey
        self.reasonArgument = reasonArgument
    }
}
