import Foundation
import AuthenticationServices

/// Google sign-in without the Google SDK.
///
/// Authorization Code + PKCE through `ASWebAuthenticationSession`, which is the flow
/// Google documents for native apps and the one their SDK performs underneath. Doing
/// it directly keeps the promise on the front of the README — no packages, no
/// CocoaPods, no SPM graph — and costs about eighty lines.
///
/// PKCE rather than a client secret: a secret shipped inside an app is not a secret,
/// and Google's iOS client type does not issue one.
///
/// **Needs `GoogleOAuthClientID` in `Secrets.plist`**, and the reversed id listed
/// under `CFBundleURLTypes` — otherwise the browser has nowhere to hand the code back.
struct GoogleOAuthFlow: Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// The bit of the profile worth keeping.
    struct Profile: Hashable, Sendable {
        /// Google's stable user id (`sub`).
        let subject: String
        let name: String?
        let email: String?
    }

    @MainActor
    func authenticate(presenting context: WebAuthenticationPresenting) async throws -> Profile {
        guard let clientID = AppSecrets.googleOAuthClientID,
              let scheme = AppSecrets.googleRedirectScheme
        else { throw AuthenticationError.providerNotConfigured(.google) }

        let verifier = Self.randomVerifier()
        let redirectURI = "\(scheme):/oauth2redirect"

        let code = try await authorizationCode(clientID: clientID,
                                               redirectURI: redirectURI,
                                               verifier: verifier,
                                               scheme: scheme,
                                               context: context)
        let idToken = try await exchange(code: code,
                                         clientID: clientID,
                                         redirectURI: redirectURI,
                                         verifier: verifier)
        return try Self.profile(fromIDToken: idToken)
    }

    // MARK: - Step 1 · the browser

    @MainActor
    private func authorizationCode(clientID: String,
                                   redirectURI: String,
                                   verifier: String,
                                   scheme: String,
                                   context: WebAuthenticationPresenting) async throws -> String {
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            // Nothing beyond identity. Vihara has no reason to read anybody's mail.
            URLQueryItem(name: "scope", value: "openid email profile"),
            URLQueryItem(name: "code_challenge", value: CryptoHash.pkceChallenge(for: verifier)),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]
        guard let url = components.url else { throw AuthenticationError.unexpected }

        let anchor = (context as? PresentationAnchorProviding)?.anchor

        return try await withCheckedThrowingContinuation { continuation in
            let webSession = ASWebAuthenticationSession(url: url, callbackURLScheme: scheme) { callback, error in
                if let error = error as? ASWebAuthenticationSessionError,
                   error.code == .canceledLogin {
                    continuation.resume(throwing: AuthenticationError.cancelled)
                    return
                }
                guard error == nil,
                      let callback,
                      let code = URLComponents(url: callback, resolvingAgainstBaseURL: false)?
                          .queryItems?.first(where: { $0.name == "code" })?.value
                else {
                    continuation.resume(throwing: AuthenticationError.unexpected)
                    return
                }
                continuation.resume(returning: code)
            }
            // Ephemeral: the traveller signs into Google, not into Safari. Leaving a
            // session cookie behind on a shared device would be somebody else's
            // problem tomorrow.
            webSession.prefersEphemeralWebBrowserSession = true
            webSession.presentationContextProvider = anchor
            if !webSession.start() {
                continuation.resume(throwing: AuthenticationError.unexpected)
            }
        }
    }

    // MARK: - Step 2 · the token

    private func exchange(code: String,
                          clientID: String,
                          redirectURI: String,
                          verifier: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var body = URLComponents()
        body.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "code_verifier", value: verifier),
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
        ]
        request.httpBody = body.query?.data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AuthenticationError.network
        }
        guard let token = try? JSONDecoder().decode(TokenResponse.self, from: data).id_token else {
            throw AuthenticationError.unexpected
        }
        return token
    }

    private struct TokenResponse: Decodable {
        let id_token: String?
    }

    // MARK: - Step 3 · the claims

    /// Reads the id token's payload **without verifying its signature.**
    ///
    /// That is not an oversight and it is not sufficient: verification belongs on the
    /// server, against Google's public keys, once there is a server. What the client
    /// gets from this is a name to greet somebody by. Nothing is authorised on the
    /// strength of it, because nothing here can be.
    static func profile(fromIDToken token: String) throws -> Profile {
        let segments = token.split(separator: ".")
        guard segments.count >= 2 else { throw AuthenticationError.unexpected }

        var base64 = String(segments[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)

        guard let data = Data(base64Encoded: base64),
              let claims = try? JSONDecoder().decode(Claims.self, from: data)
        else { throw AuthenticationError.unexpected }

        return Profile(subject: claims.sub, name: claims.name, email: claims.email)
    }

    private struct Claims: Decodable {
        let sub: String
        let name: String?
        let email: String?
    }

    /// 64 URL-safe characters, well inside RFC 7636's 43–128.
    private static func randomVerifier() -> String {
        let allowed = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return String((0..<64).map { _ in allowed.randomElement()! })
    }
}

/// Supplies the window the web sheet hangs off.
///
/// The view conforms to this and passes itself in, which keeps `UIWindow` out of both
/// the domain protocol and this flow's signature.
protocol PresentationAnchorProviding {
    var anchor: ASWebAuthenticationPresentationContextProviding { get }
}
