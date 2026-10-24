import AuthenticationServices
import UIKit

/// Raises the Sign in with Apple sheet from our own button.
///
/// `SignInWithAppleButton` cannot be square: it keeps its label at every size, so
/// forcing it into a 56pt box clips "Mit Apple anmelden" to "Apple anme…". Apple's
/// guidelines allow a logo-only button provided the mark keeps its shape and
/// contrast, so the button is drawn in ``AuthView`` and the sheet is raised here.
///
/// An `NSObject` because `ASAuthorizationController` still wants delegates. It holds
/// itself alive for the duration of the request — the controller does not retain its
/// delegate, and a sheet whose delegate has been deallocated simply never calls back.
@MainActor
final class AppleSignInController: NSObject {
    private var completion: ((Result<AppleCredential, any Error>) -> Void)?
    private var strongSelf: AppleSignInController?

    func requestCredential(completion: @escaping (Result<AppleCredential, any Error>) -> Void) {
        self.completion = completion
        self.strongSelf = self

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    private func finish(_ result: Result<AppleCredential, any Error>) {
        completion?(result)
        completion = nil
        strongSelf = nil
    }
}

extension AppleSignInController: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            finish(.failure(AuthenticationError.unexpected))
            return
        }
        // Apple sends the name once, on first authorisation, and never again.
        let name = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")

        finish(.success(AppleCredential(
            userIdentifier: credential.user,
            fullName: name.isEmpty ? nil : name,
            email: credential.email,
            identityToken: credential.identityToken.flatMap { String(data: $0, encoding: .utf8) }
        )))
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithError error: any Error) {
        finish(.failure(error))
    }
}

extension AppleSignInController: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
            ?? ASPresentationAnchor()
    }
}
