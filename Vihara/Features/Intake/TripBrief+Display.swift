import Foundation

extension TripBrief.Pace {
    var label: String {
        switch self {
        case .relaxed:  "Entspannt"
        case .balanced: "Ausgewogen"
        case .packed:   "Viel sehen"
        }
    }
}

extension TripBrief.BudgetBand {
    var label: String {
        switch self {
        case .thrifty: "Günstig"
        case .middle:  "Mittelklasse"
        case .premium: "Gehoben"
        }
    }
}

extension TripBrief.DietRequirement {
    var label: String {
        switch self {
        case .none:       "Alles"
        case .vegetarian: "Vegetarisch"
        case .vegan:      "Vegan"
        }
    }
}

extension TripBrief.TravelStyle {
    var label: String {
        switch self {
        case .cityBreak: "Städtereise"
        case .roundTrip: "Rundreise"
        }
    }
}

extension TripBrief {
    var nightsLabel: String {
        nights == 1 ? "1 Nacht" : "\(nights) Nächte"
    }

    /// "Sa, 12. Sep." — short enough for a chip, unambiguous enough to trust.
    var startDateLabel: String {
        startDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }
}
