import Foundation

/// Turns wire DTOs into domain values, and refuses anything it cannot represent.
///
/// Mapping fails loudly rather than filling in blanks: a day with an unknown slot or
/// an unparseable time is a contract break, and rendering a half-understood plan is
/// worse than reporting the error. The traveller sees the failure as a retry, never
/// as a plausible-looking wrong plan.
struct TripStreamMapper: Sendable {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func day(from dto: TripStreamDTO.Day) throws -> TripDay {
        guard let date = Self.date(from: dto.date, calendar: calendar) else {
            throw DomainError.unexpectedResponse
        }
        // A day always has all three blocks. Anything the server omits comes through
        // as empty rather than absent, so the UI has no "missing block" case.
        let mapped = try dto.blocks.map(block(from:))
        let blocks = DaySlot.allCases.map { slot in
            mapped.first { $0.slot == slot } ?? DayBlock(slot: slot)
        }
        return TripDay(id: Identifier(dto.id), date: date, city: dto.city, blocks: blocks)
    }

    func block(from dto: TripStreamDTO.Block) throws -> DayBlock {
        guard let slot = DaySlot(rawValue: dto.slot) else { throw DomainError.unexpectedResponse }
        return DayBlock(id: Identifier(dto.id), slot: slot, items: try dto.items.map(item(from:)))
    }

    func item(from dto: TripStreamDTO.Item) throws -> ItineraryItem {
        guard let kind = ItineraryItem.Kind(rawValue: dto.kind) else {
            throw DomainError.unexpectedResponse
        }
        var startsAt: MinuteOfDay?
        if let raw = dto.startsAt {
            guard let parsed = Self.minute(from: raw) else { throw DomainError.unexpectedResponse }
            startsAt = parsed
        }
        return ItineraryItem(
            id: Identifier(dto.id),
            place: try place(from: dto.place),
            kind: kind,
            startsAt: startsAt,
            durationMinutes: dto.durationMinutes,
            isPinned: dto.pinned,
            travelFromPrevious: try dto.travelFromPrevious.map(travel(from:))
        )
    }

    func travel(from dto: TripStreamDTO.Travel) throws -> TravelLeg {
        guard let mode = TravelLeg.Mode(rawValue: dto.mode) else {
            throw DomainError.unexpectedResponse
        }
        return TravelLeg(mode: mode, minutes: dto.minutes)
    }

    func place(from dto: TripStreamDTO.Place) throws -> Place {
        var hours: OpeningWindow?
        if let opens = dto.opensAt, let closes = dto.closesAt {
            guard let from = Self.minute(from: opens), let to = Self.minute(from: closes) else {
                throw DomainError.unexpectedResponse
            }
            hours = OpeningWindow(opensAt: from, closesAt: to)
        }
        return Place(
            id: Identifier(dto.id),
            providerPlaceID: dto.providerPlaceId,
            name: dto.name,
            address: dto.address,
            coordinate: Coordinate(latitude: dto.lat, longitude: dto.lng),
            openingHours: hours,
            dietSignal: dietSignal(from: dto.diet),
            requiresTicket: dto.requiresTicket
        )
    }

    /// An unrecognised diet payload degrades to ``DietSignal/unknown`` rather than
    /// throwing. Getting this wrong in the safe direction costs a badge; getting it
    /// wrong in the unsafe direction puts a vegan in front of a meat menu.
    func dietSignal(from dto: TripStreamDTO.Diet?) -> DietSignal {
        guard let dto else { return .notApplicable }
        switch dto.status {
        case "confirmed":
            guard let diet = dto.diet.flatMap(DietSignal.Diet.init(rawValue:)),
                  let source = dto.source.flatMap(DietSignal.Source.init(rawValue:))
            else { return .unknown }
            return .confirmed(diet, source: source)
        case "likely":
            guard let diet = dto.diet.flatMap(DietSignal.Diet.init(rawValue:)) else { return .unknown }
            return .likely(diet)
        case "notApplicable":
            return .notApplicable
        default:
            return .unknown
        }
    }

    // MARK: - Scalars

    /// `HH:mm` → minutes since midnight.
    static func minute(from raw: String) -> MinuteOfDay? {
        let parts = raw.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]), let minute = Int(parts[1]),
              (0...23).contains(hour), (0...59).contains(minute)
        else { return nil }
        return MinuteOfDay(hour: hour, minute: minute)
    }

    /// `yyyy-MM-dd` → the start of that calendar day.
    static func date(from raw: String, calendar: Calendar) -> Date? {
        let parts = raw.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2])
        else { return nil }
        return calendar.date(from: DateComponents(year: year, month: month, day: day))
    }
}
