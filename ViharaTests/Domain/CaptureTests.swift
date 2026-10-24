import Testing
import Foundation
@testable import Vihara

@Suite("Reading places out of a caption")
struct ResolveCaptureTests {

    private let vocabulary = PlaceVocabulary(entries: [
        .init(name: "Bologna", destinationID: Identifier("bologna")),
        .init(name: "Rom", terms: ["Roma", "Rome"]),
        .init(name: "Florenz", terms: ["Firenze", "Florence"]),
        .init(name: "San Sebastián", terms: ["Donostia"]),
        .init(name: "München", terms: ["Munich"]),
    ])

    private var resolver: ResolveCapture { ResolveCapture(vocabulary: vocabulary) }

    private func names(_ text: String) -> [String] {
        resolver.mentions(in: text).map(\.name)
    }

    /// Hashtags are how captions name places, so `#` has to be punctuation.
    @Test("A hashtag names a place")
    func hashtags() {
        #expect(names("3 Tage in #bologna 🍝") == ["Bologna"])
        #expect(names("#Firenze #food") == ["Florenz"])
    }

    @Test("Punctuation around a name does not hide it")
    func punctuation() {
        #expect(names("Bologna, Italien!") == ["Bologna"])
        #expect(names("(Rom)") == ["Rom"])
    }

    /// A substring search finds "Rom" inside "Romantik", and a caption about a
    /// romantic weekend is not a caption about Rome.
    @Test("A name inside a longer word is not a match")
    func wordBoundaries() {
        #expect(names("Ein romantisches Wochenende").isEmpty)
        #expect(names("Romantik pur").isEmpty)
        #expect(names("Roman über Liebe").isEmpty)
    }

    @Test("Multi-word names match as a run")
    func multiWordNames() {
        #expect(names("Pintxos in San Sebastián") == ["San Sebastián"])
        // "San" alone is not San Sebastián.
        #expect(names("San Marco").isEmpty)
    }

    @Test("Diacritics and case are optional, as in the search field")
    func folding() {
        #expect(names("muenchen").isEmpty, "a transliteration is not a fold")
        #expect(names("munchen") == ["München"])
        #expect(names("MÜNCHEN") == ["München"])
        #expect(names("san sebastian") == ["San Sebastián"])
    }

    @Test("The endonym and the English name both resolve")
    func aliases() {
        #expect(names("Firenze") == ["Florenz"])
        #expect(names("Florence") == ["Florenz"])
        #expect(names("Roma") == ["Rom"])
    }

    /// A mention we can act on is worth more than one we can only acknowledge — the
    /// same ordering the search field keeps.
    @Test("Somewhere we can plan comes first")
    func plannableFirst() {
        let mentions = resolver.mentions(in: "Von Rom nach Bologna")
        #expect(mentions.first?.name == "Bologna")
        #expect(mentions.first?.isPlannable == true)
        #expect(mentions.map(\.name) == ["Bologna", "Rom"])
    }

    @Test("A place named twice is reported once")
    func noDuplicates() {
        #expect(names("Bologna! Bologna! #bologna") == ["Bologna"])
    }

    @Test("A caption naming nowhere resolves to nothing")
    func nothingFound() {
        #expect(names("this little place near the market was unreal").isEmpty)
        #expect(names("").isEmpty)
        #expect(names("   ").isEmpty)
    }

    /// The honest ceiling of the whole feature: a bare link names no places, which
    /// is exactly why ``CaptionResolving`` exists.
    @Test("A link on its own yields nothing")
    func bareLinkYieldsNothing() {
        #expect(names("https://www.tiktok.com/@someone/video/123456").isEmpty)
    }

    @Test("The matched spelling is reported alongside the name")
    func reportsWhatMatched() throws {
        let mention = try #require(resolver.mentions(in: "Ein Tag in Firenze").first)
        #expect(mention.name == "Florenz")
        #expect(mention.matched == "Firenze")
    }

    @Test("Tokenising splits on everything that is not a letter or digit")
    func tokenising() {
        #expect(ResolveCapture.tokenise("#bologna, Italien!") == ["bologna", "italien"])
        #expect(ResolveCapture.tokenise("3 Tage") == ["3", "tage"])
        #expect(ResolveCapture.tokenise("🍝🍝") == [])
    }

    @Test("A run is found only when the words are consecutive")
    func runMatching() {
        #expect(ResolveCapture.contains(["a", "b", "c"], ["b", "c"]))
        #expect(!ResolveCapture.contains(["a", "b", "c"], ["a", "c"]))
        #expect(!ResolveCapture.contains(["a"], ["a", "b"]))
        #expect(!ResolveCapture.contains(["a", "b"], []))
    }
}

@Suite("What the share extension hands over")
struct SharedCaptureTests {

    @Test("The source is guessed from the host")
    func sourceDetection() {
        func source(_ url: String) -> SharedCapture.Source {
            SharedCapture(url: URL(string: url), text: "").source
        }
        #expect(source("https://www.tiktok.com/@a/video/1") == .tiktok)
        #expect(source("https://vm.tiktok.com/abc") == .tiktok)
        #expect(source("https://www.instagram.com/reel/abc") == .instagram)
        #expect(source("https://youtu.be/abc") == .youtube)
        #expect(source("https://example.com") == .unknown)
        #expect(SharedCapture(url: nil, text: "x").source == .unknown)
    }

    @Test("A capture with neither link nor text is empty")
    func emptiness() {
        #expect(SharedCapture(url: nil, text: "").isEmpty)
        #expect(SharedCapture(url: nil, text: "   \n ").isEmpty)
        #expect(!SharedCapture(url: nil, text: "Bologna").isEmpty)
        #expect(!SharedCapture(url: URL(string: "https://a.com"), text: "").isEmpty)
    }

