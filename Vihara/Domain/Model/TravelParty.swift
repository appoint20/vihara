import Foundation

/// Who is going.
///
/// This is not a headcount for a booking form. Every field here changes what gets
/// composed: an age limit removes a candidate outright, a nap takes a window out of
/// the afternoon, and the party's shape decides when dinner starts and what the
/// tickets cost. A `TravelParty` that did not reach composition would be a question
/// asked for nothing, and the interview does not ask those.
struct TravelParty: Hashable, Sendable {
    var adults: Int
    /// One entry per child, in years. Ages rather than a count, because an age limit
    /// is the single most common reason a plan has to drop a stop, and "two children"
    /// cannot answer it.
    var childAges: [Int]
    var accommodations: Set<Accommodation>

    init(adults: Int = 2, childAges: [Int] = [], accommodations: Set<Accommodation> = []) {
        self.adults = max(1, adults)
        self.childAges = childAges
        self.accommodations = accommodations
    }

    /// What the interview offers before anyone touches a stepper.
    static let solo = TravelParty(adults: 1)
    static let couple = TravelParty(adults: 2)
    static let family = TravelParty(adults: 2, childAges: [7], accommodations: [.pushchair])

    // MARK: - Shape

    var childCount: Int { childAges.count }
    var size: Int { adults + childCount }
    var hasChildren: Bool { !childAges.isEmpty }
    var youngestChildAge: Int? { childAges.min() }

    // MARK: - What it does to a plan

    /// Whether everyone in the party may enter.
    ///
    /// One child below the limit rules the place out for the whole party — splitting
    /// up is not a plan, it is a compromise the traveller should be offered rather
    /// than have made for them.
    func admits(_ place: Place) -> Bool {
        guard let minimumAge = place.minimumAge else { return true }
        return childAges.allSatisfy { $0 >= minimumAge }
    }

    /// The child who is turned away, if any. Drives the wording of the explanation.
    func childBlocked(by place: Place) -> Int? {
        guard let minimumAge = place.minimumAge else { return nil }
        return childAges.filter { $0 < minimumAge }.min()
    }

    /// The afternoon window a nap takes out of the day.
    ///
    /// Only when the traveller asked for it *and* somebody in the party still naps.
    /// A stated preference with no toddler behind it would quietly cost the party
    /// two hours of their afternoon for nothing.
    var napWindow: OpeningWindow? {
        guard accommodations.contains(.middaySleep),
              let youngest = youngestChildAge, youngest <= Self.napsUntilAge
        else { return nil }
        return OpeningWindow(opensAt: MinuteOfDay(hour: 13), closesAt: MinuteOfDay(hour: 15))
    }

    /// When the evening meal should start.
    ///
    /// An hour earlier with children. Not a nicety: a 19:30 booking with a five-year-old
    /// is a booking nobody enjoys, and moving it is the kind of thing a good human
    /// planner does without being asked.
    var eveningMealStart: MinuteOfDay {
        hasChildren ? MinuteOfDay(hour: 18, minute: 30) : MinuteOfDay(hour: 19, minute: 30)
    }

    /// What the party pays to get in, or `nil` where entry is free or unpriced.
    ///
    /// Children under the concession age cost nothing, which is a real saving worth
    /// showing rather than a rounding error to bury.
    func admissionCost(for place: Place) -> Money? {
        guard let admission = place.admission else { return nil }
        let payingChildren = admission.freeUnderAge.map { free in
            childAges.filter { $0 >= free }.count
        } ?? childCount
        let heads = adults + payingChildren
        return Money(admission.adultPrice.amount * Decimal(heads), admission.adultPrice.currency)
    }

    /// How many of the party's children get in free at this place.
    func childrenAdmittedFree(at place: Place) -> Int {
        guard let freeUnderAge = place.admission?.freeUnderAge else { return 0 }
        return childAges.filter { $0 < freeUnderAge }.count
    }

    /// Above this age a child is assumed to have grown out of an afternoon nap.
    private static let napsUntilAge = 5

    /// A consideration the plan has to respect.
    ///
    /// A closed set: each case is something composition genuinely acts on, so adding
    /// one is a change to the planner, not a new checkbox.
    enum Accommodation: String, CaseIterable, Hashable, Sendable, Identifiable {
        /// Mittagsschlaf — an afternoon window kept clear.
        case middaySleep
        /// Kinderwagen — step-free routing and no long stair climbs.
        case pushchair
        /// Barrierefrei — step-free access is required, not preferred.
        case stepFree
        /// Kein langes Stehen — nothing with a standing queue.
        case noLongStanding

        var id: String { rawValue }

        /// Whether this consideration needs a place to be reachable without stairs.
        var requiresStepFreeAccess: Bool {
            self == .pushchair || self == .stepFree
        }
    }
}

/// What it costs to get in.
///
/// A single adult price and a concession age, not a fare table. The plan answers
/// "roughly what will today cost us", which does not need family tickets, city cards
/// or the seventeen combinations a ticketing API would return.
struct Admission: Hashable, Sendable {
    let adultPrice: Money
    /// Children below this age enter free. `nil` when everybody pays.
    let freeUnderAge: Int?

    init(adultPrice: Money, freeUnderAge: Int? = nil) {
        self.adultPrice = adultPrice
        self.freeUnderAge = freeUnderAge
    }
}

extension TravelParty {
    /// The items this party may actually visit.
    ///
    /// Lives on the party rather than in the composer so every composition path —
    /// the stub today, the server's response tomorrow — filters the same way.
    func admissible(_ items: [ItineraryItem]) -> [ItineraryItem] {
        items.filter { admits($0.place) }
    }
}
