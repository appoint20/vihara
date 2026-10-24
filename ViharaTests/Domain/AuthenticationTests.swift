import Testing
import Foundation
@testable import Vihara

/// The gate has to actually be a gate. The version of this screen it replaced
/// accepted any input and pushed on, which is worse than no gate at all.
@Suite("Signing in")
struct AuthenticationTests {

    private func service() -> StubAuthenticationService {
        StubAuthenticationService(store: InMemoryCredentialStore())
    }

    // MARK: - Email

    @Test("Registering then signing in with the same password works")
    func registerThenSignIn() async throws {
        let service = service()
        let registered = try await service.register(email: "Sanya@Example.com",
                                                    password: "correct-horse",
                                                    name: "Sanya Mehta")
        #expect(registered.displayName == "Sanya Mehta")
        #expect(registered.greetingName == "Sanya")
        // Addresses are case-insensitive, so the stored one is normalised.
        #expect(registered.email == "sanya@example.com")

        let signedIn = try await service.signIn(email: "sanya@example.com", password: "correct-horse")
        #expect(signedIn.id == registered.id)
    }

    @Test("A wrong password is refused")
    func wrongPassword() async throws {
        let service = service()
        _ = try await service.register(email: "sanya@example.com", password: "correct-horse", name: "Sanya")

        await #expect(throws: AuthenticationError.invalidCredentials) {
            try await service.signIn(email: "sanya@example.com", password: "wrong-horse")
        }
    }

    @Test("An unknown address is refused, and says the same thing a wrong password does")
    func unknownAccount() async {
        await #expect(throws: AuthenticationError.invalidCredentials) {
            try await service().signIn(email: "nobody@example.com", password: "correct-horse")
        }
    }

    @Test("The same address cannot be registered twice")
    func duplicateRegistration() async throws {
        let service = service()
        _ = try await service.register(email: "sanya@example.com", password: "correct-horse", name: "Sanya")

        await #expect(throws: AuthenticationError.emailAlreadyRegistered) {
            try await service.register(email: "SANYA@example.com", password: "another-one", name: "Sanya")
        }
    }

    @Test("A short password is refused before an account exists")
    func weakPassword() async {
        await #expect(throws: AuthenticationError.weakPassword) {
            try await service().register(email: "sanya@example.com", password: "short", name: "Sanya")
        }
    }

    @Test("Something that is not an address is refused")
    func malformedEmail() async {
        await #expect(throws: AuthenticationError.invalidCredentials) {
            try await service().register(email: "sanya", password: "correct-horse", name: "Sanya")
        }
    }

    @Test("Passwords are never stored in the clear")
    func passwordsAreHashed() async throws {
        let store = InMemoryCredentialStore()
        let service = StubAuthenticationService(store: store)
        _ = try await service.register(email: "sanya@example.com", password: "correct-horse", name: "Sanya")

        let record = try #require(await store.emailRecord(for: "sanya@example.com"))
        #expect(record.passwordHash != "correct-horse")
        #expect(!record.passwordHash.contains("correct-horse"))
        #expect(!record.salt.isEmpty)
    }

    @Test("Two accounts with the same password get different hashes")
    func saltsDiffer() async throws {
        let store = InMemoryCredentialStore()
        let service = StubAuthenticationService(store: store)
        _ = try await service.register(email: "a@example.com", password: "correct-horse", name: "A")
        let first = try #require(await store.emailRecord(for: "a@example.com"))
        _ = try await service.register(email: "b@example.com", password: "correct-horse", name: "B")
        let second = try #require(await store.emailRecord(for: "b@example.com"))

        #expect(first.passwordHash != second.passwordHash)
    }

    // MARK: - Apple

    /// Apple sends the name once, on first authorisation, and never again. Losing it
    /// would mean greeting a returning traveller by nothing at all.
    @Test("Apple's name is remembered across sign-ins")
    func appleNameSurvives() async throws {
        let service = service()
        let first = try await service.signIn(withApple: AppleCredential(
            userIdentifier: "001.abc",
            fullName: "Sanya Mehta",
            email: "relay@privaterelay.appleid.com",
            identityToken: nil))
        #expect(first.displayName == "Sanya Mehta")

        // The second time Apple sends no name at all.
        let second = try await service.signIn(withApple: AppleCredential(
            userIdentifier: "001.abc", fullName: nil, email: nil, identityToken: nil))

        #expect(second.id == first.id)
        #expect(second.displayName == "Sanya Mehta")
        #expect(second.email == "relay@privaterelay.appleid.com")
    }

    @Test("Somebody who hid their name is greeted without one, not nagged")
    func appleWithoutName() async throws {
        let account = try await service().signIn(withApple: AppleCredential(
            userIdentifier: "001.xyz", fullName: nil, email: nil, identityToken: nil))
        #expect(account.displayName.isEmpty)
        #expect(account.greetingName.isEmpty)
    }

    // MARK: - Session

    @Test("A session survives, and signing out ends it")
    func sessionLifecycle() async throws {
        let store = InMemoryCredentialStore()
        let service = StubAuthenticationService(store: store)
        _ = try await service.register(email: "sanya@example.com", password: "correct-horse", name: "Sanya")

        #expect(await service.restoreSession()?.email == "sanya@example.com")
        await service.signOut()
        #expect(await service.restoreSession() == nil)
    }

    /// Deliberately does not assert on `AppSecrets`: a test that read ambient
    /// configuration printed a real credential into its own failure output.
    @Test("Google reports itself unconfigured rather than failing on tap")
    func googleWithoutClientID() async {
        let service = StubAuthenticationService(store: InMemoryCredentialStore(),
                                                googleClientID: nil)
        await #expect(throws: AuthenticationError.providerNotConfigured(.google)) {
            try await service.signInWithGoogle(presenting: NullContext())
        }
    }

    @Test("A client id reverses into the redirect scheme Google expects")
    func redirectScheme() {
        // Spelled out rather than exercised through AppSecrets, which reads a bundle.
        let clientID = "123-abc.apps.googleusercontent.com"
        let reversed = clientID.split(separator: ".").reversed().joined(separator: ".")
        #expect(reversed == "com.googleusercontent.apps.123-abc")
    }

    @Test("A Google id token's claims are read without trusting them")
    func idTokenClaims() throws {
        // header.payload.signature — only the payload is read, and the signature is
        // deliberately not checked here. See the doc comment on `profile(fromIDToken:)`.
        let payload = #"{"sub":"1234","name":"Sanya Mehta","email":"sanya@example.com"}"#
        let encoded = Data(payload.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        let token = "header.\(encoded).signature"

        let profile = try GoogleOAuthFlow.profile(fromIDToken: token)
        #expect(profile.subject == "1234")
        #expect(profile.name == "Sanya Mehta")
        #expect(profile.email == "sanya@example.com")
    }

    @Test("A malformed token is refused rather than half-read")
    func malformedIDToken() {
        #expect(throws: AuthenticationError.unexpected) {
            try GoogleOAuthFlow.profile(fromIDToken: "not-a-token")
        }
    }
}

