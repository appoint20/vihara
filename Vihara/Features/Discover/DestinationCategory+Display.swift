import Foundation

extension DestinationCategory {
    /// The rail label. German only until phase 3 adds EN (PRD 9).
    var label: String {
        switch self {
        case .food:      "Kulinarik"
        case .coast:     "Küste"
        case .mountains: "Berge"
        case .cities:    "Städte"
        case .nature:    "Natur"
        }
    }
}

extension Destination {
    /// "4,8" — German decimal separator, which `Locale` handles for us.
    var formattedRating: String {
        rating.formatted(.number.precision(.fractionLength(1)))
    }

    /// "3 Nächte"
    var suggestedLengthLabel: String {
        suggestedNights == 1 ? "1 Nacht" : "\(suggestedNights) Nächte"
    }
}
