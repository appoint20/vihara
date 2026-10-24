import Foundation

/// Translates between saved records and the domain, in both directions.
///
/// Reads fail loudly for the same reason ``TripStreamMapper`` does: a plan we only
/// half understand is worse than one we admit we cannot open. The single exception is
/// again the diet signal, which degrades toward *less* confidence — the one failure
/// direction that can actually hurt someone.
///
/// Writes cannot fail. Every domain value has a representation here by construction,
/// and if that ever stops being true the compiler says so rather than a traveller
/// losing a plan.
struct TripRecordMapper: Sendable {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    // MARK: - Domain → record

    func record(from trip: Trip) -> TripRecordDTO.Trip {
        TripRecordDTO.Trip(
            id: trip.id.rawValue,
            brief: record(from: trip.brief),
            days: trip.days.map(record(from:)),
            revision: trip.revision,
            createdAt: trip.createdAt.timeIntervalSince1970
        )
    }

    private func record(from brief: TripBrief) -> TripRecordDTO.Brief {
        TripRecordDTO.Brief(
            destination: brief.destination,
            startDate: Self.day(from: brief.startDate, calendar: calendar),
            nights: brief.nights,
            travelStyle: brief.travelStyle.rawValue,
            pace: brief.pace.rawValue,
            budget: brief.budget.rawValue,
            diet: brief.diet.rawValue,
            party: TripRecordDTO.Party(
                adults: brief.party.adults,
                childAges: brief.party.childAges,
                // Sorted so a record is byte-stable across saves; a Set has no order
                // of its own and an unstable file makes every diff noise.
                accommodations: brief.party.accommodations.map(\.rawValue).sorted()
            ),
            sourceText: brief.sourceText
        )
    }

    private func record(from day: TripDay) -> TripRecordDTO.Day {
        TripRecordDTO.Day(
            id: day.id.rawValue,
            date: Self.day(from: day.date, calendar: calendar),
            city: day.city,
            blocks: day.blocks.map(record(from:)),
            arrivalTransfer: day.arrivalTransfer.map(record(from:))
        )
    }

    private func record(from block: DayBlock) -> TripRecordDTO.Block {
        TripRecordDTO.Block(id: block.id.rawValue,
                            slot: block.slot.rawValue,
                            items: block.items.map(record(from:)))
    }

    private func record(from item: ItineraryItem) -> TripRecordDTO.Item {
        TripRecordDTO.Item(
            id: item.id.rawValue,
            kind: item.kind.rawValue,
            startsAt: item.startsAt.map(Self.time(from:)),
            durationMinutes: item.durationMinutes,
            pinned: item.isPinned,
            travelFromPrevious: item.travelFromPrevious.map {
                TripRecordDTO.Travel(mode: $0.mode.rawValue, minutes: $0.minutes)
            },
            reason: item.reason,
            place: record(from: item.place)
        )
    }

    private func record(from place: Place) -> TripRecordDTO.Place {
        TripRecordDTO.Place(
            id: place.id.rawValue,
            providerPlaceId: place.providerPlaceID,
            name: place.name,
            address: place.address,
            lat: place.coordinate.latitude,
            lng: place.coordinate.longitude,
            opensAt: place.openingHours.map { Self.time(from: $0.opensAt) },
            closesAt: place.openingHours.map { Self.time(from: $0.closesAt) },
            requiresTicket: place.requiresTicket,
            diet: record(from: place.dietSignal),
            minimumAge: place.minimumAge,
            admissionPrice: place.admission?.adultPrice.amount,
            admissionCurrency: place.admission?.adultPrice.currency.rawValue,
            admissionFreeUnderAge: place.admission?.freeUnderAge,
            isStepFree: place.isStepFree,
            checkedAt: place.checkedAt?.timeIntervalSince1970
        )
    }

