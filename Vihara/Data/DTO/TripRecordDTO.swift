import Foundation

/// The on-disk shape of a saved plan.
///
/// A second DTO family alongside ``TripStreamDTO``, for the same reason ADR-003 gives
/// for the first: the domain is not `Codable`, so nothing the traveller has saved
/// welds ``Trip`` to a storage format. The wire shape and the storage shape are also
/// genuinely different problems — the wire carries one day at a time and no brief,
/// while a saved record has to round-trip a whole plan, including the brief it was
/// generated from and the revision exports are keyed on.
///
/// Both directions here, unlike the stream: this is the only DTO the app writes.
enum TripRecordDTO {

    /// Bumped when the shape changes incompatibly. ``TripRecordMapper`` refuses a
    /// version it does not know rather than guessing at a field's meaning — a saved
    /// plan misread is a traveller standing outside a restaurant that closed an hour
    /// ago.
    static let currentSchemaVersion = 1

    struct Trip: Codable {
        var schemaVersion: Int = TripRecordDTO.currentSchemaVersion
        let id: String
        let brief: Brief
        let days: [Day]
        let revision: Int
        /// Seconds since 1970. An instant, not a calendar date — unlike everything
        /// else here, this one really did happen at a moment in time.
        let createdAt: Double
    }

    struct Brief: Codable {
        let destination: String
        /// `yyyy-MM-dd`. A departure date has no time zone; see ``TripStreamDTO/Day``.
        let startDate: String
        let nights: Int
        let travelStyle: String
        let pace: String
        let budget: String
        let diet: String
        let party: Party
        let sourceText: String?
    }

    struct Party: Codable {
        let adults: Int
        let childAges: [Int]
        /// Raw values of ``TravelParty/Accommodation``. An array on disk because a
        /// JSON object has no set; order is not meaningful.
        let accommodations: [String]
    }

    struct Day: Codable {
        let id: String
        /// `yyyy-MM-dd`.
        let date: String
        let city: String
        let blocks: [Block]
        let arrivalTransfer: Transfer?
    }

    struct Block: Codable {
        let id: String
        let slot: String
        let items: [Item]
    }

    struct Item: Codable {
        let id: String
        let kind: String
        /// `HH:mm`.
        let startsAt: String?
        let durationMinutes: Int
        let pinned: Bool
        let travelFromPrevious: Travel?
        let reason: String?
        let place: Place
    }

    struct Travel: Codable {
        let mode: String
        let minutes: Int
    }

    struct Place: Codable {
        let id: String
        let providerPlaceId: String
        let name: String
        let address: String
        let lat: Double
        let lng: Double
        let opensAt: String?
        let closesAt: String?
        let requiresTicket: Bool
        let diet: Diet?
        let minimumAge: Int?
        let admissionPrice: Decimal?
        let admissionCurrency: String?
        let admissionFreeUnderAge: Int?
        let isStepFree: Bool?
        /// Seconds since 1970, or `nil` for never checked.
        let checkedAt: Double?
    }

    struct Diet: Codable {
        /// `confirmed` · `likely` · `unknown` · `notApplicable`
        let status: String
        let diet: String?
        /// `providerAttribute` · `venueMenu`
        let source: String?
    }

    struct Transfer: Codable {
        let origin: String
        let destination: String
        let options: [TransferOption]
    }

    struct TransferOption: Codable {
        let id: String
        let mode: String
        let minutes: Int
        let priceLow: Decimal
        let priceHigh: Decimal?
        let currency: String
        let note: String?
        let partner: String?
    }
}
