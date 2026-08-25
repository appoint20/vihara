import SwiftUI

@main
struct ViharaApp: App {
    /// Built once, here. Swapping ``AppDependencies/stubbed()`` for
    /// ``AppDependencies/live(configuration:)`` is the entire cutover to the backend.
    private let dependencies = AppDependencies.stubbed()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.dependencies, dependencies)
        }
    }
}
