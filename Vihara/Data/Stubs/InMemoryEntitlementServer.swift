import Foundation

/// The entitlement backend, faked in process.
///
/// **This type stands in for the server, not for a client capability.** That
/// distinction is the whole of [ADR-004](../../../docs/adr/004-server-authoritative-entitlements.md):
/// the client may not spend, so the spending lives here, behind the same
/// ``WalletRepository`` and ``PlanExporting`` protocols the real endpoints will
/// implement. When `POST /v1/trips/:id/export` exists, this type is deleted and the
/// screens do not change.
///
/// It is an `actor` because it holds a ledger, and a ledger read and written from
/// several tasks is a data race — which in this particular case spends somebody's
/// money twice.
///
/// Nothing here is a security boundary. A real ledger lives behind authentication
/// and signs what it hands back; this one believes whatever it is told, in the same
/// way ``StubAuthenticationService`` authenticates for real and verifies nothing.
actor InMemoryEntitlementServer: WalletRepository, PlanExporting {

    /// What a subscription period grants, and what a top-up bundle contains.
    /// Server-configured in production (PRD 10.3 wants the allowance tunable so the
    /// conversion effect stays measurable).
    static let creditsPerPeriod = 5
    static let creditsPerBundle = 5
    /// What a free account's preview contains. One day is enough to judge the
    /// quality — see ``ExportGrant/preview(daysInFull:)``.
    static let previewDaysInFull = 1

    private var wallet: Wallet
    /// Grants already issued, keyed by `(trip, revision)`.
    ///
    /// This is the idempotency the roadmap calls for: a traveller who taps
    /// *Exportieren* twice because the first tap seemed slow gets the same grant back
    /// and is charged once. Keyed on the revision as well as the trip, so an *edited*
    /// plan is a new export and genuinely does cost again.
    private var issued: [GrantKey: ExportGrant] = [:]

    private struct GrantKey: Hashable {
        let tripID: Identifier<Trip>
        let revision: Int
    }

    init(wallet: Wallet = .empty) {
        self.wallet = wallet
    }

    func currentWallet() async throws -> Wallet { wallet }

    // MARK: - Export (F-08)

    /// The server's decision order, which ``Wallet/exportOutlook(for:)`` mirrors.
    ///
    /// A free account is **not** refused — it is granted a watermarked preview, which
    /// is what PRD 4 promises. The paywall is raised alongside the preview by the
    /// screen, not instead of it.
    func requestGrant(tripID: Identifier<Trip>, revision: Int) async throws -> ExportGrant {
        let key = GrantKey(tripID: tripID, revision: revision)
        if let already = issued[key] { return already }

        let grant: ExportGrant
        switch wallet.exportOutlook(for: tripID) {
        case .coveredByUnlock:
            grant = .full
        case .coveredByPeriodCredit:
            wallet = wallet.consumingPeriodCredit()
            grant = .full
        case .coveredByPurchasedCredit:
            wallet = wallet.consumingPurchasedCredit()
            grant = .full
        case .needsTopUp, .needsPurchase:
            grant = .preview(daysInFull: Self.previewDaysInFull)
        }

        // Only a *spending* grant is remembered. Idempotency exists to stop a
        // double tap being billed twice; a preview consumed nothing, so caching it
        // would do nothing but trap the traveller on a watermarked file after they
        // had just paid to remove the watermark.
        if case .full = grant { issued[key] = grant }
        return grant
    }

    // MARK: - Purchases (F-09)

    /// Applies a verified purchase to the ledger.
    ///
    /// **In production nothing calls this from the client.** The receipt goes to the
    /// server, the server verifies it with Apple and moves the ledger, and the client
    /// learns about it by re-reading the wallet. The composition root wires StoreKit
    /// to this method only because there is no server to send the receipt to — the
    /// same shape of pretence as ``StubAuthenticationService``.
    func apply(_ product: PurchasableProduct, tripID: Identifier<Trip>?) {
        switch product {
        case .singleTripUnlock:
            guard let tripID else { return }
            wallet = wallet.unlocking(tripID)
        case .subscription:
            wallet = wallet.subscribing(credits: Self.creditsPerPeriod)
        case .creditBundle:
            wallet = wallet.addingPurchasedCredits(Self.creditsPerBundle)
        }
    }
}

/// Ledger moves, as pure transformations.
///
/// Deliberately `fileprivate`-adjacent in spirit: they live here, in the data layer,
/// beside the only type allowed to call them. Putting them on ``Wallet`` in the
/// domain would hand every screen a way to grant itself a download, which is exactly
/// what ADR-004 exists to prevent — `Wallet` has no mutating members and must keep
/// none.
private extension Wallet {

    func copy(subscription: SubscriptionState? = nil,
              periodCreditsGranted: Int? = nil,
              periodCreditsUsed: Int? = nil,
              purchasedCredits: Int? = nil,
              unlockedTripIDs: Set<Identifier<Trip>>? = nil,
              periodRenewsOn: Date?? = nil) -> Wallet {
        Wallet(freeTripsUsedThisYear: freeTripsUsedThisYear,
               freeTripsAllowance: freeTripsAllowance,
               subscription: subscription ?? self.subscription,
               periodCreditsGranted: periodCreditsGranted ?? self.periodCreditsGranted,
               periodCreditsUsed: periodCreditsUsed ?? self.periodCreditsUsed,
               purchasedCredits: purchasedCredits ?? self.purchasedCredits,
               unlockedTripIDs: unlockedTripIDs ?? self.unlockedTripIDs,
               periodRenewsOn: periodRenewsOn ?? self.periodRenewsOn)
    }

    func consumingPeriodCredit() -> Wallet {
        copy(periodCreditsUsed: periodCreditsUsed + 1)
    }

    func consumingPurchasedCredit() -> Wallet {
        copy(purchasedCredits: max(0, purchasedCredits - 1))
    }

    func unlocking(_ tripID: Identifier<Trip>) -> Wallet {
        copy(unlockedTripIDs: unlockedTripIDs.union([tripID]))
    }

    func subscribing(credits: Int) -> Wallet {
        copy(subscription: .active,
             periodCreditsGranted: periodCreditsGranted + credits,
             periodRenewsOn: Calendar.current.date(byAdding: .month, value: 1, to: .now))
    }

    func addingPurchasedCredits(_ count: Int) -> Wallet {
        copy(purchasedCredits: purchasedCredits + count)
    }
}
