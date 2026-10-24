import SwiftUI

/// Owns the navigation stack so no screen has to.
///
/// The previous spike put a `NavigationStack` inside `WelcomeView`; moving it up here
/// means every screen is a plain view that can be previewed, tested and pushed from
/// anywhere — including from a deep link or a push notification, neither of which can
/// reach a `NavigationLink` buried in a leaf.
struct RootView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var router = Router()
    @State private var session = Session(service: AppDependencies.current.authentication)
    @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.deviceDefault

    var body: some View {
        NavigationStack(path: $router.path) {
            WelcomeView()
                .navigationDestination(for: Route.self) { route in
                    destination(for: route)
                }
        }
        .environment(router)
        .environment(session)
        .task { await session.restore() }
        // Applied once, at the root: every `Text(LocalizedStringKey)` below resolves
        // against this, and so does every date and number the plan formats. Changing
        // it in Settings re-renders the whole app in the other language without a
        // relaunch.
        .environment(\.locale, language.locale)
        .tint(Theme.C.accent)
        #if DEBUG
        .task { router.applyLaunchRoute() }
        #endif
    }

    /// The gate.
    ///
    /// Routing decides what is reachable, so the check lives here rather than in each
    /// screen: a screen that has to remember to check is one that will eventually
    /// forget. Signed out, every destination resolves to ``AuthView`` — including a
    /// deep link, which is exactly the case a check written into a button would miss.
    @ViewBuilder
    private func destination(for route: Route) -> some View {
        if session.isRestoring {
            restoring
        } else if session.isSignedIn, route != .auth {
            signedInDestination(for: route)
        } else {
            AuthView(model: SignInViewModel(service: dependencies.authentication) { account in
                session.signedIn(as: account)
                // Straight on to the home surface, rather than back to Welcome. The
                // sign-in screen is a door, and a door you walk back out of is a wall.
                router.path = [.discover]
            })
        }
    }

    /// Held for the moment it takes to read the Keychain, so a returning traveller
    /// never sees the sign-in screen flash past on launch.
    private var restoring: some View {
        ProgressView()
            .tint(Theme.C.accent)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.C.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
    }

    /// View models are built here, from the one place that reads the composition
    /// root. Screens receive a finished model and never reach into the environment
    /// for a dependency — so each one can be previewed, and later tested, with
    /// whatever collaborators the case calls for.
    @ViewBuilder
    private func signedInDestination(for route: Route) -> some View {
        switch route {
        case .auth:
            EmptyView()
        case .discover:
            HomeView(model: HomeViewModel(catalogue: dependencies.destinations,
                                          placeSearch: dependencies.placeSearch,
                                          drafts: dependencies.interviewDrafts),
                     inbox: CaptureInboxViewModel(inbox: dependencies.sharedInbox,
                                                  captions: dependencies.captions,
                                                  vocabulary: dependencies.vocabulary,
                                                  placeSearch: dependencies.placeSearch),
                     savedTrips: SavedTripsViewModel(trips: dependencies.trips))
        case let .intake(destination):
            IntakeView(model: IntakeViewModel(parser: dependencies.briefParser,
                                              catalogue: dependencies.destinations,
                                              destination: destination))
        case let .plan(brief):
            PlanView(model: PlanViewModel(brief: brief,
                                          generateTrip: dependencies.generateTrip,
                                          offerProvider: dependencies.offers,
                                          clickReporter: dependencies.offerClicks,
                                          trips: dependencies.trips,
                                          rates: dependencies.rates,
                                          exporter: dependencies.exporter,
                                          purchases: dependencies.purchases,
                                          wallets: dependencies.wallets))
        case let .savedTrip(trip):
            PlanView(model: PlanViewModel(trip: trip,
                                          offerProvider: dependencies.offers,
                                          clickReporter: dependencies.offerClicks,
                                          trips: dependencies.trips,
                                          rates: dependencies.rates,
                                          exporter: dependencies.exporter,
                                          purchases: dependencies.purchases,
                                          wallets: dependencies.wallets))
        }
    }
}

#Preview {
    RootView()
}
