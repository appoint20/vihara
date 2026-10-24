import Testing
import Foundation
@testable import Vihara

@Suite("The shared-posts inbox")
@MainActor
struct CaptureInboxTests {

    private let vocabulary = PlaceVocabulary(entries: [
        .init(name: "Bologna", destinationID: Identifier("bologna")),
        .init(name: "Lissabon", terms: ["Lisboa", "Lisbon"]),
    ])

    private func temporaryInbox() throws -> (SharedInbox, URL) {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (SharedInbox(directory: directory), directory)
    }

    private func model(_ inbox: SharedInbox,
                       captions: any CaptionResolving = NoCaptions()) -> CaptureInboxViewModel {
        CaptureInboxViewModel(inbox: inbox,
                              captions: captions,
                              vocabulary: vocabulary,
                              placeSearch: FakeSearch())
    }

    @Test("A capture whose text names a city resolves without touching the network")
    func resolvesFromSharedText() async throws {
        let (inbox, directory) = try temporaryInbox()
        defer { try? FileManager.default.removeItem(at: directory) }
        inbox.append(SharedCapture(url: URL(string: "https://www.tiktok.com/x"),
                                   text: "3 Tage in #Bologna"))

        let captions = RecordingCaptions(caption: "should not be needed")
        let model = model(inbox, captions: captions)
        await model.load()

        #expect(model.count == 1)
        #expect(model.items.first?.mentions.map(\.name) == ["Bologna"])
        // The caption fetch is a fallback, not a step. Most captures arrive with
        // their text attached and must not cost a request.
        #expect(await captions.requestCount == 0)
    }

    @Test("A bare link falls back to fetching the caption")
    func fallsBackToTheCaption() async throws {
        let (inbox, directory) = try temporaryInbox()
        defer { try? FileManager.default.removeItem(at: directory) }
        inbox.append(SharedCapture(url: URL(string: "https://www.tiktok.com/x"), text: ""))

        let captions = RecordingCaptions(caption: "POV: ein Wochenende in Bologna")
        let model = model(inbox, captions: captions)
        await model.load()

        #expect(model.items.first?.mentions.map(\.name) == ["Bologna"])
        #expect(await captions.requestCount == 1)
        // The caption is kept, so the traveller can see why we said Bologna.
        #expect(model.items.first?.text.contains("Bologna") == true)
    }

    /// Instagram's oEmbed has needed a token since 2020, so this is the normal case
    /// there — and dropping it would look like the share itself had failed.
    @Test("A capture that resolves to nothing is kept, not discarded")
    func unresolvedCapturesAreKept() async throws {
        let (inbox, directory) = try temporaryInbox()
        defer { try? FileManager.default.removeItem(at: directory) }
        inbox.append(SharedCapture(url: URL(string: "https://www.instagram.com/reel/x"), text: ""))

        let model = model(inbox)
        await model.load()

        #expect(model.count == 1)
        #expect(model.items.first?.isUnresolved == true)
        #expect(model.items.first?.capture.source == .instagram)
    }

    @Test("Newest first")
    func ordering() async throws {
        let (inbox, directory) = try temporaryInbox()
        defer { try? FileManager.default.removeItem(at: directory) }
        inbox.append(SharedCapture(url: nil, text: "Bologna",
                                   capturedAt: Date(timeIntervalSince1970: 1_000)))
        inbox.append(SharedCapture(url: nil, text: "Lissabon",
                                   capturedAt: Date(timeIntervalSince1970: 2_000)))

        let model = model(inbox)
        await model.load()

        #expect(model.items.map { $0.mentions.first?.name } == ["Lissabon", "Bologna"])
    }

    @Test("Discarding one removes it from the file as well as the screen")
    func dismissPersists() async throws {
        let (inbox, directory) = try temporaryInbox()
        defer { try? FileManager.default.removeItem(at: directory) }
        let capture = SharedCapture(url: nil, text: "Bologna")
        inbox.append(capture)
        inbox.append(SharedCapture(url: nil, text: "Lissabon"))

        let model = model(inbox)
        await model.load()
        model.dismiss(capture.id)

        #expect(model.count == 1)
        #expect(inbox.captures().count == 1)
    }

    @Test("Clearing empties both")
    func clearAll() async throws {
        let (inbox, directory) = try temporaryInbox()
        defer { try? FileManager.default.removeItem(at: directory) }
        inbox.append(SharedCapture(url: nil, text: "Bologna"))

        let model = model(inbox)
        await model.load()
        model.clearAll()

        #expect(!model.hasCaptures)
        #expect(inbox.captures().isEmpty)
    }

    @Test("An empty inbox shows nothing and asks for nothing")
    func emptyInbox() async throws {
        let (inbox, directory) = try temporaryInbox()
        defer { try? FileManager.default.removeItem(at: directory) }

        let captions = RecordingCaptions(caption: nil)
        let model = model(inbox, captions: captions)
        await model.load()

        #expect(!model.hasCaptures)
        #expect(await captions.requestCount == 0)
    }

    /// A place added from a Reel must be identical to one typed into the search
    /// field — same id, same region line, same honest `isPlannable`.
    @Test("A mention becomes a suggestion through the ordinary search path")
    func mentionBecomesASuggestion() async throws {
        let (inbox, directory) = try temporaryInbox()
        defer { try? FileManager.default.removeItem(at: directory) }
        inbox.append(SharedCapture(url: nil, text: "Bologna"))

        let model = model(inbox)
        await model.load()
        let mention = try #require(model.items.first?.mentions.first)
        let suggestion = try #require(await model.suggestion(for: mention))

        #expect(suggestion.name == "Bologna")
        #expect(suggestion.isPlannable)
    }
}

private struct FakeSearch: PlaceSearching {
    func suggestions(for query: String) async throws -> [PlaceSuggestion] {
        guard query == "Bologna" else { return [] }
        return [PlaceSuggestion(id: "bologna",
                                name: "Bologna",
                                region: "Emilia-Romagna, Italien",
                                destinationID: Identifier("bologna"))]
    }
}

private actor RecordingCaptions: CaptionResolving {
    private let caption: String?
    private(set) var requestCount = 0

    init(caption: String?) { self.caption = caption }

    func caption(for url: URL) async -> String? {
        requestCount += 1
        return caption
    }
}
