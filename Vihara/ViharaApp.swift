import SwiftUI

@main
struct ViharaApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

/// Temporary root view. Replaced by `WelcomeView` once the screens land.
struct ContentView: View {
    var body: some View {
        Text("Vihara")
    }
}

#Preview {
    ContentView()
}
