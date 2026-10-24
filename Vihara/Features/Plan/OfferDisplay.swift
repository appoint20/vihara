import Foundation

extension BookableOffer.Kind {
    /// The localization key for what is being sold. "Ticket", "Zug", "eSIM".
    var labelKey: String { "offer.kind.\(rawValue)" }
}

extension BookableOffer {
    /// "18–32 €", or nil where the partner quotes no band.
    ///
    /// A band and never an exact figure: a cached fare that has drifted is a
    /// Preisangabenverordnung problem as much as a conversion one.
    var priceLabel: String? { priceBand?.label }
}

/// The paid-placement marker.
///
/// One key, one word, used by every offer. German advertising practice (§5a UWG) and
/// every affiliate contract require the marking; keeping it in one place is what
/// stops a second booking surface from inventing a softer word for it.
enum AffiliateDisclosure {
    static let labelKey = "offer.disclosure"
}

extension PlanEditRefusal {
    /// A refusal states the fact and nothing else. The traveller did not do anything
    /// wrong by trying.
    var message: String {
        switch self {
        case .blockWouldNotAccept:
            localized("plan.edit.refused", locale: .current)
        case .itemNotFound, .dayNotFound:
            // Neither is reachable from the UI — both mean the plan changed under an
            // edit in flight. Named rather than silently swallowed.
            localized("plan.edit.refused", locale: .current)
        }
    }
}

extension ExportFailure {
    func message(locale: Locale) -> String {
        switch self {
        case .notEntitled:      localized("export.failed.notEntitled", locale: locale)
        case .nothingToExport:  localized("export.failed.empty", locale: locale)
        case .connectionFailed: localized("export.failed.offline", locale: locale)
        case let .server(text): text
        }
    }
}
