import Foundation

/// Place search against the Google Places API (New).
///
/// `POST https://places.googleapis.com/v1/places:autocomplete` — the current
/// endpoint; the older `maps/api/place/autocomplete/json` is on its way out and is
/// not worth building against now.
///
/// **Needs `GooglePlacesAPIKey` in `Vihara/Secrets.plist`.** Without one this type
/// is never constructed — ``AppDependencies`` falls back to the curated catalogue
/// instead, so the search field keeps working and simply finds less.
///
/// Restricted to cities and regions on purpose. Vihara plans days in a place; it does
/// not plan a trip to a specific restaurant, and offering one as a route stop would
/// promise something composition cannot deliver.
struct GooglePlacesSearch: PlaceSearching {
    private let apiKey: String
    private let session: URLSession
    private let languageCode: String

    init(apiKey: String, languageCode: String = "de", session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
        self.languageCode = languageCode
    }

    func suggestions(for query: String) async throws -> [PlaceSuggestion] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        // Two characters is the shortest query worth paying for; Places bills per
        // request and a one-letter search returns noise anyway.
        guard trimmed.count >= 2 else { return [] }

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
        // Required, and easy to miss: a key restricted to iOS apps is checked against
        // this header, not against anything URLSession sends on its own. Without it
        // every request comes back 403 API_KEY_IOS_APP_BLOCKED with an empty bundle
        // id — the restriction working exactly as configured, against us.
        //
        // Google's Maps SDK adds this; a plain REST call does not.
        request.setValue(Self.bundleIdentifier, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        // Ask for only the fields we render. Places bills by field mask, so a lazy
        // `*` here is money spent on data that never reaches the screen.
        request.setValue("suggestions.placePrediction.placeId,suggestions.placePrediction.text,suggestions.placePrediction.structuredFormat",
                         forHTTPHeaderField: "X-Goog-FieldMask")
        request.httpBody = try JSONEncoder().encode(
            Request(input: trimmed,
                    languageCode: languageCode,
                    includedPrimaryTypes: Self.regionTypes)
        )

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw DomainError.unexpectedResponse }
        guard (200..<300).contains(http.statusCode) else {
            // A 403 here is almost always the key: not enabled, not restricted to
            // this bundle id, or billing off. Say so rather than "network error".
            throw http.statusCode == 403 || http.statusCode == 401
                ? DomainError.server(message: "Places rejected the key (HTTP \(http.statusCode)) — check the iOS app restriction lists \(Self.bundleIdentifier).")
                : DomainError.connectionFailed
        }

        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return decoded.suggestions?.compactMap(\.placePrediction).map { prediction in
            // Prefer the structured split ("Bologna" / "Italien") over the joined
            // string, because the two halves are drawn differently.
            PlaceSuggestion(
                id: prediction.placeId,
                name: prediction.structuredFormat?.mainText?.text
                    ?? prediction.text?.text
                    ?? prediction.placeId,
                region: prediction.structuredFormat?.secondaryText?.text ?? ""
            )
        } ?? []
    }

    private static let endpoint = URL(string: "https://places.googleapis.com/v1/places:autocomplete")!

    /// Read from the bundle rather than hard-coded, so a build with a different
    /// identifier reports its own — otherwise this would silently lie to Google.
    private static let bundleIdentifier = Bundle.main.bundleIdentifier ?? ""

    /// Cities, towns and administrative regions. Not restaurants, not museums — a
    /// route stop is somewhere you sleep, not somewhere you eat.
    private static let regionTypes = ["locality", "administrative_area_level_1", "administrative_area_level_2"]

    // MARK: - Wire shape

    private struct Request: Encodable {
        let input: String
        let languageCode: String
        let includedPrimaryTypes: [String]
    }

    private struct Response: Decodable {
        let suggestions: [Suggestion]?

        struct Suggestion: Decodable {
            let placePrediction: Prediction?
        }

        struct Prediction: Decodable {
            let placeId: String
            let text: TextValue?
            let structuredFormat: StructuredFormat?
        }

        struct TextValue: Decodable {
            let text: String?
        }

        struct StructuredFormat: Decodable {
            let mainText: TextValue?
            let secondaryText: TextValue?
        }
    }
}
