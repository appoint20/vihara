import Foundation

/// Produces a plan from a brief, one validated day at a time (F-02).
///
/// Streaming is in the signature rather than an implementation detail, because the
/// product rule depends on it: day one appears as soon as it validates and the rest
/// follow, so there is never a full-screen spinner (PRD 5.1, rule 7). A
/// `func generate(...) async throws -> Trip` would make that rule unimplementable.
protocol TripGenerating: Sendable {
    func generate(from brief: TripBrief) -> AsyncThrowingStream<TripGenerationEvent, any Error>
}

/// One frame of the generation stream. Mirrors `GET /v1/trips/:id/stream`.
enum TripGenerationEvent: Hashable, Sendable {
    /// The job was accepted. Carries the id to key exports on, and how many days to
    /// draw skeletons for.
    case accepted(tripID: Identifier<Trip>, expectedDays: Int)
    /// A day passed the validation gate and may be shown.
    case dayReady(TripDay)
    /// Every day is in. Nothing further will arrive.
    case completed
}

/// Turns the traveller's sentence into a structured brief (F-01, PRD 3.1).
///
/// Server-side in production — the intake model runs behind `POST /v1/trips` and the
/// key never reaches the device.
protocol TripBriefParsing: Sendable {
    /// Reads the sentence, and reports which slots it genuinely filled.
    ///
    /// The recognition half exists because the home screen shows it back live: chips
    /// land as the traveller types, and the ones still dashed are exactly what the
    /// interview will otherwise have to ask about. A parser that only returned a
    /// finished ``TripBrief`` could not tell "you said three nights" apart from "we
    /// assumed three nights".
    func recognise(_ sentence: String, relativeTo today: Date) async throws -> ParsedBrief
}

extension TripBriefParsing {
    /// Just the brief, for callers that do not care what was assumed.
    func parse(_ sentence: String, relativeTo today: Date) async throws -> TripBrief {
        try await recognise(sentence, relativeTo: today).brief
    }
}
