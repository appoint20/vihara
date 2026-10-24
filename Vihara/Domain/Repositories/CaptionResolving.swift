import Foundation

/// Fetches the caption behind a shared link.
///
/// Behind a protocol because what is possible differs sharply by platform, and the
/// difference is a product constraint worth being explicit about:
///
/// - **TikTok** publishes an oEmbed endpoint that returns the caption with no
///   authentication. ``TikTokOEmbedCaptions`` uses it.
/// - **Instagram and Reels** required an access token for oEmbed from 2020 onward.
///   There is no client-side way to read those captions, so a shared Reel resolves
///   from whatever text the share sheet happened to carry — often nothing. Closing
///   that gap needs a backend holding a token, not more client code.
/// - **YouTube** publishes oEmbed too, returning the video title rather than the
///   description.
///
/// Returning `nil` is normal and must stay cheap: most captures will not be enriched.
protocol CaptionResolving: Sendable {
    func caption(for url: URL) async -> String?
}
