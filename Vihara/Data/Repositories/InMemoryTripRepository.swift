import Foundation

/// Plans held in memory for the duration of a launch.
///
/// **No longer what the app runs on** — ``FileTripRepository`` is, so a plan survives
/// the app being killed. This stays as the test double and the preview store: an
/// `actor` with the same shape, seedable, and with no filesystem to clean up
/// afterwards.
actor InMemoryTripRepository: TripRepository {
    private var storage: [Identifier<Trip>: Trip] = [:]

    init(seed: [Trip] = []) {
        for trip in seed { storage[trip.id] = trip }
    }

    func allTrips() async throws -> [Trip] {
        storage.values.sorted { $0.createdAt > $1.createdAt }
    }

    func trip(id: Identifier<Trip>) async throws -> Trip? {
        storage[id]
    }

    func save(_ trip: Trip) async throws {
        storage[trip.id] = trip
    }

    func delete(id: Identifier<Trip>) async throws {
        storage[id] = nil
    }
}

/// A fixed wallet, for running the app before accounts and RevenueCat exist.
///
/// Defaults to a free account with both generations still available, which is the
/// state most worth designing against.
struct StubWalletRepository: WalletRepository {
    private let wallet: Wallet

    init(wallet: Wallet = .empty) {
        self.wallet = wallet
    }

    func currentWallet() async throws -> Wallet { wallet }
}
