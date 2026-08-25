import SwiftUI

/// Where the traveller can be.
///
/// A closed enum rather than free-form `NavigationLink` destinations: it keeps the
/// whole navigable surface of the app visible in one place, which is how the
/// three-levels rule (PRD 5.1) stays enforceable rather than aspirational.
///
/// Route values carry data, not references. Pushing `.plan(brief:)` hands the next
/// screen everything it needs, so there is no shared mutable state between screens
/// and deep links are a matter of constructing a value.
enum Route: Hashable {
    case discover
    /// Intake, optionally opened from a destination card.
    case intake(destination: Destination?)
    /// The plan itself. Generation starts when the screen appears.
    case plan(brief: TripBrief)
    /// A plan the traveller already has, opened from "Meine Reisen". Carries the
    /// whole trip rather than an id, so the screen never has to load — and never
    /// re-generates something that was already composed and saved.
    case savedTrip(Trip)
}

/// The navigation stack's path, owned above every screen.
@MainActor
@Observable
final class Router {
    var path: [Route] = []

    func push(_ route: Route) {
        path.append(route)
    }

    /// Returns to Discover after a plan is finished, rather than unwinding through
    /// intake — the traveller has no reason to see the form they already filled in.
    ///
    /// The plan is not lost by going back: it is on disk, and "Meine Reisen" is one
    /// tap away.
    func popToDiscover() {
        path = path.first == .discover ? [.discover] : []
    }

    func popToRoot() {
        path.removeAll()
    }
}

#if DEBUG
extension Router {

    /// Jumps straight to a screen at launch, from a command-line argument.
    ///
    ///     xcrun simctl launch <device> com.vihara.app -vihara-route plan
    ///
    /// Debug-only, and the same seam UI tests and deep links use: reaching a screen
    /// four taps in should not require four taps, whether the thing doing the
    /// reaching is a person iterating on layout or a test asserting on it.
    func applyLaunchRoute() {
        guard path.isEmpty,
              let raw = UserDefaults.standard.string(forKey: "vihara-route")
        else { return }

        switch raw {
        case "discover":
            path = [.discover]
        case "intake":
            path = [.discover, .intake(destination: nil)]
        case "plan":
            path = [.discover, .intake(destination: nil), .plan(brief: Self.sampleBrief)]
        default:
            break
        }
    }

    private static var sampleBrief: TripBrief {
        TripBrief(destination: "Bologna",
                  startDate: Calendar.current.date(byAdding: .day, value: 21, to: .now) ?? .now,
                  nights: 3,
                  pace: .balanced,
                  diet: .vegetarian)
    }
}
#endif
