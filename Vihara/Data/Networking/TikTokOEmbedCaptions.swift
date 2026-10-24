import Foundation

/// Reads a TikTok caption through the public oEmbed endpoint.
///
/// `https://www.tiktok.com/oembed?url=…` is documented, unauthenticated, and returns
/// the caption as `title`. That one field is what makes the share extension useful:
/// a shared link on its own names no places, and the caption is where "Bologna" is
/// actually written.
///
/// **This is oEmbed, not scraping.** It asks a published endpoint for the metadata
/// that endpoint exists to publish, and reads one field of it. Nothing parses the
/// page, and nothing is stored beyond the caption the traveller shared.
///
/// It does not use ``HTTPClient``: that is configured for Vihara's own API — base
/// URL, auth, idempotency keys — and none of it applies to a third party's public
/// metadata endpoint.
struct TikTokOEmbedCaptions: CaptionResolving {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func caption(for url: URL) async -> String? {
        guard Self.isTikTok(url) else { return nil }
        guard var components = URLComponents(string: "https://www.tiktok.com/oembed") else {
            return nil
        }
        components.queryItems = [URLQueryItem(name: "url", value: url.absoluteString)]
        guard let endpoint = components.url else { return nil }

        var request = URLRequest(url: endpoint)
        // A caption is a nicety. A traveller who has just opened the app should not
        // wait on a third party that is having a bad day.
        request.timeoutInterval = 6

        guard let (data, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let payload = try? JSONDecoder().decode(OEmbedResponse.self, from: data)
        else { return nil }

        let caption = payload.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (caption?.isEmpty ?? true) ? nil : caption
    }

    static func isTikTok(_ url: URL) -> Bool {
        guard let host = url.host()?.lowercased() else { return false }
        return host == "tiktok.com" || host.hasSuffix(".tiktok.com")
    }

    /// Only the one field we use. oEmbed returns a dozen more and none of them are
    /// any of our business.
    private struct OEmbedResponse: Decodable {
        let title: String?
    }
}

/// What the app uses when no caption can be fetched.
///
/// Instagram and Reels land here: their oEmbed has needed an access token since 2020,
/// so a shared Reel resolves from whatever text the share sheet carried and nothing
/// more. That is a real gap in the feature and it is named here rather than hidden
/// behind a silent failure — see ``CaptionResolving``.
struct NoCaptions: CaptionResolving {
    func caption(for url: URL) async -> String? { nil }
}
