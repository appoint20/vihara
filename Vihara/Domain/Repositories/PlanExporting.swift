import Foundation

/// Produces the exportable file (F-08).
///
/// Behind a protocol because the grant half belongs to the server and the render half
/// belongs to the client, and the screen must not learn where the line is.
///
/// **Idempotent per `(trip, revision)`.** A traveller who taps *Exportieren* twice
/// because the first tap seemed slow must not be billed twice — the risk named in
/// `docs/ROADMAP.md`. Implementations key the grant on the revision, so the second
/// call returns the first call's grant and consumes nothing.
protocol PlanExporting: Sendable {
    /// Asks for permission. Throws ``ExportFailure/notEntitled(_:)`` carrying the
    /// outlook to raise a paywall for.
    func requestGrant(tripID: Identifier<Trip>, revision: Int) async throws -> ExportGrant
}

/// Buying things (F-09).
///
/// StoreKit sits behind this so the paywall can be built, previewed and tested
/// without a sandbox account, and so the screen never imports StoreKit.
protocol Purchasing: Sendable {
    /// Localised price strings, keyed by product. A product the store has not
    /// configured is simply absent, and the paywall omits its row rather than
    /// showing a button that cannot be pressed.
    func prices() async -> [PurchasableProduct: String]
    func purchase(_ product: PurchasableProduct,
                  tripID: Identifier<Trip>?) async throws -> PurchaseOutcome
    /// Restores previous purchases. Required by App Store review for any
    /// non-consumable, and the only way a reinstall gets its unlocks back.
    func restore() async throws
}
