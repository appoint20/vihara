import Foundation

/// The account's entitlement state, **as last reported by the server**.
///
/// This type deliberately has no mutating members and no `spend` anything. Credits
/// are a server-side ledger (PRD 7.3); the client holds a read copy to render the
/// right paywall and the right number in the profile, and nothing else. Every grant
/// decision is made by `POST /v1/trips/:id/export` and confirmed on delivery.
///
/// If you find yourself wanting to decrement a counter here, the change belongs in
/// the backend.
struct Wallet: Hashable, Sendable {
    /// Free generations used this calendar year. Resets on 1 January, server-side.
    let freeTripsUsedThisYear: Int
    /// Remote-configurable so the conversion effect stays measurable (PRD 10.3).
    let freeTripsAllowance: Int
    let subscription: SubscriptionState
    /// Granted per billing period by the renewal webhook.
    let periodCreditsGranted: Int
    let periodCreditsUsed: Int
    /// Bought outright. Never expire, never roll over into the period counter.
    let purchasedCredits: Int
    /// Trips bought individually. Permanent, and bound to the trip, not the device.
    let unlockedTripIDs: Set<Identifier<Trip>>
    /// When the period allowance refills — the date shown in paywall variant B.
    let periodRenewsOn: Date?

    static let empty = Wallet(
        freeTripsUsedThisYear: 0,
        freeTripsAllowance: 2,
        subscription: .none,
        periodCreditsGranted: 0,
        periodCreditsUsed: 0,
        purchasedCredits: 0,
        unlockedTripIDs: [],
        periodRenewsOn: nil
    )

    var periodCreditsRemaining: Int {
        max(0, periodCreditsGranted - periodCreditsUsed)
    }

    var freeGenerationsRemaining: Int {
        max(0, freeTripsAllowance - freeTripsUsedThisYear)
    }

    /// Whether a *new* plan may be generated at all (F-01 gate for free accounts).
    var canGenerateAnotherTrip: Bool {
        subscription.isEntitled || freeGenerationsRemaining > 0
    }

    enum SubscriptionState: String, Hashable, Sendable {
        case none
        case active
        case grace
        case billingRetry
        case expired

        /// Grace counts as paying: a failed card is not a reason to take the product
        /// away mid-trip.
        var isEntitled: Bool { self == .active || self == .grace }
    }
}

/// What the client *expects* the server to say about keeping or exporting a trip.
///
/// Presentational only — it decides which sheet to raise, never whether the file is
/// produced. The server may disagree (a credit spent on another device, a refund
/// that has not reached us yet) and the server wins.
enum ExportOutlook: Hashable, Sendable {
    /// The trip is already unlocked outright. Nothing is consumed.
    case coveredByUnlock
    /// A period credit is available.
    case coveredByPeriodCredit(remaining: Int)
    /// The period is spent but a purchased credit covers it.
    case coveredByPurchasedCredit(remaining: Int)
    /// Subscriber, nothing left — offer top-ups (paywall variant B).
    case needsTopUp(refillsOn: Date?)
    /// No subscription — offer the single unlock or the subscription (variant A).
    case needsPurchase

    var isCovered: Bool {
        switch self {
        case .coveredByUnlock, .coveredByPeriodCredit, .coveredByPurchasedCredit: true
        case .needsTopUp, .needsPurchase: false
        }
    }
}

extension Wallet {

    /// Mirrors the server's decision order from PRD 4.1 so the traveller is shown the
    /// sheet they are about to get, with no flicker between tap and answer.
    ///
    /// Order matters and is not arbitrary: period credits are consumed *before*
    /// purchased ones, so a purchased credit is never quietly wiped by a period
    /// reset.
    func exportOutlook(for tripID: Identifier<Trip>) -> ExportOutlook {
        if unlockedTripIDs.contains(tripID) {
            return .coveredByUnlock
        }
        if subscription.isEntitled, periodCreditsRemaining > 0 {
            return .coveredByPeriodCredit(remaining: periodCreditsRemaining)
        }
        // Faithful to PRD 4.1, which gates purchased credits on `active` rather than
        // on `isEntitled`. Flagged as an open question: purchased credits are sold as
        // never-expiring, so spending them during grace — or with no subscription at
        // all — is arguably what the traveller was promised.
        if subscription == .active, purchasedCredits > 0 {
            return .coveredByPurchasedCredit(remaining: purchasedCredits)
        }
        if subscription.isEntitled {
            return .needsTopUp(refillsOn: periodRenewsOn)
        }
        return .needsPurchase
    }
}
