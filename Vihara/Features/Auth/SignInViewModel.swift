import Foundation

/// Signing in or registering.
///
/// One screen with two modes rather than two screens, because the difference between
/// them is one field and a verb — and a separate "register" screen is one more place
/// somebody bounces off before they have seen the product.
@MainActor
@Observable
final class SignInViewModel {

    enum Mode: CaseIterable {
        case signIn
        case register

        var titleKey: String { self == .signIn ? "auth.signIn.title" : "auth.register.title" }
        var submitKey: String { self == .signIn ? "auth.signIn.submit" : "auth.register.submit" }
        var switchKey: String { self == .signIn ? "auth.switch.toRegister" : "auth.switch.toSignIn" }
        /// The label on the segmented control, which is a noun rather than a verb.
        var tabKey: String { self == .signIn ? "auth.tab.signIn" : "auth.tab.register" }
    }

    private let service: any AuthenticationService
    private let onSignedIn: (UserAccount) -> Void

    var mode: Mode = .signIn
    var name = ""
    var email = ""
    var password = ""
    var confirmPassword = ""
    /// The eye toggle. Off by default, and never remembered between screens.
    var isPasswordVisible = false

    private(set) var isWorking = false
    private(set) var errorKey: String?

    /// Google needs a client id we may not have been given.
    let isGoogleConfigured = AppSecrets.googleOAuthClientID != nil

    /// Sign in with Apple needs the capability on the App ID *and* the entitlement
    /// wired into the target. Neither is on yet — see `Vihara/Vihara.entitlements`
    /// and the README — so the button is present but inert rather than failing on
    /// tap with error 1000.
    ///
    /// Flip this in the same change that turns the capability on; there is no
    /// runtime API that answers it honestly.
    let isAppleConfigured = false

    init(service: any AuthenticationService, onSignedIn: @escaping (UserAccount) -> Void) {
        self.service = service
        self.onSignedIn = onSignedIn

        #if DEBUG
        // Same seam as `-vihara-route`: opening on the registration form should not
        // require a tap, whether the thing doing the opening is a person iterating
        // on layout or a test asserting on it.
        //
        //     xcrun simctl launch booted com.vihara.app -vihara-auth-mode register
        if UserDefaults.standard.string(forKey: "vihara-auth-mode") == "register" {
            mode = .register
        }
        #endif
    }

    var canSubmit: Bool {
        guard !isWorking, email.contains("@"), password.count >= 8 else { return false }
        guard mode == .register else { return true }
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && password == confirmPassword
    }

    /// Set once the traveller has typed enough of a confirmation for a mismatch to
    /// be worth pointing out — flagging it on the first character would be nagging.
    var showsPasswordMismatch: Bool {
        mode == .register
            && !confirmPassword.isEmpty
            && confirmPassword.count >= password.count
            && password != confirmPassword
    }

    // MARK: - Per-field state
    //
    // The card shows a tick beside a row that is settled and a strength bar beside
    // the password, so each row answers for itself rather than the whole form
    // failing at the button.

    var isEmailSettled: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let at = trimmed.firstIndex(of: "@") else { return false }
        let domain = trimmed[trimmed.index(after: at)...]
        return at != trimmed.startIndex && domain.contains(".") && !domain.hasSuffix(".")
    }

    var isNameSettled: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isConfirmSettled: Bool {
        !confirmPassword.isEmpty && confirmPassword == password
    }

    /// How far along the password is, from nought to three.
    ///
    /// Length, then variety. Deliberately not a character-class policy — those
    /// produce worse passwords — so this reports progress rather than gatekeeping;
    /// the only hard rule is the eight-character floor in ``canSubmit``.
    var passwordStrength: Int {
        guard !password.isEmpty else { return 0 }
        var score = 0
        if password.count >= 8 { score += 1 }
        if password.count >= 12 { score += 1 }
        let classes = [
            password.contains(where: \.isLowercase),
            password.contains(where: \.isUppercase),
            password.contains(where: \.isNumber),
            password.contains { !$0.isLetter && !$0.isNumber },
        ].filter { $0 }.count
        if classes >= 3 { score += 1 }
        return min(score, 3)
    }

    /// The line under the list. Says what is left, or that nothing is.
    var helperKey: String? {
        guard mode == .register else { return nil }
        if showsPasswordMismatch { return "auth.error.mismatch" }
        if password.isEmpty { return nil }
        if password.count < 8 { return "auth.helper.tooShort" }
        return canSubmit ? "auth.helper.ready" : "auth.helper.almost"
    }

    /// Whether the helper line is a problem or an encouragement.
    var helperIsWarning: Bool {
        showsPasswordMismatch || (!password.isEmpty && password.count < 8)
    }

    func toggleMode() {
        mode = mode == .signIn ? .register : .signIn
        // The confirmation belongs to registration; leaving it filled when switching
        // back would silently block a later sign-up with a stale value.
        confirmPassword = ""
        isPasswordVisible = false
        errorKey = nil
    }

    // MARK: - Routes in

    func submit() async {
        await run {
            switch self.mode {
            case .signIn:
                try await self.service.signIn(email: self.email, password: self.password)
            case .register:
                try await self.service.register(email: self.email,
                                                password: self.password,
                                                name: self.name)
            }
        }
    }

    func signInWithApple(_ credential: AppleCredential) async {
        await run { try await self.service.signIn(withApple: credential) }
    }

    func signInWithGoogle(presenting context: WebAuthenticationPresenting) async {
        await run { try await self.service.signInWithGoogle(presenting: context) }
    }

    /// Cancelling is not an error. A traveller who backed out of the Apple sheet does
    /// not need a red line telling them so.
    func cancelled() {
        isWorking = false
        errorKey = nil
    }

    /// Reports a failure raised outside `run` — the Apple sheet returns its errors to
    /// the view, not to this model.
    func failed(_ error: AuthenticationError) {
        isWorking = false
        errorKey = Self.messageKey(for: error)
    }

    private func run(_ work: @escaping () async throws -> UserAccount) async {
        isWorking = true
        errorKey = nil
        defer { isWorking = false }

        do {
            onSignedIn(try await work())
        } catch let error as AuthenticationError {
            guard error != .cancelled else { return }
            errorKey = Self.messageKey(for: error)
        } catch {
            errorKey = "auth.error.unexpected"
        }
    }

    private static func messageKey(for error: AuthenticationError) -> String {
        switch error {
        case .cancelled:               "auth.error.unexpected"
        case .providerNotConfigured:   "auth.error.notConfigured"
        case .invalidCredentials:      "auth.error.invalid"
        case .emailAlreadyRegistered:  "auth.error.taken"
        case .weakPassword:            "auth.error.weakPassword"
        case .network:                 "auth.error.network"
        case .unexpected:              "auth.error.unexpected"
        }
    }
}