    private func record(from signal: DietSignal) -> TripRecordDTO.Diet? {
        switch signal {
        case let .confirmed(diet, source):
            TripRecordDTO.Diet(status: "confirmed", diet: diet.rawValue, source: source.rawValue)
        case let .likely(diet):
            TripRecordDTO.Diet(status: "likely", diet: diet.rawValue, source: nil)
        case .unknown:
            TripRecordDTO.Diet(status: "unknown", diet: nil, source: nil)
        case .notApplicable:
            nil
        }
    }

    private func record(from transfer: Transfer) -> TripRecordDTO.Transfer {
        TripRecordDTO.Transfer(
            origin: transfer.origin,
            destination: transfer.destination,
            options: transfer.options.map { option in
                TripRecordDTO.TransferOption(
                    id: option.id.rawValue,
                    mode: option.mode.rawValue,
                    minutes: option.minutes,
                    priceLow: option.priceBand.low.amount,
                    priceHigh: option.priceBand.high?.amount,
                    currency: option.priceBand.low.currency.rawValue,
                    note: option.note,
                    partner: option.partner?.rawValue
                )
            }
        )
    }

    // MARK: - Record → domain

    func trip(from dto: TripRecordDTO.Trip) throws -> Trip {
        guard dto.schemaVersion <= TripRecordDTO.currentSchemaVersion else {
            // A plan written by a newer build of the app. Refusing to open it is the
            // only safe answer: the alternative is silently dropping fields the
            // traveller can see are missing.
            throw DomainError.unexpectedResponse
        }
        return Trip(
            id: Identifier(dto.id),
            brief: try brief(from: dto.brief),
            days: try dto.days.map(day(from:)),
            revision: dto.revision,
            createdAt: Date(timeIntervalSince1970: dto.createdAt)
        )
    }

    private func brief(from dto: TripRecordDTO.Brief) throws -> TripBrief {
        guard let startDate = Self.date(from: dto.startDate, calendar: calendar),
              let travelStyle = TripBrief.TravelStyle(rawValue: dto.travelStyle),
              let pace = TripBrief.Pace(rawValue: dto.pace),
              let budget = TripBrief.BudgetBand(rawValue: dto.budget),
              let diet = TripBrief.DietRequirement(rawValue: dto.diet)
        else { throw DomainError.unexpectedResponse }

        // An accommodation we do not recognise is a contract break like any other
        // enum on the wire — it would silently drop a consideration the traveller
        // asked for, and a plan that quietly stops respecting a nap is worse than one
        // that refuses to open.
        var accommodations: Set<TravelParty.Accommodation> = []
        for raw in dto.party.accommodations {
            guard let mapped = TravelParty.Accommodation(rawValue: raw) else {
                throw DomainError.unexpectedResponse
            }
            accommodations.insert(mapped)
        }

        return TripBrief(destination: dto.destination,
                         startDate: startDate,
                         nights: dto.nights,
                         travelStyle: travelStyle,
                         pace: pace,
                         budget: budget,
                         diet: diet,
                         party: TravelParty(adults: dto.party.adults,
                                            childAges: dto.party.childAges,
                                            accommodations: accommodations),
                         sourceText: dto.sourceText)
    }

    private func day(from dto: TripRecordDTO.Day) throws -> TripDay {
        guard let date = Self.date(from: dto.date, calendar: calendar) else {
            throw DomainError.unexpectedResponse
        }
        // A day always has all three blocks, as everywhere else in the app.
        let mapped = try dto.blocks.map(block(from:))
        let blocks = DaySlot.allCases.map { slot in
            mapped.first { $0.slot == slot } ?? DayBlock(slot: slot)
        }
        return TripDay(id: Identifier(dto.id),
                       date: date,
                       city: dto.city,
                       blocks: blocks,
                       arrivalTransfer: try dto.arrivalTransfer.map(transfer(from:)))
    }

    private func block(from dto: TripRecordDTO.Block) throws -> DayBlock {
        guard let slot = DaySlot(rawValue: dto.slot) else { throw DomainError.unexpectedResponse }
        return DayBlock(id: Identifier(dto.id), slot: slot, items: try dto.items.map(item(from:)))
    }

