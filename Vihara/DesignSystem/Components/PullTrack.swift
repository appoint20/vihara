import CoreGraphics

/// The maths behind a pull-to-commit control: where the knob sits for a given
/// finger movement, and whether letting go commits.
///
/// Separated from the view because thresholds are the part that is easy to get
/// subtly wrong and impossible to eyeball — a commit point 10 % too high feels
/// stiff, 10 % too low fires by accident. Here they are numbers a test can hold to.
struct PullTrack: Equatable {
    /// The knob's full range, in points.
    let travel: CGFloat
    /// How far along the track a release commits.
    var commitFraction: CGFloat = 0.55
    /// How hard a flick has to be to commit from anywhere on the track, expressed as
    /// a multiple of the travel.
    var flickFraction: CGFloat = 1.2

    enum Outcome: Equatable {
        case commit
        case release
    }

    /// Where the knob sits for a finger translation, in view coordinates where a
    /// negative `dy` is upward.
    ///
    /// Clamped at both ends rather than rubber-banded. A knob that can be dragged
    /// past the head of its track is telling the hand about a state the control does
    /// not have, and pulling *down* on a control that only goes up should do nothing
    /// at all.
    func pull(forTranslation dy: CGFloat) -> CGFloat {
        min(travel, max(0, -dy))
    }

    /// Fraction of the way to the head, for driving the fade and the glass.
    func progress(pull: CGFloat) -> CGFloat {
        guard travel > 0 else { return 0 }
        return min(1, max(0, pull / travel))
    }

    /// What letting go means.
    ///
    /// Distance *or* intent: a short, fast flick commits even though the finger
    /// stopped well short, because that is what the hand meant.
    func outcome(pull: CGFloat, predictedTranslation dy: CGFloat) -> Outcome {
        // A track with nowhere to go — the knob is as tall as its frame, which very
        // large Dynamic Type can produce. A deliberate drag on it still means "go".
        guard travel > 0 else { return .commit }

        if pull >= travel * commitFraction { return .commit }
        if -dy >= travel * flickFraction { return .commit }
        return .release
    }
}
