import Foundation

/// The wire shape of `GET /v1/trips/:id/stream`.
///
/// These types exist so the domain does not have to be `Codable`. A rename on the
/// backend changes a mapper, not ``Trip`` — and the plan model stays free of
/// coding keys, optionals-for-the-wire's-sake and snake case.
///
/// The schema is the client's proposal; it is fixed jointly with the backend in
/// phase 1 and versioned from then on.
enum TripStreamDTO {

    struct Accepted: Decodable {
        let tripId: String
        let expectedDays: Int
    }

    struct Day: Decodable {
        let id: String
        /// `yyyy-MM-dd`, the traveller's local day. Not an instant — a plan is
        /// anchored to a calendar date, and a timestamp would drag time zones into
        /// something that has none.
        let date: String
        let city: String
        let blocks: [Block]
    }

    struct Block: Decodable {
        let id: String
        let slot: String
        let items: [Item]
    }

    struct Item: Decodable {
        let id: String
        let kind: String
        /// `HH:mm`.
        let startsAt: String?
        let durationMinutes: Int
        let pinned: Bool
        let travelFromPrevious: Travel?
        let place: Place
    }

    struct Travel: Decodable {
        let mode: String
        let minutes: Int
    }

    struct Place: Decodable {
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
    }

    struct Diet: Decodable {
        /// `confirmed` · `likely` · `unknown` · `notApplicable`
        let status: String
        let diet: String?
        /// `providerAttribute` · `venueMenu`
        let source: String?
    }
}
