import Testing
@testable import Vihara

/// The SSE wire format, tested without a server.
@Suite("Server-sent event decoding")
struct ServerSentEventDecoderTests {

    /// Feeds every line and returns whatever was dispatched.
    private func decode(_ lines: [String]) -> [ServerSentEvent] {
        var decoder = ServerSentEventDecoder()
        return lines.compactMap { decoder.consume(line: $0) }
    }

    @Test("A blank line dispatches the accumulated event")
    func dispatchOnBlankLine() throws {
        let events = decode(["event: day", "data: {\"id\":\"1\"}", ""])

        let event = try #require(events.first)
        #expect(events.count == 1)
        #expect(event.event == "day")
        #expect(event.data == "{\"id\":\"1\"}")
    }

    @Test("Nothing is emitted until the blank line arrives")
    func noEarlyDispatch() {
        #expect(decode(["event: day", "data: {}"]).isEmpty)
    }

    @Test("Multiple data lines are joined with newlines")
    func multiLineData() throws {
        let events = decode(["data: {", "data: \"a\": 1", "data: }", ""])
        let event = try #require(events.first)

        #expect(event.data == "{\n\"a\": 1\n}")
    }

    @Test("Comment lines are keep-alives and produce nothing")
    func commentsAreIgnored() {
        #expect(decode([": ping", ""]).isEmpty)
    }

    @Test("An event with no data is not dispatched")
    func noDataNoEvent() {
        #expect(decode(["event: heartbeat", ""]).isEmpty)
    }

    @Test("Exactly one leading space after the colon is framing, not content")
    func leadingSpaceIsStripped() throws {
        let events = decode(["data:  padded", ""])
        let event = try #require(events.first)

        #expect(event.data == " padded")
    }

    @Test("Unknown fields are ignored rather than failing the stream")
    func unknownFieldsIgnored() throws {
        let events = decode(["retry: 3000", "id: 42", "data: ok", ""])

        let event = try #require(events.first)
        #expect(event.id == "42")
        #expect(event.data == "ok")
    }

    @Test("State does not leak between consecutive events")
    func stateResetsBetweenEvents() throws {
        var decoder = ServerSentEventDecoder()
        _ = decoder.consume(line: "event: day")
        _ = decoder.consume(line: "data: first")
        _ = decoder.consume(line: "")
        _ = decoder.consume(line: "data: second")
        // Hoisted out of `#require`: the macro evaluates its argument inside a
        // closure, which cannot call a mutating method on a local `var`.
        let dispatched = decoder.consume(line: "")
        let second = try #require(dispatched)

        // The second event must not inherit `day` from the first.
        #expect(second.event == nil)
        #expect(second.data == "second")
    }
}
