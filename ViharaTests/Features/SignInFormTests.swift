import Testing
import Foundation
@testable import Vihara

/// The form's own rules — what the button will and will not let through.
@Suite("Sign-in form")
@MainActor
struct SignInFormTests {

    private func form() -> SignInViewModel {
        SignInViewModel(service: StubAuthenticationService(store: InMemoryCredentialStore()),
                        onSignedIn: { _ in })
    }

    // MARK: - Signing in

    @Test("Signing in needs an address and eight characters")
    func signInValidation() {
        let model = form()
        #expect(!model.canSubmit)

        model.email = "max@mustermann.de"
        #expect(!model.canSubmit)

        model.password = "short"
        #expect(!model.canSubmit)

        model.password = "long-enough"
        #expect(model.canSubmit)
    }

    @Test("Something that is not an address does not submit")
    func signInRejectsMalformedEmail() {
        let model = form()
        model.email = "max"
        model.password = "long-enough"
        #expect(!model.canSubmit)
    }

    // MARK: - Registering

    @Test("Registering also needs a name and a matching confirmation")
    func registerValidation() {
        let model = form()
        model.mode = .register
        model.email = "max@mustermann.de"
        model.password = "long-enough"

        // No name yet.
        #expect(!model.canSubmit)

        model.name = "Max Mustermann"
        // No confirmation yet.
        #expect(!model.canSubmit)

        model.confirmPassword = "long-enoug"
        #expect(!model.canSubmit)

        model.confirmPassword = "long-enough"
        #expect(model.canSubmit)
    }

    @Test("A name of only spaces is not a name")
    func blankNameIsRejected() {
        let model = form()
        model.mode = .register
        model.name = "   "
        model.email = "max@mustermann.de"
        model.password = "long-enough"
        model.confirmPassword = "long-enough"
        #expect(!model.canSubmit)
    }

    /// Flagging a mismatch on the first keystroke would be nagging — somebody
    /// halfway through typing has not made a mistake yet.
    @Test("A mismatch is only pointed out once it could be one")
    func mismatchIsPatient() {
        let model = form()
        model.mode = .register
        model.password = "long-enough"

        model.confirmPassword = ""
        #expect(!model.showsPasswordMismatch)

        model.confirmPassword = "long"
        #expect(!model.showsPasswordMismatch)

        model.confirmPassword = "long-enougH"
        #expect(model.showsPasswordMismatch)

        model.confirmPassword = "long-enough"
        #expect(!model.showsPasswordMismatch)
    }

    @Test("Signing in never shows a mismatch — it has no confirmation field")
    func noMismatchWhenSigningIn() {
        let model = form()
        model.password = "long-enough"
        model.confirmPassword = "something-else"
        #expect(!model.showsPasswordMismatch)
    }

    /// Switching modes must not leave a stale confirmation behind, or a later
    /// registration is blocked by a value the traveller cannot see.
    @Test("Switching modes clears the confirmation")
    func togglingClearsConfirmation() {
        let model = form()
        model.mode = .register
        model.confirmPassword = "stale"

        model.toggleMode()
        #expect(model.mode == .signIn)
        #expect(model.confirmPassword.isEmpty)
    }

    // MARK: - Providers

    /// Both are inert until they are configured, so neither can open a sheet that
    /// then fails.
    @Test("Neither provider is offered as working while unconfigured")
    func providersAreInert() {
        let model = form()
        #expect(!model.isAppleConfigured)
        #expect(!model.isGoogleConfigured)
    }
}
