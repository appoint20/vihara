import Foundation

/// The production generator: start a job, then follow the stream (PRD 6.4).
///
/// Two calls rather than one long request, because the plan outlives the connection.
/// If the traveller backgrounds the app mid-generation, the job keeps composing and
/// the stream can be rejoined.
struct RemoteTripGenerator: TripGenerating {
    private let client: any HTTPClient
    private let mapper: TripStreamMapper

    init(client: any HTTPClient, mapper: TripStreamMapper = TripStreamMapper()) {
        self.client = client
        self.mapper = mapper
    }

    func generate(from brief: TripBrief) -> AsyncThrowingStream<TripGenerationEvent, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let accepted = try await client.send(
                        APIRequest(.post, "/v1/trips", body: try JSONEncoder().encode(BriefDTO(brief))),
                        expecting: TripStreamDTO.Accepted.self
                    )
                    let tripID = Identifier<Trip>(accepted.tripId)
                    continuation.yield(.accepted(tripID: tripID, expectedDays: accepted.expectedDays))

                    let decoder = JSONDecoder()
                    for try await event in client.stream(APIRequest(.get, "/v1/trips/\(tripID)/stream")) {
                        switch event.event {
                        case "day":
                            guard let payload = event.data.data(using: .utf8) else {
                                throw DomainError.unexpectedResponse
                            }
                            let dto = try decoder.decode(TripStreamDTO.Day.self, from: payload)
                            continuation.yield(.dayReady(try mapper.day(from: dto)))
                        case "done":
                            continuation.yield(.completed)
                        case "error":
                            throw DomainError.server(message: event.data)
                        default:
                            break   // Keep-alives and fields we do not consume yet.
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

/// The brief on the wire. Separate from ``TripBrief`` for the same reason the
/// response DTOs are separate: the domain does not owe the transport a shape.
private struct BriefDTO: Encodable {
    let destination: String
    let startDate: String
    let nights: Int
    let travelStyle: String
    let pace: String
    let budget: String
    let diet: String
    let sourceText: String?

    init(_ brief: TripBrief) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        destination = brief.destination
        startDate = formatter.string(from: brief.startDate)
        nights = brief.nights
        travelStyle = brief.travelStyle.rawValue
        pace = brief.pace.rawValue
        budget = brief.budget.rawValue
        diet = brief.diet.rawValue
        sourceText = brief.sourceText
    }
}
