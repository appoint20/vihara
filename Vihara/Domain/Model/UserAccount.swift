import Foundation

/// Who is signed in.
///
/// Deliberately thin. The app needs a name to greet somebody by and a stable id to
/// hang their plans off; everything else a provider hands back is somebody else's
/// data we would then be responsible for. Apple in particular gives the name *once*,
/// on first authorisation, so what is captured here is captured then or not at all.
struct UserAccount: Hashable, Sendable, Identifiable {
    let id: Identifier<UserAccount>
    /// What the greeting uses. May be empty — Apple lets people hide their name, and
    /// a traveller who declined to give one is greeted without it rather than nagged.
    var displayName: String
    /// May be a private relay address (`…@privaterelay.appleid.com`). Never shown.
    var email: String?
    let provider: Provider

    init(id: Identifier<UserAccount>,
         displayName: String = "",
         email: String? = nil,
         provider: Provider) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.provider = provider
    }

    enum Provider: String, Hashable, Sendable, CaseIterable {
        case apple
        case google
        /// Email and password, once a backend exists to check them against.
        case email
    }

    /// The first name, for a greeting. "Sanya Mehta" greets as "Sanya".
    var greetingName: String {
        displayName.split(separator: " ").first.map(String.init) ?? displayName
    }
}

/// Signing in, and staying signed in.
///
/// Behind a protocol because all three routes end in the same place — an account and
/// a session — and the screen must not care which one the traveller took.
protocol AuthenticationService: Sendable {
    /// The account restored from a previous launch, if the session is still good.
    func restoreSession() async -> UserAccount?

    /// Completes a Sign in with Apple authorisation.
    ///
    /// The credential is produced by the system sheet, which only a view can raise —
    /// so the view raises it and hands the result here rather than this type reaching
    /// for UI.
    func signIn(withApple credential: AppleCredential) async throws -> UserAccount

    /// Runs Google's OAuth flow and exchanges the code for an account.
    func signInWithGoogle(presenting context: WebAuthenticationPresenting) async throws -> UserAccount

    /// Email and password, for people who want neither provider.
    func signIn(email: String, password: String) async throws -> UserAccount
    func register(email: String, password: String, name: String) async throws -> UserAccount

    func signOut() async
}

/// What Sign in with Apple hands back.
///
/// A plain value rather than `ASAuthorizationAppleIDCredential`, so the domain does
/// not import AuthenticationServices and the flow stays testable.
struct AppleCredential: Hashable, Sendable {
    let userIdentifier: String
    let fullName: String?
    let email: String?
    /// The JWT the backend will verify once there is one. Held, not trusted here: a
    /// client cannot validate its own identity token in any meaningful sense.
    let identityToken: String?
}

/// Something that can present a web sheet for OAuth.
///
/// The Google flow needs a presentation anchor, which is a UIKit concept. This keeps
/// the requirement in the signature without dragging UIKit into the domain.
protocol WebAuthenticationPresenting: Sendable {}

/// What can go wrong on the way in.
enum AuthenticationError: Error, Hashable, Sendable {
    case cancelled
    /// The provider is not configured — no client id, no key. A build problem, and
    /// the message says so rather than blaming the traveller.
    case providerNotConfigured(UserAccount.Provider)
    case invalidCredentials
    case emailAlreadyRegistered
    case weakPassword
    case network
    case unexpected
}
