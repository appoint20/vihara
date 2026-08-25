import Foundation

/// Where plans live.
///
/// Offline-first: reads resolve from the local store, and the implementation
/// reconciles with the server in the background. Callers never wait on the network
/// to see a trip they already have.
protocol TripRepository: Sendable {
    func allTrips() async throws -> [Trip]
    func trip(id: Identifier<Trip>) async throws -> Trip?
    func save(_ trip: Trip) async throws
    func delete(id: Identifier<Trip>) async throws
}

/// Reads the account's entitlement state.
///
/// Read-only on purpose: see ``Wallet``. There is no `spend` here because spending
/// is not a client capability.
protocol WalletRepository: Sendable {
    func currentWallet() async throws -> Wallet
}
