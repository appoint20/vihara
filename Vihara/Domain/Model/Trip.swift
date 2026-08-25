import Foundation

/// A plan. The whole product in one value type.
///
/// Three levels deep and no further — Trip → Day → Item — which is the structural
/// half of the No-Cockpit rule (PRD 5.1). Anything that would add a fourth level
/// belongs behind a tap, not in this model.
struct Trip: Hashable, Sendable, Identifiable {
    let id: Identifier<Trip>
    var brief: TripBrief
    var days: [TripDay]
    /// Bumped on every accepted edit. Exports are idempotent per `(id, revision)`,
    /// so a double tap on download can never be billed twice (PRD 4.2).
    var revision: Int
    let createdAt: Date

    init(id: Identifier<Trip> = .generate(),
         brief: TripBrief,
         days: [TripDay] = [],
         revision: Int = 0,
         createdAt: Date = .now) {
        self.id = id
        self.brief = brief
        self.days = days
        self.revision = revision
        self.createdAt = createdAt
    }

    var itemCount: Int {
        days.reduce(0) { $0 + $1.itemCount }
    }
}

/// One day, and exactly three named blocks. Always three, even when a block is
/// empty — the shape of a day is a constant of the product, not data.
struct TripDay: Hashable, Sendable, Identifiable {
    let id: Identifier<TripDay>
    let date: Date
    /// Where the traveller is on this day. Changes across a round trip.
    let city: String
    var blocks: [DayBlock]
    /// Present when this day begins somewhere the previous day did not end (F-07).
    var arrivalTransfer: Transfer?

    init(id: Identifier<TripDay> = .generate(),
         date: Date,
         city: String,
         blocks: [DayBlock]? = nil,
         arrivalTransfer: Transfer? = nil) {
        self.id = id
        self.date = date
        self.city = city
        self.blocks = blocks ?? DaySlot.allCases.map { DayBlock(slot: $0) }
        self.arrivalTransfer = arrivalTransfer
    }

    var itemCount: Int {
        blocks.reduce(0) { $0 + $1.items.count }
    }

    subscript(slot: DaySlot) -> DayBlock? {
        blocks.first { $0.slot == slot }
    }
}

/// Half a day. Holds nought to three items (PRD 3.2).
struct DayBlock: Hashable, Sendable, Identifiable {
    let id: Identifier<DayBlock>
    let slot: DaySlot
    var items: [ItineraryItem]

    init(id: Identifier<DayBlock> = .generate(),
         slot: DaySlot,
         items: [ItineraryItem] = []) {
        self.id = id
        self.slot = slot
        self.items = items
    }

    var isEmpty: Bool { items.isEmpty }
}

/// Morning, afternoon, evening. There is no time axis in the plan and there are no
/// other slots; both are deliberate (PRD 3.2).
enum DaySlot: String, CaseIterable, Hashable, Sendable {
    case morning
    case afternoon
    case evening

    /// The window a block's items must fall inside.
    var window: OpeningWindow {
        switch self {
        case .morning:   OpeningWindow(opensAt: MinuteOfDay(hour: 8),  closesAt: MinuteOfDay(hour: 13))
        case .afternoon: OpeningWindow(opensAt: MinuteOfDay(hour: 13), closesAt: MinuteOfDay(hour: 18))
        case .evening:   OpeningWindow(opensAt: MinuteOfDay(hour: 18), closesAt: MinuteOfDay(hour: 23))
        }
    }

    /// Slots that must carry a meal.
    ///
    /// Evening only. PRD 3.1 asks for "Essensbaustein je Mittag und Abend", but the
    /// day has no midday block — and the PRD's own Abb. 1 shows a Bologna afternoon
    /// with only the Torre in it. Open question for the PM: does lunch belong to
    /// Vormittag or Nachmittag? Until that is settled, requiring one in a block that
    /// ends at 18:00 would put a warning on every plan we generate.
    var expectsMeal: Bool {
        self == .evening
    }
}

/// A building block — a *Baustein*. The unit the traveller drags, pins and swaps.
struct ItineraryItem: Hashable, Sendable, Identifiable {
    let id: Identifier<ItineraryItem>
    let place: Place
    let kind: Kind
    /// When the plan puts this. Nil for an item with no meaningful clock time.
    var startsAt: MinuteOfDay?
    var durationMinutes: Int
    /// A pinned item is a hard constraint: reflow works around it, never on it (F-05).
    var isPinned: Bool
    /// How the traveller gets here from the item before it. Rendered as an aside
    /// between items, never as a row of its own (PRD 3.2).
    var travelFromPrevious: TravelLeg?

    init(id: Identifier<ItineraryItem> = .generate(),
         place: Place,
         kind: Kind,
         startsAt: MinuteOfDay? = nil,
         durationMinutes: Int = 60,
         isPinned: Bool = false,
         travelFromPrevious: TravelLeg? = nil) {
        self.id = id
        self.place = place
        self.kind = kind
        self.startsAt = startsAt
        self.durationMinutes = durationMinutes
        self.isPinned = isPinned
        self.travelFromPrevious = travelFromPrevious
    }

    enum Kind: String, CaseIterable, Hashable, Sendable {
        case sight
        case meal
        case activity
        case lodging
    }

    /// A block may hold at most one headline sight (PRD 3.1, composition).
    var isHeadline: Bool { kind == .sight }
}

/// Getting from one item to the next inside a day.
struct TravelLeg: Hashable, Sendable {
    let mode: Mode
    let minutes: Int

    enum Mode: String, Hashable, Sendable {
        case walk
        case transit
        case taxi
    }
}

/// Getting between two places on the trip. Shown as a comparison, never as live
/// fares — a price band is enough to choose train over car (PRD 3.4).
struct Transfer: Hashable, Sendable {
    let origin: String
    let destination: String
    let options: [Option]

    struct Option: Hashable, Sendable, Identifiable {
        let id: Identifier<Option>
        let mode: Mode
        let minutes: Int
        let priceBand: PriceBand
        /// A short caveat: "Zentrum zu Zentrum", "ZTL-Sperrzone im Zentrum".
        let note: String?
        /// Which partner the booking button hands off to (F-10, phase 2).
        let partner: AffiliatePartner?

        init(id: Identifier<Option> = .generate(),
             mode: Mode,
             minutes: Int,
             priceBand: PriceBand,
             note: String? = nil,
             partner: AffiliatePartner? = nil) {
            self.id = id
            self.mode = mode
            self.minutes = minutes
            self.priceBand = priceBand
            self.note = note
            self.partner = partner
        }
    }

    enum Mode: String, CaseIterable, Hashable, Sendable {
        case highSpeedTrain
        case regionalTrain
        case rentalCar
        case coach
        case ferry
    }
}

enum AffiliatePartner: String, Hashable, Sendable {
    case booking
    case discoverCars
    case trainline
    case getYourGuide
}
