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
    /// Unfinished interviews, offered back on the home surface.
    let interviewDrafts: any InterviewDraftStore
    /// Signing in. Real flows, unverified tokens — see ``StubAuthenticationService``.
    let authentication: any AuthenticationService
    /// Searching for somewhere to go. Google Places when a key is configured, the
    /// curated catalogue when not — the screen cannot tell which.
    let placeSearch: any PlaceSearching
    /// F-10. Optional throughout: a plan whose value depended on an offer would be
    /// "a collection of links" under App Store guideline 4.2.2.
    let offers: (any OfferProviding)?
    let offerClicks: (any OfferClickReporting)?
    /// F-11. A static table today — see ``StaticExchangeRates``, which is why the
    /// budget prints an estimate rather than a price.
    let rates: any ExchangeRates
    /// F-08. The grant half of exporting, which belongs to the server.
    let exporter: any PlanExporting
    /// F-09. StoreKit, behind a protocol so no screen imports it.
    let purchases: any Purchasing
    /// Renewals, ask-to-buy approvals and purchases made on another device arrive
    /// here. Started once by ``ViharaApp``; without it a renewal never reaches the
    /// ledger.
    let transactionObserver: @Sendable () -> Task<Void, Never>
    /// What the share extension left behind. A value type over a file in the App
    /// Group container — see ``SharedInbox``, and note that it is a provisioning
    /// dependency as much as a code one.
    let sharedInbox: SharedInbox
    /// Reads a caption behind a shared link, where the platform publishes one.
    let captions: any CaptionResolving
    /// What captions are matched against. Built once: 285 cities plus the curated
    /// destinations, and the curated ones win.
    let vocabulary: PlaceVocabulary

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
        // One object plays the whole entitlement backend: it answers the wallet
        // read, it grants exports, and it is what a verified purchase moves. That is
        // deliberate — it is the *server*, faked, not three client capabilities.
        // See ``InMemoryEntitlementServer`` and ADR-004.
        let entitlements = InMemoryEntitlementServer(wallet: wallet)
        let storeKit = StoreKitPurchases { product, tripID in
            await entitlements.apply(product, tripID: tripID)
        }
        return AppDependencies(
            generateTrip: GenerateTrip(generator: StubTripGenerator(catalogue: destinations),
                                       trips: trips,
                                       wallets: entitlements),
            trips: trips,
            wallets: entitlements,
            destinations: destinations,
            briefParser: HeuristicTripBriefParser(catalogue: destinations),
            interviewDrafts: UserDefaultsInterviewDraftStore(),
            authentication: StubAuthenticationService(),
            placeSearch: Self.placeSearch(catalogue: destinations),
            offers: StubOfferProvider(),
            offerClicks: StubOfferClickReporter(),
            rates: StaticExchangeRates(),
            exporter: entitlements,
            purchases: storeKit,
            transactionObserver: { storeKit.observeTransactions() },
            sharedInbox: SharedInbox(),
            captions: TikTokOEmbedCaptions(),
            vocabulary: CatalogueVocabulary.build()
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
        // Still faked: `POST /v1/trips/:id/export` is a different endpoint from the
        // plan service, and this configuration only moves generation.
        let entitlements = InMemoryEntitlementServer()
        let storeKit = StoreKitPurchases { product, tripID in
            await entitlements.apply(product, tripID: tripID)
        }
        return AppDependencies(
            generateTrip: GenerateTrip(generator: RemoteTripGenerator(client: client),
                                       trips: trips,
                                       wallets: entitlements),
            trips: trips,
            wallets: entitlements,
            destinations: destinations,
            briefParser: HeuristicTripBriefParser(catalogue: destinations),
            interviewDrafts: UserDefaultsInterviewDraftStore(),
            authentication: StubAuthenticationService(),
            placeSearch: Self.placeSearch(catalogue: destinations),
            // Still the stub: the offer service is a separate, much smaller backend
            // than the plan service, and it is not this configuration's job to
            // pretend otherwise. See `docs/MONETISATION.md` §8, step 2.
            // The one line that was waiting for step 2. Markers, deep links and
            // click logging all moved behind `GET /v1/offers` — nothing above this
            // line changed, which is what ADR-006 was for.
            offers: RemoteOfferService(client: client),
            offerClicks: RemoteClickReporter(client: client),
            rates: StaticExchangeRates(),
            exporter: entitlements,
            purchases: storeKit,
            transactionObserver: { storeKit.observeTransactions() },
            sharedInbox: SharedInbox(),
            captions: TikTokOEmbedCaptions(),
            vocabulary: CatalogueVocabulary.build()
        )
    }
}

extension AppDependencies {

    /// The curated catalogue, then the rest of the world: Google Places when there is
    /// a key, the bundled corpus of 285 cities when there is not.
    ///
    /// Neither tier is a degraded mode. The catalogue is the only source that knows
    /// which regions we can actually *plan*, so it always answers first; the second
    /// tier exists to name everywhere else as **unplannable**, which is how the app
    /// says "not yet" by name instead of returning nothing.
    ///
    /// Before ``BundledCityCatalogue`` the keyless path returned three cities, so a
    /// traveller typing "Lissabon" got silence — indistinguishable from a broken
    /// field. It now gets Lisbon, marked as somewhere we cannot plan.
    ///
    /// Takes the key rather than reading it, so the choice is testable without a
    /// bundle — and so no test can accidentally assert on, or print, a real key.
    static func placeSearch(catalogue: any DestinationCatalogue,
                            apiKey: String? = AppSecrets.googlePlacesAPIKey,
                            corpus: any PlaceSearching = BundledCityCatalogue.bundled) -> any PlaceSearching {
        let curated = CataloguePlaceSearch(catalogue: catalogue)
        let world: any PlaceSearching = apiKey.map { GooglePlacesSearch(apiKey: $0) } ?? corpus
        return CombinedPlaceSearch(curated: curated, remote: world)
    }

    /// The composition root, for the two places that cannot reach the environment:
    /// ``ViharaApp`` builds it, and ``RootView`` reads it in `init` to construct the
    /// session before any view exists.
    static let current = AppDependencies.stubbed()
}

// MARK: - Environment

private struct AppDependenciesKey: EnvironmentKey {
    /// Previews and Xcode canvases get working dependencies without any setup.
    static let defaultValue = AppDependencies.current
}

extension EnvironmentValues {
    var dependencies: AppDependencies {
        get { self[AppDependenciesKey.self] }
        set { self[AppDependenciesKey.self] = newValue }
    }
}
