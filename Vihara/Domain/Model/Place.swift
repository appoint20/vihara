import Foundation

/// A real-world place, resolved against live data before it is ever shown (F-03).
///
/// A `Place` only exists once it has passed the validation gate, so there is no
/// "unverified place" state to render defensively against: if it is in the model,
/// it resolved.
struct Place: Hashable, Sendable, Identifiable {
    let id: Identifier<Place>
    /// The provider's stable place id. Storable indefinitely; the detail fields
    /// around it are cache-limited (PRD 6.5).
    let providerPlaceID: String
    let name: String
    let address: String
    let coordinate: Coordinate
    /// Opening window on the day this place was planned for, if it keeps hours.
    let openingHours: OpeningWindow?
    let dietSignal: DietSignal
    /// Entry needs to be bought ahead — surfaced as a warning, not a booking button.
    let requiresTicket: Bool

    init(id: Identifier<Place> = .generate(),
         providerPlaceID: String,
         name: String,
         address: String,
         coordinate: Coordinate,
         openingHours: OpeningWindow? = nil,
         dietSignal: DietSignal = .notApplicable,
         requiresTicket: Bool = false) {
        self.id = id
        self.providerPlaceID = providerPlaceID
        self.name = name
        self.address = address
        self.coordinate = coordinate
        self.openingHours = openingHours
        self.dietSignal = dietSignal
        self.requiresTicket = requiresTicket
    }
}

struct Coordinate: Hashable, Sendable {
    let latitude: Double
    let longitude: Double
}

/// Opening hours for one specific day, in minutes from midnight.
struct OpeningWindow: Hashable, Sendable {
    let opensAt: MinuteOfDay
    let closesAt: MinuteOfDay

    func contains(_ minute: MinuteOfDay) -> Bool {
        minute >= opensAt && minute < closesAt
    }

    /// Whether a visit starting at `minute` and lasting `duration` finishes before
    /// closing. Used by reflow to warn rather than silently reshuffle (F-06).
    func admits(start: MinuteOfDay, duration: Int) -> Bool {
        start >= opensAt && start + duration <= closesAt
    }
}

/// Minutes since midnight. A plain `Int` invites arithmetic against durations and
/// distances; this does not.
struct MinuteOfDay: Hashable, Comparable, Sendable {
    let rawValue: Int

    init(_ rawValue: Int) { self.rawValue = rawValue }
    init(hour: Int, minute: Int = 0) { self.rawValue = hour * 60 + minute }

    var hour: Int { rawValue / 60 }
    var minute: Int { rawValue % 60 }

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
    static func + (lhs: Self, minutes: Int) -> Self { Self(lhs.rawValue + minutes) }
}

/// The three-stage diet verification from PRD 6.5.
///
/// The distinction between ``confirmed`` and ``likely`` is a product promise, not a
/// nicety: "vegetarisch bestätigt" may only ever come from a provider attribute or a
/// structured menu. Review-text inference is a weak signal and must read differently
/// in the UI.
enum DietSignal: Hashable, Sendable {
    /// Stage 1 or 2 — provider attribute or the venue's own structured menu.
    case confirmed(DietSignal.Diet, source: Source)
    /// Stage 3 — inferred from review text. Shown as "wahrscheinlich".
    case likely(DietSignal.Diet)
    /// Checked, nothing found.
    case unknown
    /// Not a place where diet is a question (a basilica, a viewpoint).
    case notApplicable

    enum Diet: String, Hashable, Sendable {
        case vegetarian
        case vegan
    }

    enum Source: String, Hashable, Sendable {
        case providerAttribute
        case venueMenu
    }

    /// Does this place satisfy `requirement` well enough to be offered for it?
    ///
    /// Vegan implies vegetarian; the converse does not hold.
    func satisfies(_ requirement: TripBrief.DietRequirement) -> Bool {
        guard requirement.requiresSignal else { return true }
        switch self {
        case let .confirmed(diet, _), let .likely(diet):
            return diet == .vegan || diet.rawValue == requirement.rawValue
        case .unknown, .notApplicable:
            return false
        }
    }
}
