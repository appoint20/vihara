import SwiftUI

@main
struct ViharaApp: App {
    /// Built once, here. Swapping ``AppDependencies/stubbed()`` for
    /// ``AppDependencies/live(configuration:)`` is the entire cutover to the backend.
    private let dependencies = AppDependencies.current

    init() {
        FontRegistration.registerCustomFonts()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.dependencies, dependencies)
                // StoreKit delivers renewals, ask-to-buy approvals and purchases
                // made on another device outside any purchase call. Without this
                // listener a renewal never reaches the ledger, and a transaction
                // that is never finished is re-delivered on every launch.
                .task { _ = dependencies.transactionObserver() }
        }
    }
}
