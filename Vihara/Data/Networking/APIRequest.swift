import Foundation

/// Where the backend lives, and who we are talking to it as.
struct APIConfiguration: Sendable {
    let baseURL: URL
    /// Supplies the bearer token. A closure rather than a stored string so the client
    /// picks up a refreshed token without being rebuilt.
    let accessToken: @Sendable () async -> String?

    /// A backend running on the developer's own machine.
    ///
    /// `#if DEBUG` because App Transport Security blocks cleartext HTTP in a release
    /// build, and a release build reaching for this would fail at the first request
    /// with an error that looks like a backend problem and is not one. Shipping
    /// against a real server means ``init(baseURL:accessToken:)`` with an `https`
    /// URL; there is deliberately no ATS exception for this to lean on.
    #if DEBUG
    static func localhost(port: Int = 8080) -> APIConfiguration {
        APIConfiguration(baseURL: URL(string: "http://localhost:\(port)")!,
                         accessToken: { nil })
    }
    #endif
}

/// A request in the app's own terms. Endpoints are described, not constructed, so
/// the `URLRequest` is built in exactly one place.
struct APIRequest: Sendable {
    let method: Method
    let path: String
    let query: [String: String]
    let body: Data?
    /// Makes a repeated POST safe to retry — required for export, where a retry that
    /// is not deduplicated costs the traveller money (PRD 4.2).
    let idempotencyKey: String?

    init(_ method: Method,
         _ path: String,
         query: [String: String] = [:],
         body: Data? = nil,
         idempotencyKey: String? = nil) {
        self.method = method
        self.path = path
        self.query = query
        self.body = body
        self.idempotencyKey = idempotencyKey
    }

    enum Method: String, Sendable {
        case get = "GET"
        case post = "POST"
        case patch = "PATCH"
        case delete = "DELETE"
    }
}
