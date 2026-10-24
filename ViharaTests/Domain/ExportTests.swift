import Testing
import Foundation
@testable import Vihara

/// The money path, server side. The client predicts; this decides.
@Suite("Granting an export")
struct EntitlementServerTests {

    private let tripID = Identifier<Trip>("trip-1")

    private func wallet(subscription: Wallet.SubscriptionState = .none,
                        granted: Int = 0,
                        used: Int = 0,
                        purchased: Int = 0,
                        unlocked: Set<Identifier<Trip>> = []) -> Wallet {
        Wallet(freeTripsUsedThisYear: 0,
               freeTripsAllowance: 2,
               subscription: subscription,
               periodCreditsGranted: granted,
               periodCreditsUsed: used,
               purchasedCredits: purchased,
               unlockedTripIDs: unlocked,
               periodRenewsOn: nil)
    }

    @Test("An unlocked trip exports in full and consumes nothing")
    func unlockedTripIsFull() async throws {
        let server = InMemoryEntitlementServer(wallet: wallet(unlocked: [tripID]))

        #expect(try await server.requestGrant(tripID: tripID, revision: 0) == .full)

        let after = try await server.currentWallet()
        #expect(after.purchasedCredits == 0)
        #expect(after.periodCreditsUsed == 0)
    }

    @Test("A subscriber's period credit is spent, and the balance drops")
    func periodCreditIsSpent() async throws {
        let server = InMemoryEntitlementServer(wallet: wallet(subscription: .active, granted: 3))

        #expect(try await server.requestGrant(tripID: tripID, revision: 0) == .full)
        #expect(try await server.currentWallet().periodCreditsRemaining == 2)
    }

    /// PRD 4.1's order: period credits go first, so a purchased credit is never
    /// quietly wiped by a period reset.
    @Test("Period credits are spent before purchased ones")
    func periodBeforePurchased() async throws {
        let server = InMemoryEntitlementServer(
            wallet: wallet(subscription: .active, granted: 1, purchased: 2)
        )

        _ = try await server.requestGrant(tripID: tripID, revision: 0)
        let after = try await server.currentWallet()

        #expect(after.periodCreditsRemaining == 0)
        #expect(after.purchasedCredits == 2)
    }

    /// PRD 4 promises a watermarked preview, not a locked door.
    @Test("A free account is granted a preview rather than refused")
    func freeAccountGetsAPreview() async throws {
        let server = InMemoryEntitlementServer(wallet: wallet())

        let grant = try await server.requestGrant(tripID: tripID, revision: 0)

        #expect(grant == .preview(daysInFull: InMemoryEntitlementServer.previewDaysInFull))
        #expect(grant.isWatermarked)
    }

    /// The double-charging risk named in docs/ROADMAP.md: a traveller taps twice
    /// because the first tap seemed slow.
    @Test("Exporting the same revision twice is granted once and charged once")
    func idempotentPerRevision() async throws {
        let server = InMemoryEntitlementServer(wallet: wallet(subscription: .active, granted: 2))

        #expect(try await server.requestGrant(tripID: tripID, revision: 4) == .full)
        #expect(try await server.requestGrant(tripID: tripID, revision: 4) == .full)

        #expect(try await server.currentWallet().periodCreditsRemaining == 1)
    }

    /// An edited plan is a different plan. `Trip.revision` is documented as bumping
    /// on every accepted edit precisely so this is true.
    @Test("A new revision is a new export, and costs again")
    func newRevisionCostsAgain() async throws {
        let server = InMemoryEntitlementServer(wallet: wallet(subscription: .active, granted: 2))

        _ = try await server.requestGrant(tripID: tripID, revision: 1)
        _ = try await server.requestGrant(tripID: tripID, revision: 2)

        #expect(try await server.currentWallet().periodCreditsRemaining == 0)
    }

    /// Caching a preview would trap the traveller on a watermarked file *after* they
    /// had just paid to remove the watermark. A preview consumed nothing, so there is
    /// nothing to be idempotent about.
    @Test("A preview is not cached, so a purchase takes effect immediately")
    func previewIsNotCached() async throws {
        let server = InMemoryEntitlementServer(wallet: wallet())

        #expect(try await server.requestGrant(tripID: tripID, revision: 0).isWatermarked)

        await server.apply(.singleTripUnlock, tripID: tripID)

        #expect(try await server.requestGrant(tripID: tripID, revision: 0) == .full)
    }

