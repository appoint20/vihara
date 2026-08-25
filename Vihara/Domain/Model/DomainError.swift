import Foundation

/// Everything the domain can fail with.
///
/// Feature code switches over this to choose wording; it never inspects an
/// `NSError`, a status code or a URL. Transport detail stops at the data layer.
enum DomainError: Error, Hashable, Sendable {
    /// The brief does not name a destination, or a length of stay.
    case incompleteBrief
    /// The free allowance for the calendar year is used up (PRD 4.2).
    case generationLimitReached(resetsOn: Date?)
    /// The plan could not be composed — usually too few validated candidates for a
    /// region we have not curated yet.
    case noValidatedCandidates(destination: String)
    /// The planning model is unavailable. The existing plan stays readable and
    /// editable; only reflow pauses (PRD 8, availability).
    case planningUnavailable
    /// Offline, or the request timed out.
    case connectionFailed
    /// Anything the server reported that the client has no specific handling for.
    case server(message: String)
    /// A bug on our side — a response we could not map.
    case unexpectedResponse
}
