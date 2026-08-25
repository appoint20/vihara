import Testing
import Foundation
@testable import Vihara

/// The decision order from PRD 4.1.
///
/// This is the money path. The server decides for real, but the client picks the
/// sheet — and a client that predicts the wrong outcome either shows a paywall to
/// someone entitled, or promises a download it cannot deliver.
@Suite("Wallet outlook")
struct WalletTests {

    private let tripID = Identifier<Trip>("trip-1")

    private func wallet(subscription: Wallet.SubscriptionState = .none,
                        granted: Int = 0,
                        used: Int = 0,
                        purchased: Int = 0,
                        unlocked: Set<Identifier<Trip>> = [],
                        freeUsed: Int = 0,
                        renews: Date? = nil) -> Wallet {
        Wallet(freeTripsUsedThisYear: freeUsed,
               freeTripsAllowance: 2,
               subscription: subscription,
               periodCreditsGranted: granted,
               periodCreditsUsed: used,
               purchasedCredits: purchased,
               unlockedTripIDs: unlocked,
               periodRenewsOn: renews)
    }

    @Test("An unlocked trip is covered and consumes nothing")
    func unlockWins() {
        let outlook = wallet(unlocked: [tripID]).exportOutlook(for: tripID)

        #expect(outlook == .coveredByUnlock)
    }

    @Test("An unlock outranks credits, so a subscriber never spends one twice on the same trip")
    func unlockOutranksCredits() {
        let subscriber = wallet(subscription: .active, granted: 10, used: 0, unlocked: [tripID])

        #expect(subscriber.exportOutlook(for: tripID) == .coveredByUnlock)
    }

    @Test("Period credits are spent before purchased ones")
    func periodBeforePurchased() {
        let outlook = wallet(subscription: .active, granted: 10, used: 3, purchased: 5)
            .exportOutlook(for: tripID)

        // Purchased credits never expire; period credits do. Spending the perishable
        // one first is what makes that promise true.
        #expect(outlook == .coveredByPeriodCredit(remaining: 7))
    }

    @Test("Purchased credits cover the export once the period is spent")
    func purchasedAfterPeriod() {
        let outlook = wallet(subscription: .active, granted: 10, used: 10, purchased: 2)
            .exportOutlook(for: tripID)

        #expect(outlook == .coveredByPurchasedCredit(remaining: 2))
    }

    @Test("A subscriber with nothing left is offered a top-up, with the refill date")
    func topUp() {
        let refill = Fixture.date(2026, 5, 14)
        let outlook = wallet(subscription: .active, granted: 10, used: 10, renews: refill)
            .exportOutlook(for: tripID)

        #expect(outlook == .needsTopUp(refillsOn: refill))
    }

    @Test("Grace still spends period credits — a failed card does not lock the trip")
    func gracePeriodKeepsWorking() {
        let outlook = wallet(subscription: .grace, granted: 10, used: 4)
            .exportOutlook(for: tripID)

        #expect(outlook == .coveredByPeriodCredit(remaining: 6))
    }

    @Test("Without a subscription the traveller is offered the unlock or the plan")
    func freeAccount() {
        #expect(wallet().exportOutlook(for: tripID) == .needsPurchase)
    }

    /// Open question for the PM — see `Wallet.exportOutlook`.
    @Test("An expired subscription with purchased credits still asks to buy")
    func expiredWithPurchasedCredits() {
        // PRD 4.1 gates purchased credits on an *active* subscription, yet sells them
        // as never expiring. Implemented as written, pinned here so the behaviour
        // cannot change by accident while the question is open.
        let outlook = wallet(subscription: .expired, purchased: 3).exportOutlook(for: tripID)

        #expect(outlook == .needsPurchase)
    }

    @Suite("Generation allowance")
    struct Allowance {

        @Test("A free account may generate until the yearly allowance is gone")
        func freeAllowance() {
            let fresh = Wallet.empty
            #expect(fresh.canGenerateAnotherTrip)
            #expect(fresh.freeGenerationsRemaining == 2)
        }

        @Test("A spent free allowance blocks generation")
        func spentAllowance() {
            let spent = Wallet(freeTripsUsedThisYear: 2, freeTripsAllowance: 2,
                               subscription: .none, periodCreditsGranted: 0,
                               periodCreditsUsed: 0, purchasedCredits: 0,
                               unlockedTripIDs: [], periodRenewsOn: nil)

            #expect(!spent.canGenerateAnotherTrip)
        }

        @Test("A subscriber is never blocked by the free allowance")
        func subscriberIgnoresAllowance() {
            let subscriber = Wallet(freeTripsUsedThisYear: 99, freeTripsAllowance: 2,
                                    subscription: .active, periodCreditsGranted: 10,
                                    periodCreditsUsed: 10, purchasedCredits: 0,
                                    unlockedTripIDs: [], periodRenewsOn: nil)

            #expect(subscriber.canGenerateAnotherTrip)
        }
    }
}
