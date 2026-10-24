import Foundation

/// The file format of `Cities.json`, the mock search corpus.
///
/// A DTO rather than a `Codable` domain type, per
/// [ADR-003](../../../docs/adr/003-domain-purity.md): the file format stops here. If
/// the corpus later arrives from `GET /v1/cities` instead of the bundle, this type
/// changes and ``PlaceSuggestion`` does not.
struct CityCorpusDTO: Decodable, Sendable {
    let version: Int
    let cities: [CityDTO]
}

struct CityDTO: Decodable, Sendable {
    let id: String
    /// German, because the app is German-first. "Florenz", not "Firenze".
    let name: String
    /// The endonym. Shown nowhere yet; searchable always.
    let localName: String
    let country: String
    let countryCode: String
    /// "Toskana, Italien" — the line under the name, same shape as
    /// ``Destination/region``.
    let region: String
    let latitude: Double
    let longitude: Double
    let categories: [String]
    /// Every other spelling worth finding: the endonym, the English name, and
    /// historical names. "Bombay" finds Mumbai.
    let aliases: [String]
}

extension CityDTO {

    /// Maps to a suggestion that is **deliberately not plannable**.
    ///
    /// `destinationID` stays `nil` for every city in the corpus. That is the honest
    /// mapping and the product's central distinction: the corpus can *name* 285
    /// cities, and the app can plan three. A city that claimed to be plannable here
    /// would hand the traveller a generation that cannot succeed.
    var suggestion: PlaceSuggestion {
        PlaceSuggestion(id: "city:\(id)",
                        name: name,
                        region: region,
                        coordinate: Coordinate(latitude: latitude, longitude: longitude),
                        destinationID: nil)
    }
}
