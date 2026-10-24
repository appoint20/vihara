import Foundation

/// Keys and client ids, read at runtime and never committed.
///
/// Three sources, in order: a bundled `Secrets.plist` (git-ignored, the normal way to
/// run this locally), then the generated `Info.plist` (how CI injects them), then the
/// environment (how you override one for an afternoon without editing a file).
///
/// **Nothing here has a default.** A missing key returns `nil` and the feature behind
/// it degrades to something honest — place search falls back to the curated
/// catalogue, and a sign-in button that cannot work says so instead of failing on
/// tap. Shipping a placeholder string would turn a build problem into a runtime
/// mystery.
///
/// To fill them in, copy `Vihara/Secrets.example.plist` to `Vihara/Secrets.plist`
/// and paste your values. The real file is git-ignored.
enum AppSecrets {

    /// Google Places API key, for searching real places (Places API, New).
    ///
    /// Restrict it to this app's bundle id in the Google Cloud console before it goes
    /// anywhere near a build somebody else can run — a key shipped inside an app is
    /// extractable, and an unrestricted Places key is somebody else's bill.
    static var googlePlacesAPIKey: String? { value(for: "GooglePlacesAPIKey") }

    /// OAuth client id of type **iOS** from the Google Cloud console.
    ///
    /// The redirect scheme is this id reversed, and it must also be listed under
    /// `CFBundleURLTypes` or the browser has nowhere to hand the code back to.
    static var googleOAuthClientID: String? { value(for: "GoogleOAuthClientID") }

    /// `com.googleusercontent.apps.1234-abcd` → the URL scheme Google redirects to.
    static var googleRedirectScheme: String? {
        guard let clientID = googleOAuthClientID else { return nil }
        return clientID.split(separator: ".").reversed().joined(separator: ".")
    }

    // MARK: - Lookup

    private static func value(for key: String) -> String? {
        let candidates = [
            secretsPlist?[key] as? String,
            Bundle.main.object(forInfoDictionaryKey: key) as? String,
            ProcessInfo.processInfo.environment[key],
        ]
        return candidates
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty && !$0.hasPrefix("PASTE_") }
    }

    private static let secretsPlist: [String: Any]? = {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data,
                                                                     format: nil)
        else { return nil }
        return plist as? [String: Any]
    }()
}
