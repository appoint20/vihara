import SwiftUI

/// The composition root.
///
/// Every concrete type in the app is chosen here and nowhere else. Screens receive
/// protocols and use cases; they never construct a repository, never see a
/// `URLSession`, and never reach for a shared singleton — which is what makes each
/// one testable and previewable in isolation.
///
/// There is exactly one of these per running app, built in ``ViharaApp`` and read
/// from the environment.
struct AppDependencies: Sendable {
    let generateTrip: GenerateTrip
    let trips: any TripRepository
    let wallets: any WalletRepository
    let destinations: any DestinationCatalogue
    let briefParser: any TripBriefParsing

    /// What ships today: real screens, real streaming, real on-device storage,
    /// sample data.
    ///
    /// The plan service does not exist yet, so generation is served by
    /// ``StubTripGenerator``. Nothing above this line knows that. Storage, by
    /// contrast, is no longer a stub: a plan the traveller generated is still there
    /// after the app is killed, which is the minimum a travel planner owes someone
    /// standing on a street corner with no signal.
    static func stubbed(wallet: Wallet = .empty) -> AppDependencies {
        let destinations = PilotDestinationCatalogue()
        let trips = FileTripRepository()
        let wallets = StubWalletRepository(wallet: wallet)
        return AppDependencies(
            generateTrip: GenerateTrip(generator: StubTripGenerator(catalogue: destinations),
                                       trips: trips,
                                       wallets: wallets),
            trips: trips,
            wallets: wallets,
            destinations: destinations,
            briefParser: HeuristicTripBriefParser(catalogue: destinations)
        )
    }

    /// What the first backend integration looks like: generation moves to the server,
    /// storage and entitlements follow later.
    ///
    /// This is the whole diff when `POST /v1/trips` goes live — one line in one file.
    /// If it ever needs to be more than that, a boundary has leaked.
    static func live(configuration: APIConfiguration) -> AppDependencies {
        let client = URLSessionHTTPClient(configuration: configuration)
        let destinations = PilotDestinationCatalogue()
        let trips = FileTripRepository()
        let wallets = StubWalletRepository()
        return AppDependencies(
            generateTrip: GenerateTrip(generator: RemoteTripGenerator(client: client),
                                       trips: trips,
                                       wallets: wallets),
            trips: trips,
            wallets: wallets,
            destinations: destinations,
            briefParser: HeuristicTripBriefParser(catalogue: destinations)
        )
    }
}

// MARK: - Environment

private struct AppDependenciesKey: EnvironmentKey {
    /// Previews and Xcode canvases get working dependencies without any setup.
    static let defaultValue = AppDependencies.stubbed()
}

extension EnvironmentValues {
    var dependencies: AppDependencies {
        get { self[AppDependenciesKey.self] }
        set { self[AppDependenciesKey.self] = newValue }
    }
}
