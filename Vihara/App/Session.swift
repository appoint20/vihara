import SwiftUI

/// Who is signed in, for the whole app.
///
/// Lives above the navigation stack because the answer decides whether there *is* a
/// navigation stack: signed out, the only reachable screens are Welcome and Sign in.
/// Screens read the account from here rather than being handed one, because the
/// greeting needs it in three places and threading it through every initialiser buys
/// nothing.
@MainActor
@Observable
final class Session {
    private let service: any AuthenticationService

    private(set) var account: UserAccount?
    /// True until the stored session has been looked for. The gate waits on this —
    /// otherwise a returning traveller sees the sign-in screen flash past on every
    /// launch.
    private(set) var isRestoring = true

    init(service: any AuthenticationService) {
        self.service = service
    }

    var isSignedIn: Bool { account != nil }

    func restore() async {
        #if DEBUG
        // Same seam as `-vihara-route`: reaching a screen four taps in should not
        // require four taps, whether the thing doing the reaching is a person
        // iterating on layout or a UI test asserting on it.
        //
        //     xcrun simctl launch booted com.vihara.app -vihara-signed-in Sanya
        if let name = UserDefaults.standard.string(forKey: "vihara-signed-in"), !name.isEmpty {
            account = UserAccount(id: Identifier("debug:\(name)"),
                                  displayName: name,
                                  provider: .email)
            isRestoring = false
            return
        }
        #endif
        account = await service.restoreSession()
        isRestoring = false
    }

    func signedIn(as account: UserAccount) {
        self.account = account
    }

    func signOut() async {
        await service.signOut()
        account = nil
    }

    /// The name the greeting uses, preferring what the traveller typed over what the
    /// provider said — somebody who corrected their name meant it.
    func greetingName(overriddenBy stored: String) -> String {
        let trimmed = stored.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? (account?.greetingName ?? "") : trimmed
    }
}