    // MARK: - Purchases moving the ledger

    @Test("A single unlock binds to the trip, not the device")
    func unlockBindsToTheTrip() async throws {
        let server = InMemoryEntitlementServer(wallet: wallet())
        await server.apply(.singleTripUnlock, tripID: tripID)

        let after = try await server.currentWallet()
        #expect(after.unlockedTripIDs == [tripID])
        // Another plan is still not covered.
        #expect(after.exportOutlook(for: Identifier("other")) == .needsPurchase)
    }

    @Test("Subscribing turns the subscription on and grants the period allowance")
    func subscribing() async throws {
        let server = InMemoryEntitlementServer(wallet: wallet())
        await server.apply(.subscription, tripID: nil)

        let after = try await server.currentWallet()
        #expect(after.subscription == .active)
        #expect(after.periodCreditsRemaining == InMemoryEntitlementServer.creditsPerPeriod)
        #expect(after.periodRenewsOn != nil)
    }

    @Test("A top-up bundle adds purchased credits")
    func topUp() async throws {
        let server = InMemoryEntitlementServer(wallet: wallet(subscription: .active))
        await server.apply(.creditBundle, tripID: nil)

        #expect(try await server.currentWallet().purchasedCredits
                == InMemoryEntitlementServer.creditsPerBundle)
    }

    /// An unlock with no trip to bind to would be money for nothing.
    @Test("A single unlock with no trip changes nothing")
    func unlockWithoutATripIsIgnored() async throws {
        let server = InMemoryEntitlementServer(wallet: wallet())
        await server.apply(.singleTripUnlock, tripID: nil)

        #expect(try await server.currentWallet().unlockedTripIDs.isEmpty)
    }
}

@Suite("Which paywall is offered")
struct PaywallVariantTests {

    /// Variant A: no subscription. The cheap way out and the good deal.
    @Test("Without a subscription, the unlock and the subscription are offered")
    func variantA() {
        let offered = PurchasableProduct.allCases.filter { $0.isOffered(for: .needsPurchase) }
        #expect(Set(offered) == [.singleTripUnlock, .subscription])
    }

    /// Variant B: already paying. Selling the subscription again reads as a bug, and
    /// a single unlock would undercut the top-up.
    @Test("A subscriber who is out is offered only a top-up")
    func variantB() {
        let offered = PurchasableProduct.allCases.filter { $0.isOffered(for: .needsTopUp(refillsOn: nil)) }
        #expect(offered == [.creditBundle])
    }

    @Test("Nothing is sold to somebody already covered")
    func coveredSellsNothing() {
        for outlook in [ExportOutlook.coveredByUnlock,
                        .coveredByPeriodCredit(remaining: 1),
                        .coveredByPurchasedCredit(remaining: 1)] {
            #expect(PurchasableProduct.allCases.allSatisfy { !$0.isOffered(for: outlook) })
        }
    }

    @Test("Every product and every paywall string is localised")
    func paywallStringsExist() {
        let keys = ["paywall.title", "paywall.notNow", "paywall.restore", "paywall.pending",
                    "paywall.failed", "paywall.unavailable", "paywall.preview.note",
                    "paywall.headline.purchase", "paywall.headline.topUp",
                    "paywall.body.purchase", "paywall.body.topUp",
                    "export.action", "export.share", "export.watermark",
                    "export.preview.heading", "export.preview.footer"]
        for language in ["de", "en"] {
            let locale = Locale(identifier: language)
            for key in keys {
                #expect(localized(key, locale: locale) != key, "\(key) missing in \(language)")
            }
            for product in PurchasableProduct.allCases {
                for prefix in ["paywall.product.", "paywall.detail."] {
                    let key = prefix + product.rawValue
                    #expect(localized(key, locale: locale) != key, "\(key) missing in \(language)")
                }
            }
        }
    }

    @Test("Every product has a StoreKit identifier")
    func everyProductHasASKU() {
        for product in PurchasableProduct.allCases {
            #expect(StoreKitPurchases.identifiers[product] != nil, "\(product) has no product id")
        }
    }
}
