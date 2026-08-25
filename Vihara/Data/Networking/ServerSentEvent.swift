import Foundation

/// One event from an SSE stream.
struct ServerSentEvent: Hashable, Sendable {
    var event: String?
    var id: String?
    var data: String
}

/// Incremental SSE parser.
///
/// Deliberately knows nothing about networking: it takes lines and hands back events.
/// That keeps the wire format — the part with the fiddly rules about comments,
/// multi-line `data` and blank-line dispatch — testable without a server, a socket or
/// a stubbed `URLProtocol`.
struct ServerSentEventDecoder: Sendable {
    private var event: String?
    private var id: String?
    private var dataLines: [String] = []

    init() {}

    /// Feeds one line. Returns an event when the line completes one.
    mutating func consume(line: String) -> ServerSentEvent? {
        // A blank line dispatches whatever has accumulated.
        guard !line.isEmpty else { return dispatch() }
        // Leading colon marks a comment; servers send these as keep-alives.
        guard !line.hasPrefix(":") else { return nil }

        let (field, value) = Self.split(line)
        switch field {
        case "event": event = value
        case "id":    id = value
        case "data":  dataLines.append(value)
        default:      break   // Unknown fields are ignored, per the SSE spec.
        }
        return nil
    }

    /// An event with no `data` field is not dispatched, per the spec.
    private mutating func dispatch() -> ServerSentEvent? {
        defer {
            event = nil
            id = nil
            dataLines.removeAll()
        }
        guard !dataLines.isEmpty else { return nil }
        return ServerSentEvent(event: event, id: id, data: dataLines.joined(separator: "\n"))
    }

    /// Splits `field: value`. A single leading space after the colon is part of the
    /// framing, not the value.
    private static func split(_ line: String) -> (field: String, value: String) {
        guard let colon = line.firstIndex(of: ":") else { return (line, "") }
        let field = String(line[line.startIndex..<colon])
        var value = String(line[line.index(after: colon)...])
        if value.hasPrefix(" ") { value.removeFirst() }
        return (field, value)
    }
}
