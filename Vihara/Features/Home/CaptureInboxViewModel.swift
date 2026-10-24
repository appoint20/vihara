import Foundation

/// What the share extension left behind, turned into places (COMPETITION.md wedge 3).
///
/// The split with the extension is deliberate and lives here: the extension captures
/// a link and whatever text came with it, and **this** does the expensive half —
/// fetching a caption, matching it against the vocabulary, deciding what to offer.
/// None of that could run inside an app extension's memory budget, and keeping it in
/// the app means the matching can improve without shipping a new extension.
@MainActor
@Observable
final class CaptureInboxViewModel {

    /// One shared post and the places found in it.
    struct Resolved: Identifiable, Sendable {
        let capture: SharedCapture
        let mentions: [PlaceMention]
        /// The text the mentions were found in, caption included. Shown so the
        /// traveller can see *why* we think this post was about Bologna.
        let text: String

        var id: UUID { capture.id }
        /// A post we could find nothing in. Kept and shown rather than dropped —
        /// see ``CaptureInboxViewModel``.
        var isUnresolved: Bool { mentions.isEmpty }
    }

    private let inbox: SharedInbox
    private let captions: any CaptionResolving
    private let resolver: ResolveCapture
    private let placeSearch: any PlaceSearching

    private(set) var items: [Resolved] = []
    private(set) var isLoading = false

    init(inbox: SharedInbox,
         captions: any CaptionResolving,
         vocabulary: PlaceVocabulary,
         placeSearch: any PlaceSearching) {
        self.inbox = inbox
        self.captions = captions
        self.resolver = ResolveCapture(vocabulary: vocabulary)
        self.placeSearch = placeSearch
    }

    var hasCaptures: Bool { !items.isEmpty }
    var count: Int { items.count }

    /// Reads the inbox and resolves everything in it, newest first.
    ///
    /// Captures that resolve to nothing are **kept**. A post whose caption named no
    /// city is the normal case for Instagram, whose oEmbed has needed a token since
    /// 2020 — silently dropping it would look like the share had failed, when what
    /// actually happened is that the link carried no text to read.
    func load() async {
        isLoading = true
        defer { isLoading = false }

        let captures = inbox.captures()
        guard !captures.isEmpty else {
            items = []
            return
        }

        var resolved: [Resolved] = []
        await withTaskGroup(of: Resolved.self) { group in
            for capture in captures {
                group.addTask { [resolver, captions] in
                    var text = capture.text
                    // Only reach for the network when the share itself said nothing
                    // useful. Most captures arrive with their caption attached.
                    if resolver.mentions(in: text).isEmpty, let url = capture.url,
                       let caption = await captions.caption(for: url) {
                        text = text.isEmpty ? caption : "\(text)\n\(caption)"
                    }
                    return Resolved(capture: capture,
                                    mentions: resolver.mentions(in: text),
                                    text: text)
                }
            }
            for await item in group { resolved.append(item) }
        }

        items = resolved.sorted { $0.capture.capturedAt > $1.capture.capturedAt }
    }

    /// Turns a mention into the suggestion the route expects.
    ///
    /// Goes back through ``PlaceSearching`` rather than building a `PlaceSuggestion`
    /// here, so a place added from a Reel is identical to one typed into the search
    /// field — same id, same region line, same honest `isPlannable`.
    func suggestion(for mention: PlaceMention) async -> PlaceSuggestion? {
        let results = (try? await placeSearch.suggestions(for: mention.name)) ?? []
        return results.first { $0.name == mention.name } ?? results.first
    }

    func dismiss(_ id: UUID) {
        inbox.remove(id)
        items.removeAll { $0.id == id }
    }

    func clearAll() {
        inbox.removeAll()
        items = []
    }
}
