import Foundation

extension MinuteOfDay {
    /// "8:30"
    var label: String {
        String(format: "%d:%02d", hour, minute)
    }
}

extension OpeningWindow {
    /// "8:30–13:00"
    var label: String {
        "\(opensAt.label)–\(closesAt.label)"
    }
}

extension DaySlot {
    var label: String {
        switch self {
        case .morning:   "Vormittag"
        case .afternoon: "Nachmittag"
        case .evening:   "Abend"
        }
    }
}

extension TripDay {
    /// "Dienstag · 14. April · Bologna"
    var title: String {
        let weekday = date.formatted(.dateTime.weekday(.wide))
        let day = date.formatted(.dateTime.day().month(.wide))
        return "\(weekday) · \(day) · \(city)"
    }
}

extension TravelLeg {
    /// "7 Min. zu Fuß"
    var label: String {
        switch mode {
        case .walk:    "\(minutes) Min. zu Fuß"
        case .transit: "\(minutes) Min. mit Bus/Bahn"
        case .taxi:    "\(minutes) Min. mit dem Taxi"
        }
    }
}

extension DietSignal {
    /// The wording carries the evidence level. "bestätigt" is only ever printed for
    /// stage 1 and 2 evidence; anything weaker says "wahrscheinlich" and is drawn
    /// differently (PRD 6.5).
    var badge: (text: String, isConfirmed: Bool)? {
        switch self {
        case let .confirmed(diet, _):
            (diet == .vegan ? "vegan bestätigt" : "vegetarisch bestätigt", true)
        case let .likely(diet):
            (diet == .vegan ? "vegan wahrscheinlich" : "vegetarisch wahrscheinlich", false)
        case .unknown, .notApplicable:
            nil
        }
    }
}

extension Transfer.Mode {
    var label: String {
        switch self {
        case .highSpeedTrain: "Schnellzug"
        case .regionalTrain:  "Regionalzug"
        case .rentalCar:      "Mietwagen"
        case .coach:          "Fernbus"
        case .ferry:          "Fähre"
        }
    }
}

extension Transfer.Option {
    /// "37 Min."
    var durationLabel: String {
        minutes < 60
            ? "\(minutes) Min."
            : "\(minutes / 60) Std. \(String(format: "%02d", minutes % 60))"
    }
}

extension PriceBand {
    /// "15–29 €" or "ab 9 €"
    var label: String {
        let format = FloatingPointFormatStyle<Double>.Currency(code: "EUR")
            .precision(.fractionLength(0))
        let lower = Double(truncating: low.amount as NSDecimalNumber).formatted(format)
        guard let high else { return "ab \(lower)" }
        let upper = Double(truncating: high.amount as NSDecimalNumber).formatted(format)
        return "\(lower)–\(upper)"
    }
}

extension PlanWarning {
    /// Warnings state a fact. They never scold, and they never imply the traveller
    /// broke something — an edit that creates a conflict is a normal thing to do.
    var message: String {
        switch kind {
        case let .closedAtPlannedTime(place):
            "\(place) hat zur geplanten Zeit geschlossen."
        case let .blockOverfull(limit):
            limit == 1
                ? "Mehr als ein Baustein für dieses Tempo."
                : "Mehr als \(limit) Bausteine für dieses Tempo."
        case .competingHeadlines:
            "Zwei große Sehenswürdigkeiten in einem Halbtag."
        case let .mealNotVerifiedForDiet(place, diet):
            "\(place): \(diet.label(locale: .current).lowercased()) nicht belegt."
        case .missingMeal:
            "Noch kein Essen eingeplant."
        case let .excessiveWalking(minutes, limit):
            "\(minutes) Min. zu Fuß, mehr als die \(limit) Min. für dieses Tempo."
        }
    }
}

extension DomainError {
    var message: String {
        switch self {
        case .incompleteBrief:
            "Uns fehlt noch das Ziel oder die Dauer."
        case let .generationLimitReached(resetsOn):
            resetsOn.map {
                "Deine freien Pläne für dieses Jahr sind aufgebraucht. Neu ab \($0.formatted(.dateTime.day().month(.wide)))."
            } ?? "Deine freien Pläne für dieses Jahr sind aufgebraucht."
        case let .noValidatedCandidates(destination):
            "Für \(destination) haben wir noch keine geprüften Orte."
        case .planningUnavailable:
            "Die Planung ist gerade nicht erreichbar. Dein Plan bleibt lesbar."
        case .connectionFailed:
            "Keine Verbindung. Wir versuchen es gleich noch einmal."
        case let .server(message):
            message
        case .unexpectedResponse:
            "Da ist uns etwas dazwischengekommen."
        }
    }
}
