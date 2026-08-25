import Foundation

/// The app's one door to the network.
///
/// Feature and domain code never see this type. Repositories use it, map what comes
/// back into domain models, and translate failures into ``DomainError`` — so a status
/// code or a `URLError` never reaches a view.
protocol HTTPClient: Sendable {
    func send<Response: Decodable>(_ request: APIRequest, expecting: Response.Type) async throws -> Response
    func stream(_ request: APIRequest) -> AsyncThrowingStream<ServerSentEvent, any Error>
}

struct URLSessionHTTPClient: HTTPClient {
    private let configuration: APIConfiguration
    private let session: URLSession
    private let decoder: JSONDecoder

    init(configuration: APIConfiguration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder.dateDecodingStrategy = .iso8601
    }

    func send<Response: Decodable>(_ request: APIRequest,
                                   expecting: Response.Type) async throws -> Response {
        let urlRequest = await makeURLRequest(request)
        let (data, response) = try await perform(urlRequest)
        try Self.validate(response, data: data)
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw DomainError.unexpectedResponse
        }
    }

    func stream(_ request: APIRequest) -> AsyncThrowingStream<ServerSentEvent, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let urlRequest = await makeURLRequest(request)
                    let (bytes, response) = try await session.bytes(for: urlRequest)
                    try Self.validate(response, data: nil)

                    var parser = ServerSentEventDecoder()
                    for try await line in bytes.lines {
                        if let event = parser.consume(line: line) {
                            continuation.yield(event)
                        }
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch let error as DomainError {
                    continuation.finish(throwing: error)
                } catch {
                    continuation.finish(throwing: Self.translate(error))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Plumbing

    private func makeURLRequest(_ request: APIRequest) async -> URLRequest {
        var components = URLComponents(
            url: configuration.baseURL.appendingPathComponent(request.path),
            resolvingAgainstBaseURL: false
        )
        if !request.query.isEmpty {
            components?.queryItems = request.query
                .sorted { $0.key < $1.key }
                .map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        var urlRequest = URLRequest(url: components?.url ?? configuration.baseURL)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body
        if request.body != nil {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let key = request.idempotencyKey {
            urlRequest.setValue(key, forHTTPHeaderField: "Idempotency-Key")
        }
        if let token = await configuration.accessToken() {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return urlRequest
    }

    private func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw Self.translate(error)
        }
    }

    private static func validate(_ response: URLResponse, data: Data?) throws {
        guard let http = response as? HTTPURLResponse else { throw DomainError.unexpectedResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw DomainError.server(message: ErrorEnvelope.message(from: data)
                                     ?? "HTTP \(http.statusCode)")
        }
    }

    private static func translate(_ error: any Error) -> DomainError {
        guard let urlError = error as? URLError else { return .unexpectedResponse }
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotConnectToHost:
            return .connectionFailed
        default:
            return .server(message: urlError.localizedDescription)
        }
    }
}

/// The backend's error shape, so a server-authored message reaches the traveller
/// instead of "HTTP 409".
private struct ErrorEnvelope: Decodable {
    let message: String

    static func message(from data: Data?) -> String? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(ErrorEnvelope.self, from: data).message
    }
}
