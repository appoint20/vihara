import AVFoundation
import SwiftUI

/// A silently looping video, with a still of its own first frame underneath.
///
/// The still is not a fallback bolted on afterwards — it is always there, behind the
/// player. It covers the moment before the first frame decodes (otherwise the screen
/// opens on black), it is what a reader with Reduce Motion sees instead, and it is
/// what shows if the clip is ever missing from the bundle. Because it is generated
/// *from* the clip, the swap between them is invisible.
///
/// Presentational only: the caller owns the scrim, the corner radius and the inset.
struct VideoBackground: View {
    /// Resource name of the `.mp4` in the bundle, without its extension.
    let resource: String
    /// Image-set name of the poster frame.
    let poster: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            AssetImage(name: poster)

            if !reduceMotion, let url = Self.url(for: resource) {
                LoopingVideoLayer(url: url, isPlaying: scenePhase == .active)
                    .transition(.opacity)
            }
        }
        .accessibilityHidden(true)
    }

    private static func url(for resource: String) -> URL? {
        Bundle.main.url(forResource: resource, withExtension: "mp4")
    }
}

/// An `AVPlayerLayer` that loops, muted, and stops when the app is not on screen.
///
/// `AVKit`'s `VideoPlayer` is the shorter route and the wrong one: it brings playback
/// controls, a tap target and a background colour that a decorative backdrop must not
/// have.
private struct LoopingVideoLayer: UIViewRepresentable {
    let url: URL
    let isPlaying: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    func makeUIView(context: Context) -> PlayerHostView {
        let view = PlayerHostView()
        view.playerLayer.player = context.coordinator.player
        view.playerLayer.videoGravity = .resizeAspectFill
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ view: PlayerHostView, context: Context) {
        context.coordinator.setPlaying(isPlaying)
    }

    static func dismantleUIView(_ view: PlayerHostView, coordinator: Coordinator) {
        coordinator.setPlaying(false)
    }

    @MainActor
    final class Coordinator {
        let player: AVQueuePlayer
        /// Retained: the looper stops looping the moment it is released.
        private let looper: AVPlayerLooper

        init(url: URL) {
            player = AVQueuePlayer()
            // The clip carries no audio track, so the player never activates the audio
            // session and never interrupts what the traveller is listening to. Muting
            // as well costs nothing and survives someone re-adding a soundtrack.
            player.isMuted = true
            // A backdrop is not a reason to keep the screen awake.
            player.preventsDisplaySleepDuringVideoPlayback = false
            looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        }

        func setPlaying(_ playing: Bool) {
            if playing {
                player.play()
            } else {
                player.pause()
            }
        }
    }
}

/// A view whose backing layer *is* the player layer, so there is no second layer to
/// keep in sync on rotation or resize.
private final class PlayerHostView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer {
        // Safe by construction: `layerClass` above guarantees the type.
        layer as! AVPlayerLayer
    }
}

#Preview {
    VideoBackground(resource: "welcome_loop", poster: "welcome_bg")
        .ignoresSafeArea()
}
