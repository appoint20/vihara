import Foundation

/// Reads a German sentence into a ``TripBrief`` on the device.
///
/// A stand-in for the intake model behind `POST /v1/trips` (PRD 6.2, "Haiku-Klasse"),
/// good enough to build and test the whole intake flow before a backend exists.
/// Everything it cannot infer falls back to a stated default rather than an empty
/// field, because the traveller corrects chips — they should never face a blank form.
///
/// The destination is resolved through the catalogue rather than guessed from the
/// text, which is the product rule, not a shortcut: we only plan regions we have
/// curated (PRD 10.2).
struct HeuristicTripBriefParser: TripBriefParsing {
    private let catalogue: any DestinationCatalogue
    private let calendar: Calendar
    /// How far out a trip lands when the traveller names no date.
    private let defaultLeadDays: Int

    init(catalogue: any DestinationCatalogue,
         calendar: Calendar = .current,
         defaultLeadDays: Int = 21) {
        self.catalogue = catalogue
        self.calendar = calendar
        self.defaultLeadDays = defaultLeadDays
    }

    func parse(_ sentence: String, relativeTo today: Date) async throws -> TripBrief {
        let tokens = Self.tokenise(sentence)
        let destination = try await catalogue.destination(matching: sentence)

        return TripBrief(
            destination: destination?.name ?? "",
            startDate: Self.startDate(tokens: tokens,
                                      today: today,
                                      calendar: calendar,
                                      fallbackLeadDays: defaultLeadDays),
            nights: Self.nights(tokens: tokens) ?? destination?.suggestedNights ?? 3,
            travelStyle: tokens.contains("rundreise") ? .roundTrip : .cityBreak,
            pace: Self.pace(tokens: tokens),
            budget: Self.budget(tokens: tokens),
            diet: Self.diet(tokens: tokens),
            sourceText: sentence
        )
    }

    // MARK: - Scanning
    //
    // Token matching rather than regular expressions: the rules are readable, each
    // one is independently testable, and a sentence that matches nothing degrades to
    // defaults instead of throwing.

    static func tokenise(_ sentence: String) -> [String] {
        PilotDestinationCatalogue.fold(sentence)
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
    }

    static func nights(tokens: [String]) -> Int? {
        if tokens.contains("wochenende") { return 2 }

        for (index, token) in tokens.enumerated() {
            guard let count = Int(token), count > 0, count < 60 else { continue }
            guard let unit = tokens[safe: index + 1] else { continue }
            // Folding strips the umlaut, so "nachte" covers "Nächte" too.
            if unit.hasPrefix("tag")   { return max(1, count - 1) }   // 5 Tage → 4 Nächte
            if unit.hasPrefix("nacht") { return count }
            if unit.hasPrefix("woche") { return count * 7 - 1 }
        }
        if tokens.contains("woche") { return 6 }
        return nil
    }

    static func pace(tokens: [String]) -> TripBrief.Pace {
        let relaxed = ["entspannt", "entspanntes", "gemutlich", "gemutliches", "ruhig", "langsam"]
        let packed  = ["intensiv", "kompakt", "straff", "vollgepackt", "viel"]
        if tokens.contains(where: relaxed.contains) { return .relaxed }
        if tokens.contains(where: packed.contains)  { return .packed }
        return .balanced
    }

    static func budget(tokens: [String]) -> TripBrief.BudgetBand {
        let thrifty = ["gunstig", "billig", "budget", "sparsam", "preiswert"]
        let premium = ["luxus", "luxurios", "gehoben", "hochwertig", "premium"]
        if tokens.contains(where: thrifty.contains) { return .thrifty }
        if tokens.contains(where: premium.contains) { return .premium }
        return .middle
    }

    static func diet(tokens: [String]) -> TripBrief.DietRequirement {
        if tokens.contains(where: { $0.hasPrefix("vegan") })      { return .vegan }
        if tokens.contains(where: { $0.hasPrefix("vegetarisch") }) { return .vegetarian }
        return .none
    }

    static func startDate(tokens: [String],
                          today: Date,
                          calendar: Calendar,
                          fallbackLeadDays: Int) -> Date {
        let base = calendar.startOfDay(for: today)

        if tokens.contains("ubermorgen") {
            return calendar.date(byAdding: .day, value: 2, to: base) ?? base
        }
        if tokens.contains("morgen") {
            return calendar.date(byAdding: .day, value: 1, to: base) ?? base
        }
        if tokens.contains("nachste"), tokens.contains("woche") {
            return calendar.date(byAdding: .day, value: 7, to: base) ?? base
        }
        if let explicit = explicitDate(tokens: tokens, today: base, calendar: calendar) {
            return explicit
        }
        return calendar.date(byAdding: .day, value: fallbackLeadDays, to: base) ?? base
    }

    /// "ab 14. April" — a day number followed by a month name. A month on its own
    /// ("im Mai") means the first of that month.
    private static func explicitDate(tokens: [String], today: Date, calendar: Calendar) -> Date? {
        for (index, token) in tokens.enumerated() {
            guard let month = months[token] else { continue }
            let day = tokens[safe: index - 1].flatMap(Int.init).flatMap { (1...31).contains($0) ? $0 : nil } ?? 1
            let year = calendar.component(.year, from: today)
            let candidate = calendar.date(from: DateComponents(year: year, month: month, day: day))
            guard let candidate else { return nil }
            // A month already past means the traveller means next year.
            return candidate < today
                ? calendar.date(from: DateComponents(year: year + 1, month: month, day: day))
                : candidate
        }
        return nil
    }

    private static let months: [String: Int] = [
        "januar": 1, "februar": 2, "marz": 3, "april": 4, "mai": 5, "juni": 6,
        "juli": 7, "august": 8, "september": 9, "oktober": 10, "november": 11, "dezember": 12,
    ]
}

private extension Array {
    /// Bounds-checked lookup, so look-ahead and look-behind read as one expression.
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
