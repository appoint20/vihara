import Foundation

/// Wording for a brief's enum values.
///
/// Keys rather than literals, and functions rather than properties, because the
/// reader's language is in the environment and a property cannot see it. Every one of
/// these has both a German and an English string behind it — see the two
/// `Localizable.strings` files, kept in step by `Scripts/check-localization.sh`.

extension TripBrief.Pace {
    var localizationKey: String { "pace.\(rawValue)" }
    func label(locale: Locale) -> String { localized(localizationKey, locale: locale) }
}

extension TripBrief.BudgetBand {
    var localizationKey: String { "budget.\(rawValue)" }
    func label(locale: Locale) -> String { localized(localizationKey, locale: locale) }
}

extension TripBrief.DietRequirement {
    var localizationKey: String { "diet.\(rawValue)" }
    func label(locale: Locale) -> String { localized(localizationKey, locale: locale) }
}

extension TripBrief.TravelStyle {
    var localizationKey: String { "style.\(rawValue)" }
    func label(locale: Locale) -> String { localized(localizationKey, locale: locale) }
}

extension TripBrief {
    func nightsLabel(locale: Locale) -> String {
        HomeDisplay.nights(nights, locale: locale)
    }

    /// "Sa, 12. Sep." — short enough for a chip, unambiguous enough to trust.
    func startDateLabel(locale: Locale) -> String {
        startDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(locale))
    }
}