private struct NullContext: WebAuthenticationPresenting {}

/// The account the team signs in with while there is no backend.
@Suite("Demo account")
struct DemoAccountTests {

    private func service() -> StubAuthenticationService {
        StubAuthenticationService(store: InMemoryCredentialStore())
    }

    @Test("The documented demo credentials sign in")
    func demoSignsIn() async throws {
        let account = try await service().signIn(email: StubAuthenticationService.Demo.email,
                                                 password: StubAuthenticationService.Demo.password)
        #expect(account.email == "vihara-app@gmail.com")
        #expect(account.greetingName == "Vihara")
        #expect(account.provider == .email)
    }

    @Test("They are exactly the credentials the README hands out")
    func credentialsAreTheOnesDocumented() {
        #expect(StubAuthenticationService.Demo.email == "vihara-app@gmail.com")
        #expect(StubAuthenticationService.Demo.password == "vihara007")
    }

    /// Seeded through the real path, not special-cased at the call site — so a wrong
    /// password against the demo address is refused like any other.
    @Test("A wrong password against the demo address is still refused")
    func demoStillChecksThePassword() async {
        await #expect(throws: AuthenticationError.invalidCredentials) {
            try await service().signIn(email: "vihara-app@gmail.com", password: "vihara008")
        }
    }

    @Test("Seeding is idempotent and does not overwrite a changed password")
    func seedingDoesNotClobber() async throws {
        let store = InMemoryCredentialStore()
        let service = StubAuthenticationService(store: store)

        _ = try await service.signIn(email: StubAuthenticationService.Demo.email,
                                     password: StubAuthenticationService.Demo.password)
        let first = try #require(await store.emailRecord(for: "vihara-app@gmail.com"))

        // A second pass must leave the existing record alone.
        _ = await service.restoreSession()
        let second = try #require(await store.emailRecord(for: "vihara-app@gmail.com"))
        #expect(first.passwordHash == second.passwordHash)
    }

    @Test("The demo account is a session that restores like any other")
    func demoRestores() async throws {
        let store = InMemoryCredentialStore()
        let service = StubAuthenticationService(store: store)
        _ = try await service.signIn(email: StubAuthenticationService.Demo.email,
                                     password: StubAuthenticationService.Demo.password)

        #expect(await service.restoreSession()?.email == "vihara-app@gmail.com")
    }
}
