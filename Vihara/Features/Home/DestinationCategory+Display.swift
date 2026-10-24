import Foundation

extension DestinationCategory {
    /// The rail label, as a key rather than a literal — the app reads in two
    /// languages now.
    var localizationKey: String { "category.\(rawValue)" }
}

extension Destination {
    /// "4,8" — German decimal separator, which `Locale` handles for us.
    var formattedRating: String {
        rating.formatted(.number.precision(.fractionLength(1)))
    }

    /// "3 Nächte" · "3 nights"
    func suggestedLengthLabel(locale: Locale) -> String {
        HomeDisplay.nights(suggestedNights, locale: locale)
    }
}
