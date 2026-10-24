import Foundation
import StoreKit

/// Buying things, through StoreKit 2 (F-09).
///
/// Vihara's own credits and subscription are **digital content**, so guideline 3.1.1
/// requires in-app purchase for them. That is the opposite of the booking links in
/// F-10, which are real-world services and so must *not* use IAP (3.1.3(e)). The two
/// revenue streams follow opposite rules and neither may be made to look like the
/// other — see `docs/MONETISATION.md` §6.
///
/// **StoreKit's verification is not entitlement.** `VerificationResult.verified`
/// means Apple signed the transaction, not that this account is entitled: that
/// decision belongs to the server, which validates the receipt and moves the ledger
/// ([ADR-004](../../../docs/adr/004-server-authoritative-entitlements.md)). With no
/// server, the composition root wires `onVerified` straight to
/// ``InMemoryEntitlementServer``, which is a pretence of exactly the same shape as
/// ``StubAuthenticationService`` and has to be undone the day a backend exists.
struct StoreKitPurchases: Purchasing {

    /// The product identifiers, kept here beside the StoreKit calls rather than in
    /// the domain — the domain names *what* is sold, the store names *which SKU*.
    /// They must match `Vihara.storekit` and, later, App Store Connect exactly.
    static let identifiers: [PurchasableProduct: String] = [
        .singleTripUnlock: "com.vihara.app.unlock.trip",
        .subscription:     "com.vihara.app.sub.monthly",
        .creditBundle:     "com.vihara.app.credits.five",
    ]

    /// Called once a transaction is signed by Apple. Stands in for "the receipt
    /// reached the server and the server moved the ledger".
    private let onVerified: @Sendable (PurchasableProduct, Identifier<Trip>?) async -> Void

    init(onVerified: @escaping @Sendable (PurchasableProduct, Identifier<Trip>?) async -> Void) {
        self.onVerified = onVerified
    }

    func prices() async -> [PurchasableProduct: String] {
        guard let products = try? await Product.products(for: Set(Self.identifiers.values)) else {
            // No store, no network, or nothing configured. The paywall omits the rows
            // it has no price for rather than showing a button that cannot be
            // pressed — a price is not optional chrome, it is the offer.
            return [:]
        }

        var prices: [PurchasableProduct: String] = [:]
        for (product, identifier) in Self.identifiers {
            if let match = products.first(where: { $0.id == identifier }) {
                prices[product] = match.displayPrice
            }
        }
        return prices
    }

    func purchase(_ product: PurchasableProduct,
                  tripID: Identifier<Trip>?) async throws -> PurchaseOutcome {
        guard let identifier = Self.identifiers[product],
              let storeProduct = try await Product.products(for: [identifier]).first else {
            throw ExportFailure.server("product unavailable")
        }

        var options: Set<Product.PurchaseOption> = []
        // Binds the purchase to the trip it unlocks. The server keys the unlock on
        // this, which is what makes an unlock follow the account rather than the
        // device — `Wallet.unlockedTripIDs` is documented as exactly that.
        if let tripID, let token = UUID(uuidString: tripID.rawValue) {
            options.insert(.appAccountToken(token))
        }

        switch try await storeProduct.purchase(options: options) {
        case let .success(verification):
            guard case let .verified(transaction) = verification else {
                // Signed by nobody we trust. Finish nothing, grant nothing.
                throw ExportFailure.server("unverified transaction")
            }
            await onVerified(product, tripID)
            await transaction.finish()
            return .purchased

        case .userCancelled:
            return .cancelled

        case .pending:
            // Ask-to-buy, or a payment held for review. Entitlement may arrive in
            // minutes, days, or never, so the UI must not promise a download.
            return .pending

        @unknown default:
            return .cancelled
        }
    }

    func restore() async throws {
        try await AppStore.sync()
    }

    /// Transactions that arrive outside a purchase: a renewal, an ask-to-buy
    /// approved later, a purchase made on another device.
    ///
    /// Without this, a subscription renewal never reaches the ledger and a
    /// previously-pending purchase is lost. Started once by the composition root and
    /// left running for the life of the app.
    func observeTransactions() -> Task<Void, Never> {
        Task.detached(priority: .background) {
            for await update in Transaction.updates {
                guard case let .verified(transaction) = update else { continue }
                guard let product = Self.identifiers.first(where: { $0.value == transaction.productID })?.key
                else { continue }

                let tripID = transaction.appAccountToken.map { Identifier<Trip>($0.uuidString) }
                await onVerified(product, tripID)
                await transaction.finish()
            }
        }
    }
}