    @Test("Only tiktok.com is treated as TikTok")
    func tikTokHosts() {
        #expect(TikTokOEmbedCaptions.isTikTok(URL(string: "https://www.tiktok.com/x")!))
        #expect(TikTokOEmbedCaptions.isTikTok(URL(string: "https://vm.tiktok.com/x")!))
        // A lookalike host must not be handed a URL to resolve.
        #expect(!TikTokOEmbedCaptions.isTikTok(URL(string: "https://tiktok.com.evil.test/x")!))
        #expect(!TikTokOEmbedCaptions.isTikTok(URL(string: "https://instagram.com/x")!))
    }
}

@Suite("The share inbox")
struct SharedInboxTests {

    private func temporaryInbox() throws -> (SharedInbox, URL) {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (SharedInbox(directory: directory), directory)
    }

    @Test("A capture survives the round trip")
    func roundTrip() throws {
        let (inbox, directory) = try temporaryInbox()
        defer { try? FileManager.default.removeItem(at: directory) }

        let capture = SharedCapture(url: URL(string: "https://www.tiktok.com/x"),
                                    text: "3 Tage in Bologna")
        #expect(inbox.append(capture))

        let read = inbox.captures()
        #expect(read.count == 1)
        #expect(read.first?.text == "3 Tage in Bologna")
        #expect(read.first?.id == capture.id)
    }

    @Test("An empty capture is refused rather than stored")
    func refusesEmpty() throws {
        let (inbox, directory) = try temporaryInbox()
        defer { try? FileManager.default.removeItem(at: directory) }

        #expect(!inbox.append(SharedCapture(url: nil, text: "  ")))
        #expect(inbox.captures().isEmpty)
    }

    @Test("Captures accumulate and can be removed one at a time")
    func removal() throws {
        let (inbox, directory) = try temporaryInbox()
        defer { try? FileManager.default.removeItem(at: directory) }

        let first = SharedCapture(url: nil, text: "Bologna")
        let second = SharedCapture(url: nil, text: "Rom")
        inbox.append(first)
        inbox.append(second)
        #expect(inbox.captures().count == 2)

        inbox.remove(first.id)
        #expect(inbox.captures().map(\.text) == ["Rom"])

        inbox.removeAll()
        #expect(inbox.captures().isEmpty)
    }

    /// Somebody who shares forty Reels and opens the app once wants the recent ones,
    /// not an unbounded file.
    @Test("The inbox keeps the most recent captures and drops the rest")
    func limit() throws {
        let (inbox, directory) = try temporaryInbox()
        defer { try? FileManager.default.removeItem(at: directory) }

        for index in 0..<(SharedInbox.limit + 10) {
            inbox.append(SharedCapture(url: nil, text: "post \(index)"))
        }

        let kept = inbox.captures()
        #expect(kept.count == SharedInbox.limit)
        #expect(kept.last?.text == "post \(SharedInbox.limit + 9)")
    }

    @Test("Reading an inbox that was never written is empty, not an error")
    func emptyInbox() throws {
        let (inbox, directory) = try temporaryInbox()
        defer { try? FileManager.default.removeItem(at: directory) }
        #expect(inbox.captures().isEmpty)
    }

    /// Without the App Group the container is nil, and a capture that appears to
    /// save but does not is the worst outcome available.
    @Test("An inbox with no container reports that it is unavailable")
    func unavailableContainer() {
        let inbox = SharedInbox(appGroupIdentifier: "group.does.not.exist.anywhere")
        #expect(!inbox.isAvailable)
        #expect(!inbox.append(SharedCapture(url: nil, text: "Bologna")))
        #expect(inbox.captures().isEmpty)
    }
}

@Suite("The caption vocabulary")
struct CatalogueVocabularyTests {

    @Test("Curated destinations carry an id, so they can be planned")
    func curatedAreplannable() throws {
        let vocabulary = CatalogueVocabulary.build()
        let bologna = try #require(vocabulary.entries.first { $0.name == "Bologna" })
        #expect(bologna.destinationID == Identifier("bologna"))
    }

    @Test("The corpus fills in everywhere else, without an id")
    func corpusIsNotPlannable() throws {
        let vocabulary = CatalogueVocabulary.build()
        let lisbon = try #require(vocabulary.entries.first { $0.name == "Lissabon" })
        #expect(lisbon.destinationID == nil)
        #expect(lisbon.terms.contains("Lisboa"))
    }

    /// A city in both lists must not appear twice, or a caption mentioning it would
    /// resolve to a duplicate — once plannable, once not.
    @Test("A curated city is not repeated from the corpus")
    func noDuplicateEntries() {
        let vocabulary = CatalogueVocabulary.build()
        let bolognas = vocabulary.entries.filter { $0.name == "Bologna" }
        #expect(bolognas.count == 1)
        #expect(bolognas.first?.destinationID != nil)
    }

    @Test("The vocabulary covers the whole corpus")
    func coversTheCorpus() {
        #expect(CatalogueVocabulary.build().entries.count >= 200)
    }

    /// End to end against the shipped data, not a fixture.
    @Test("A real caption resolves against the real vocabulary")
    func realCaptionResolves() {
        let resolver = ResolveCapture(vocabulary: CatalogueVocabulary.build())
        let mentions = resolver.mentions(in: "POV: 3 perfekte Tage in #Bologna 🍝 #italy #foodie")

        #expect(mentions.first?.name == "Bologna")
        #expect(mentions.first?.isPlannable == true)
    }
}