    private func item(from dto: TripRecordDTO.Item) throws -> ItineraryItem {
        guard let kind = ItineraryItem.Kind(rawValue: dto.kind) else {
            throw DomainError.unexpectedResponse
        }
        var startsAt: MinuteOfDay?
        if let raw = dto.startsAt {
            guard let parsed = TripStreamMapper.minute(from: raw) else {
                throw DomainError.unexpectedResponse
            }
            startsAt = parsed
        }
        var travel: TravelLeg?
        if let leg = dto.travelFromPrevious {
            guard let mode = TravelLeg.Mode(rawValue: leg.mode) else {
                throw DomainError.unexpectedResponse
            }
            travel = TravelLeg(mode: mode, minutes: leg.minutes)
        }
        return ItineraryItem(id: Identifier(dto.id),
                             place: try place(from: dto.place),
                             kind: kind,
                             startsAt: startsAt,
                             durationMinutes: dto.durationMinutes,
                             isPinned: dto.pinned,
                             travelFromPrevious: travel,
                             reason: dto.reason)
    }

    private func place(from dto: TripRecordDTO.Place) throws -> Place {
        var hours: OpeningWindow?
        if let opens = dto.opensAt, let closes = dto.closesAt {
            guard let from = TripStreamMapper.minute(from: opens),
                  let to = TripStreamMapper.minute(from: closes)
            else { throw DomainError.unexpectedResponse }
            hours = OpeningWindow(opensAt: from, closesAt: to)
        }
        var admission: Admission?
        if let price = dto.admissionPrice {
            guard let currency = dto.admissionCurrency.flatMap(Money.Currency.init(rawValue:)) else {
                throw DomainError.unexpectedResponse
            }
            admission = Admission(adultPrice: Money(price, currency),
                                  freeUnderAge: dto.admissionFreeUnderAge)
        }

        return Place(id: Identifier(dto.id),
                     providerPlaceID: dto.providerPlaceId,
                     name: dto.name,
                     address: dto.address,
                     coordinate: Coordinate(latitude: dto.lat, longitude: dto.lng),
                     openingHours: hours,
                     dietSignal: dietSignal(from: dto.diet),
                     requiresTicket: dto.requiresTicket,
                     minimumAge: dto.minimumAge,
                     admission: admission,
                     isStepFree: dto.isStepFree,
                     checkedAt: dto.checkedAt.map(Date.init(timeIntervalSince1970:)))
    }

    /// Degrades toward less confidence, never more. Same rule as the wire mapper, and
    /// for the same reason.
    private func dietSignal(from dto: TripRecordDTO.Diet?) -> DietSignal {
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

    private func transfer(from dto: TripRecordDTO.Transfer) throws -> Transfer {
        Transfer(origin: dto.origin,
                 destination: dto.destination,
                 options: try dto.options.map { option in
                     guard let mode = Transfer.Mode(rawValue: option.mode),
                           let currency = Money.Currency(rawValue: option.currency)
                     else { throw DomainError.unexpectedResponse }
                     var partner: AffiliatePartner?
                     if let raw = option.partner {
                         guard let mapped = AffiliatePartner(rawValue: raw) else {
                             throw DomainError.unexpectedResponse
                         }
                         partner = mapped
                     }
                     return Transfer.Option(
                         id: Identifier(option.id),
                         mode: mode,
                         minutes: option.minutes,
                         priceBand: PriceBand(low: Money(option.priceLow, currency),
                                              high: option.priceHigh.map { Money($0, currency) }),
                         note: option.note,
                         partner: partner
                     )
                 })
    }

    // MARK: - Scalars

    /// Minutes since midnight → `HH:mm`, the inverse of ``TripStreamMapper/minute(from:)``.
    static func time(from minute: MinuteOfDay) -> String {
        String(format: "%02d:%02d", minute.hour, minute.minute)
    }

    /// A `Date` → `yyyy-MM-dd` in the given calendar, the inverse of
    /// ``TripStreamMapper/date(from:calendar:)``.
    static func day(from date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func date(from raw: String, calendar: Calendar) -> Date? {
        TripStreamMapper.date(from: raw, calendar: calendar)
    }
}
