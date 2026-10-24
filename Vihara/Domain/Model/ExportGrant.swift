import Foundation

/// Permission to produce a file, **as granted by the server**.
///
/// The client never decides this. ``Wallet/exportOutlook(for:)`` predicts it so the
/// right sheet opens without a flicker, but the prediction and the authority can
/// disagree — a credit spent on another device, a refund not yet propagated — and the
/// server wins. See [ADR-004](../../../docs/adr/004-server-authoritative-entitlements.md).
///
/// There is deliberately no `ExportGrant.full` the client can construct from a
/// `Wallet`: if that initialiser existed, a client bug or a changed clock could mint
/// one.
enum ExportGrant: Hashable, Sendable {
    /// The whole plan, no watermark. Something was consumed, or nothing needed to be.
    case full
    /// What a free account gets: watermarked, and truncated after `daysInFull`.
    ///
    /// **The truncation is a product decision, not a technical one**, and it answers
    /// open decision 3 in `docs/ROADMAP.md`. A watermarked *complete* plan is still a
    /// complete plan — a traveller reads it and never pays — so a watermark alone is
    /// a logo, not a paywall. One day in full is enough to judge the quality, which
    /// is what a preview is for. Confirm before launch; the server sets the number.
    case preview(daysInFull: Int)

    var isWatermarked: Bool {
        if case .preview = self { return true }
        return false
    }
}

/// Why an export could not be produced.
enum ExportFailure: Hashable, Sendable, Error {
    /// The server refused: nothing left to spend. Carries what to offer instead.
    case notEntitled(ExportOutlook)
    /// The plan has no days yet.
    case nothingToExport
    case connectionFailed
    case server(String)
}

/// What the store sells.
///
/// A closed set rather than raw product identifiers, so a screen cannot ask StoreKit
/// for a string nobody has configured. The identifiers themselves live in the data
/// layer, next to the StoreKit code that uses them.
enum PurchasableProduct: String, CaseIterable, Hashable, Sendable, Identifiable {
    /// This one plan, forever. Bound to the trip, not the device.
    case singleTripUnlock
    /// The subscription, which grants period credits on renewal.
    case subscription
    /// A top-up for a subscriber who has spent the period allowance.
    case creditBundle

    var id: String { rawValue }

    /// Which paywall variant offers this. Mirrors PRD 4.1's two sheets.
    func isOffered(for outlook: ExportOutlook) -> Bool {
        switch outlook {
        case .needsPurchase:
            // Variant A: no subscription. Offer the cheap way out and the good deal.
            self == .singleTripUnlock || self == .subscription
        case .needsTopUp:
            // Variant B: already paying. Selling them the subscription again would
            // be insulting; selling a single unlock undercuts the top-up.
            self == .creditBundle
        case .coveredByUnlock, .coveredByPeriodCredit, .coveredByPurchasedCredit:
            false
        }
    }
}

/// How a purchase ended.
enum PurchaseOutcome: Hashable, Sendable {
    /// Paid and verified by StoreKit. **Not** the same as entitled — the receipt
    /// still has to reach the server, which is what actually grants anything.
    case purchased
    case cancelled
    /// Ask-to-buy, or a payment held for review. Entitlement arrives later or not
    /// at all, so the UI must not promise a download.
    case pending
}
