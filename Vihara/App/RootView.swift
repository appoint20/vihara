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

    var body: some View {
        NavigationStack(path: $router.path) {
            WelcomeView()
                .navigationDestination(for: Route.self) { route in
                    destination(for: route)
                }
        }
        .environment(router)
        .tint(Theme.C.accent)
        #if DEBUG
        .task { router.applyLaunchRoute() }
        #endif
    }

    /// View models are built here, from the one place that reads the composition
    /// root. Screens receive a finished model and never reach into the environment
    /// for a dependency — so each one can be previewed, and later tested, with
    /// whatever collaborators the case calls for.
    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .discover:
            DiscoverView(model: DiscoverViewModel(catalogue: dependencies.destinations),
                         savedTrips: SavedTripsViewModel(trips: dependencies.trips))
        case let .intake(destination):
            IntakeView(model: IntakeViewModel(parser: dependencies.briefParser,
                                              catalogue: dependencies.destinations,
                                              destination: destination))
        case let .plan(brief):
            PlanView(model: PlanViewModel(brief: brief,
                                          generateTrip: dependencies.generateTrip))
        case let .savedTrip(trip):
            PlanView(model: PlanViewModel(trip: trip))
        }
    }
}

#Preview {
    RootView()
}
