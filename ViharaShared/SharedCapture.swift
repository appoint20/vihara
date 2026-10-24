import Foundation

/// Something the traveller shared into Vihara from another app.
///
/// **Compiled into both the app and the share extension**, which is why it lives in
/// `ViharaShared/` and depends on nothing but Foundation. The extension cannot see
/// `Vihara/Domain` — an app extension links its own binary — so this is the whole
/// contract between the two, and it is deliberately dumb: a URL, whatever text came
/// with it, and when.
///
/// It is **not** a domain type. The extension captures; the app resolves captures
/// into places against the catalogue it owns. Keeping the split here means the
/// resolution can get cleverer without ever shipping a new extension, and it keeps
/// the extension inside the memory budget an extension actually gets.
struct SharedCapture: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    /// The link that was shared. `nil` when only text came through.
    let url: URL?
    /// Everything textual the share carried: a title, a caption, the traveller's own
    /// note. Joined with newlines, never parsed here.
    let text: String
    let capturedAt: Date

    init(id: UUID = UUID(), url: URL?, text: String, capturedAt: Date = .now) {
        self.id = id
        self.url = url
        self.text = text
        self.capturedAt = capturedAt
    }

    /// Which app it most likely came from, guessed from the host.
    ///
    /// A guess, and labelled as one: it drives nothing but the line of text that
    /// tells the traveller what they are looking at.
    var source: Source {
        guard let host = url?.host()?.lowercased() else { return .unknown }
        if host.contains("tiktok") { return .tiktok }
        if host.contains("instagram") { return .instagram }
        if host.contains("youtube") || host.contains("youtu.be") { return .youtube }
        return .unknown
    }

    enum Source: String, Codable, Hashable, Sendable {
        case tiktok, instagram, youtube, unknown
    }

    var isEmpty: Bool {
        url == nil && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
