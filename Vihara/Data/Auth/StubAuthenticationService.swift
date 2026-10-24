import Foundation
import AuthenticationServices

/// Signing in, against no backend.
///
/// **This is a stub in the same sense ``StubTripGenerator`` is one**, and the same
/// caveat applies: the flows are real, the verification is not. Apple and Google both
/// genuinely authenticate — the system sheet and the OAuth round trip are the real
/// thing — but nobody checks the resulting token, because there is no server to check
/// it with. Email and password are stored on the device, hashed, and are not an
/// account in any sense that survives a reinstall.
///
/// When `POST /v1/auth/*` exists, this type is replaced rather than edited: the
/// screens depend on ``AuthenticationService``, not on this.
actor StubAuthenticationService: AuthenticationService {
    private let store: CredentialStore
    private let google: GoogleOAuthFlow

    /// The account the team signs in with while there is no backend.
    ///
    /// A real record in the same store as any other, seeded on first use rather than
    /// special-cased at the sign-in call — so it exercises the whole path (hash,
    /// compare, session, Keychain) instead of stepping around it. When the backend
    /// lands this seeding is the only thing that has to be deleted.
    enum Demo {
        static let email = "vihara-app@gmail.com"
        static let password = "vihara007"
        static let name = "Vihara"
    }

    /// `googleClientID` is injected rather than read at the call site so tests can
    /// exercise the unconfigured path without reading — or printing — a real one.
    private let googleClientID: String?

    init(store: CredentialStore = KeychainCredentialStore(),
         google: GoogleOAuthFlow = GoogleOAuthFlow(),
         googleClientID: String? = AppSecrets.googleOAuthClientID) {
        self.store = store
        self.google = google
        self.googleClientID = googleClientID
    }

    /// Registers the demo account if it is not already there.
    ///
    /// Idempotent, and never overwrites: somebody who changed the demo password on
    /// their own device keeps their change.
    private func seedDemoAccountIfNeeded() async {
        guard await store.emailRecord(for: Demo.email) == nil else { return }
        let salt = UUID().uuidString
        await store.saveEmailRecord(EmailRecord(email: Demo.email,
                                                name: Demo.name,
                                                salt: salt,
                                                passwordHash: Self.hash(Demo.password, salt: salt)))
    }

    // MARK: - Session

    func restoreSession() async -> UserAccount? {
        await seedDemoAccountIfNeeded()
        return await store.currentAccount()
    }

    func signOut() async {
        await store.clear()
    }

    // MARK: - Apple

    /// Apple hands the name over exactly once, on first authorisation. If we do not
    /// keep it now we never get another chance, so a returning traveller is greeted
    /// from what was stored the first time.
    func signIn(withApple credential: AppleCredential) async throws -> UserAccount {
        let id = Identifier<UserAccount>("apple:\(credential.userIdentifier)")
        let remembered = await store.account(for: id)

        let account = UserAccount(
            id: id,
            displayName: credential.fullName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                ?? remembered?.displayName
                ?? "",
            email: credential.email ?? remembered?.email,
            provider: .apple
        )
        await store.save(account)
        return account
    }

    // MARK: - Google

    func signInWithGoogle(presenting context: WebAuthenticationPresenting) async throws -> UserAccount {
        guard googleClientID != nil else {
            throw AuthenticationError.providerNotConfigured(.google)
        }
        let profile = try await google.authenticate(presenting: context)
        let account = UserAccount(id: Identifier("google:\(profile.subject)"),
                                  displayName: profile.name ?? "",
                                  email: profile.email,
                                  provider: .google)
        await store.save(account)
        return account
    }

    // MARK: - Email

    func signIn(email: String, password: String) async throws -> UserAccount {
        await seedDemoAccountIfNeeded()

        let email = Self.normalise(email)
        guard let record = await store.emailRecord(for: email) else {
            throw AuthenticationError.invalidCredentials
        }
        guard record.passwordHash == Self.hash(password, salt: record.salt) else {
            throw AuthenticationError.invalidCredentials
        }
        let account = UserAccount(id: Identifier("email:\(email)"),
                                  displayName: record.name,
                                  email: email,
                                  provider: .email)
        await store.save(account)
        return account
    }

    func register(email: String, password: String, name: String) async throws -> UserAccount {
        let email = Self.normalise(email)
        guard email.contains("@"), email.count >= 5 else {
            throw AuthenticationError.invalidCredentials
        }
        // Eight characters is the floor, and it is a floor rather than a policy: a
        // composition rule ("one capital, one symbol") produces worse passwords and
        // there is no backend here to enforce anything better.
        guard password.count >= 8 else { throw AuthenticationError.weakPassword }
        guard await store.emailRecord(for: email) == nil else {
            throw AuthenticationError.emailAlreadyRegistered
        }

        let salt = UUID().uuidString
        await store.saveEmailRecord(EmailRecord(email: email,
                                                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                                salt: salt,
                                                passwordHash: Self.hash(password, salt: salt)))

        let account = UserAccount(id: Identifier("email:\(email)"),
                                  displayName: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                  email: email,
                                  provider: .email)
        await store.save(account)
        return account
    }

    private static func normalise(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// SHA-256 over salt and password.
    ///
    /// Enough that a stolen device does not hand over a plaintext password, and
    /// nowhere near enough for a real account system — that wants a slow KDF and a
    /// server. Named honestly rather than dressed up.
    private static func hash(_ password: String, salt: String) -> String {
        CryptoHash.sha256("\(salt):\(password)")
    }
}

/// A registered email, as stored on this device.
struct EmailRecord: Codable, Hashable, Sendable {
    let email: String
    let name: String
    let salt: String
    let passwordHash: String
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
