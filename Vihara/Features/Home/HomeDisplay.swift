import Foundation

/// Wording for the home surface.
///
/// Kept out of the view because most of it is arithmetic wearing a sentence: which
/// greeting the hour calls for, which season a date falls in, how a slot's value
/// reads once it has been parsed. A view should place these, not compute them.
enum HomeDisplay {

    // MARK: - Greeting

    /// Morning, afternoon, evening — and one for the small hours, because somebody
    /// planning a trip at 2 a.m. deserves to be noticed rather than told "good
    /// evening".
    static func greetingKey(hour: Int, hasName: Bool) -> String {
        let base = switch hour {
        case 5..<12:  "home.greeting.morning"
        case 12..<18: "home.greeting.afternoon"
        case 18..<23: "home.greeting.evening"
        default:      "home.greeting.night"
        }
        return hasName ? base : base + ".anon"
    }

    static func greeting(name: String, at date: Date, calendar: Calendar, locale: Locale) -> String {
        let hour = calendar.component(.hour, from: date)
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = greetingKey(hour: hour, hasName: !trimmed.isEmpty)
        return trimmed.isEmpty
            ? localized(key, locale: locale)
            : localized(key, trimmed, locale: locale)
    }

    /// The paragraph under the greeting: names where they are going and when.
    static func greetingBody(destination: String?,
                             at date: Date,
                             calendar: Calendar,
                             locale: Locale) -> String {
        let season = localized(seasonKey(for: date, calendar: calendar), locale: locale)
        guard let destination, !destination.isEmpty else {
            return localized("home.greeting.body.nowhere", season, locale: locale)
        }
        return localized("home.greeting.body", destination, season, locale: locale)
    }

    static func seasonKey(for date: Date, calendar: Calendar) -> String {
        // Meteorological seasons, northern hemisphere — the pilot region is Italy and
        // an astronomical boundary would move the word by three weeks for no reader's
        // benefit.
        switch calendar.component(.month, from: date) {
        case 3...5:   "season.spring"
        case 6...8:   "season.summer"
        case 9...11:  "season.autumn"
        default:      "season.winter"
        }
    }

    // MARK: - Counts

    static func nights(_ count: Int, locale: Locale) -> String {
        count == 1 ? localized("nights.one", locale: locale)
                   : localized("nights.count", count, locale: locale)
    }

    static func stopNights(_ count: Int, locale: Locale) -> String {
        count == 1 ? localized("home.stops.nights.one", locale: locale)
                   : localized("home.stops.nights", count, locale: locale)
    }

    // MARK: - Dates

    /// "14.–17. April" — one month named once, which is how a range is said aloud.
    static func range(_ selection: DateRangeSelection, locale: Locale, calendar: Calendar) -> String? {
        guard let start = selection.start else { return nil }
        guard let end = selection.end else {
            return start.formatted(.dateTime.day().month(.wide).locale(locale))
        }
        let sameMonth = calendar.isDate(start, equalTo: end, toGranularity: .month)
        let from = sameMonth
            ? start.formatted(.dateTime.day().locale(locale))
            : start.formatted(.dateTime.day().month(.abbreviated).locale(locale))
        let to = end.formatted(.dateTime.day().month(.wide).locale(locale))
        return "\(from) – \(to)"
    }

    /// Whether the range covers a Monday, when most Italian museums are shut.
    ///
    /// A real composition risk in the pilot region rather than a generic caution, so
    /// the note names the day instead of warning in the abstract.
    static func mondayInRange(_ selection: DateRangeSelection, calendar: Calendar) -> Date? {
        selection.days(in: calendar).first { calendar.component(.weekday, from: $0) == 2 }
    }

    // MARK: - Recognised slots

    static func slotCaption(_ slot: BriefSlot) -> String {
        "slot.\(slot.rawValue)"
    }

    /// What a filled chip shows beside its caption.
    static func slotValue(_ slot: BriefSlot,
                          in brief: TripBrief,
                          locale: Locale,
                          calendar: Calendar) -> String {
        switch slot {
        case .destination:
            brief.destination
        case .dates:
            brief.startDate.formatted(.dateTime.day().month(.abbreviated).locale(locale))
        case .nights:
            nights(brief.nights, locale: locale)
        case .pace:
            localized("pace.\(brief.pace.rawValue)", locale: locale)
        case .diet:
            localized("diet.\(brief.diet.rawValue)", locale: locale)
        case .party:
            partyLabel(brief.party, locale: locale)
        }
    }

    /// "2 Erwachsene · 1 Kind" — the shape of the party rather than a headcount,
    /// because the children are what changes the plan.
    static func partyLabel(_ party: TravelParty, locale: Locale) -> String {
        var parts = [localized("party.adults", locale: locale) + " \(party.adults)"]
        if party.hasChildren {
            parts.append(localized("party.children", locale: locale) + " \(party.childCount)")
        }
        return parts.joined(separator: " · ")
    }
}

extension TravelParty.Accommodation {
    var localizationKey: String { "accommodation.\(rawValue)" }

    var symbol: String {
        switch self {
        case .middaySleep:    "moon.zzz"
        case .pushchair:      "stroller"
        case .stepFree:       "figure.roll"
        case .noLongStanding: "chair"
        }
    }
}

