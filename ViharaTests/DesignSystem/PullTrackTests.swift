import Testing
import CoreGraphics
@testable import Vihara

/// The pull-to-commit thresholds.
///
/// The gesture itself cannot be unit-tested, but the numbers that decide how it
/// feels can be — and those are the part that goes subtly wrong.
@Suite("Pull track")
struct PullTrackTests {

    /// The real geometry: a 150pt capsule, an 86pt knob, 12pt of padding at each end.
    private let track = PullTrack(travel: 150 - 86 - 12 * 2)

    @Test("The designed control has 40pt of travel")
    func travel() {
        #expect(track.travel == 40)
    }

    @Suite("Following the finger")
    struct Following {
        private let track = PullTrack(travel: 40)

        @Test("An upward drag moves the knob by the same amount")
        func upward() {
            #expect(track.pull(forTranslation: -25) == 25)
        }

        @Test("The knob stops at the head of the track")
        func clampedAtHead() {
            // Not rubber-banded: past the head is a state the control does not have.
            #expect(track.pull(forTranslation: -200) == 40)
        }

        @Test("Pulling down does nothing")
        func clampedAtFoot() {
            #expect(track.pull(forTranslation: 60) == 0)
        }

        @Test("Progress is bounded on both sides", arguments: [
            (CGFloat(0), CGFloat(0)), (10, 0.25), (40, 1), (90, 1), (-10, 0),
        ])
        func progress(pull: CGFloat, expected: CGFloat) {
            #expect(track.progress(pull: pull) == expected)
        }
    }

    @Suite("Letting go")
    struct LettingGo {
        private let track = PullTrack(travel: 40)

        @Test("Past the commit point, it goes")
        func pastThreshold() {
            // 55 % of 40pt is 22pt.
            #expect(track.outcome(pull: 22, predictedTranslation: -22) == .commit)
        }

        @Test("Just short of it, it springs back")
        func shortOfThreshold() {
            #expect(track.outcome(pull: 21, predictedTranslation: -21) == .release)
        }

        @Test("A hard flick commits from near the foot")
        func flick() {
            // Barely moved, but heading for 60pt — well past the 48pt flick bar.
            #expect(track.outcome(pull: 6, predictedTranslation: -60) == .commit)
        }

        @Test("A gentle nudge does not")
        func nudge() {
            #expect(track.outcome(pull: 6, predictedTranslation: -9) == .release)
        }

        @Test("A downward flick never commits")
        func downwardFlick() {
            #expect(track.outcome(pull: 0, predictedTranslation: 120) == .release)
        }
    }

    @Test("A track with no room left still commits on a deliberate drag")
    func degenerateTrack() {
        // Very large Dynamic Type can grow the knob to the height of its frame. The
        // control must not become inert.
        let flat = PullTrack(travel: 0)

        #expect(flat.pull(forTranslation: -50) == 0)
        #expect(flat.progress(pull: 0) == 0)
        #expect(flat.outcome(pull: 0, predictedTranslation: -50) == .commit)
    }
}
