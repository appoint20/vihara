import SwiftUI

/// The knob in a track: pull it to the top of the capsule to go on.
///
/// The capsule was always drawn as a track — a chevron at the head, a knob at the
/// foot — so making it behave like one is finishing the design rather than adding to
/// it. Three things follow from that:
///
/// - **The knob never leaves the track.** The pull is clamped, not rubber-banded, so
///   the control cannot be pulled into a state it does not have.
/// - **A flick counts.** Committing on either distance or velocity means the gesture
///   works at the speed a hand actually moves.
/// - **A tap still works**, and runs the same commit animation. Anyone who does not
///   read the affordance, or who is driving this from VoiceOver, gets the same
///   result and the same feedback.
struct PullUpControl: View {
    let title: String
    /// Spoken label. The visible title is usually too terse on its own.
    let label: String
    let onCommit: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ScaledMetric(relativeTo: .title3) private var trackWidth: CGFloat = Theme.Size.welcomeCapsule.width
    @ScaledMetric(relativeTo: .title3) private var trackHeight: CGFloat = Theme.Size.welcomeCapsule.height
    @ScaledMetric(relativeTo: .title3) private var knob: CGFloat = Theme.Size.losCircle

    /// How far the knob has been pulled, in points. Always within `0...travel`.
    @State private var pull: CGFloat = 0
    /// The idle rise that signals the control can be pulled.
    @State private var hint: CGFloat = 0
    @State private var isDragging = false
    /// Latched once the pull commits, so a second gesture cannot navigate twice.
    @State private var hasCommitted = false

    var body: some View {
        trackSurface
            .frame(width: trackWidth, height: trackHeight)
            .overlay(alignment: .top) { chevron }
            .overlay(alignment: .bottom) { knobView }
            .contentShape(Rectangle())
            .gesture(pullGesture)
            // Simultaneous, not stacked: a drag gesture with a minimum distance can
            // otherwise swallow the touch and leave a plain tap doing nothing. Both
            // routes land in `commit()`, which is latched, so a double fire is inert.
            .simultaneousGesture(TapGesture().onEnded { commit() })
            .task { startHint() }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityHint(Text("control.pullUp"))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { commit() }
    }

    // MARK: - Geometry

    /// Derived, not guessed: the track's height less the knob and the padding at
    /// either end, so the knob lands exactly at the head. The thresholds live in
    /// ``PullTrack``, where they are testable.
    private var track: PullTrack {
        PullTrack(travel: max(0, trackHeight - knob - Theme.S.s3 * 2))
    }

    private var progress: CGFloat {
        track.progress(pull: pull)
    }

    // MARK: - Parts

    private var trackSurface: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.R.pill, style: .continuous)
        return shape
            .fill(.ultraThinMaterial)
            // The glass warms slightly as the knob rises, so the track confirms the
            // pull without a progress bar or a number.
            .overlay { shape.fill(.white.opacity(Theme.O.glassFill + progress * 0.12)) }
            .overlay {
                shape.strokeBorder(.white.opacity(Theme.O.glassStroke + progress * 0.2),
                                   lineWidth: Theme.Size.hairline)
            }
    }

    /// Fades out as the knob rises into the space it occupies — it has said what it
    /// had to say by then.
    private var chevron: some View {
        Image(systemName: "chevron.up")
            .viharaText(Theme.F.chevron)
            .foregroundStyle(.white.opacity(Theme.O.chevron * Double(1 - progress)))
            .padding(.top, Theme.S.s3)
            .accessibilityHidden(true)
    }

    private var knobView: some View {
        Text(title)
            .viharaText(Theme.F.cta)
            .foregroundStyle(Theme.C.text)
            .frame(width: knob, height: knob)
            .background(Theme.C.surface, in: Circle())
            .scaleEffect(isDragging ? 1.03 : 1)
            .padding(.bottom, Theme.S.s3)
            .offset(y: -(pull + hint))
    }

    // MARK: - Gesture

    private var pullGesture: some Gesture {
        // A 1pt threshold leaves stationary taps to the tap gesture.
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                guard !hasCommitted else { return }
                if !isDragging {
                    isDragging = true
                    stopHint()
                    Haptics.pickUp()
                }
                pull = track.pull(forTranslation: value.translation.height)
            }
            .onEnded { value in
                guard !hasCommitted else { return }
                isDragging = false

                switch track.outcome(pull: pull,
                                     predictedTranslation: value.predictedEndTranslation.height) {
                case .commit:
                    commit()
                case .release:
                    Haptics.release()
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.68)) { pull = 0 }
                    startHint()
                }
            }
    }

    private func commit() {
        guard !hasCommitted else { return }
        hasCommitted = true
        stopHint()
        Haptics.commit()
        // The knob lands *before* the push, so the screen leaves on a finished
        // gesture rather than mid-flight.
        withAnimation(.spring(response: 0.26, dampingFraction: 0.78), completionCriteria: .logicallyComplete) {
            pull = track.travel
        } completion: {
            onCommit()
        }
    }

    // MARK: - Idle hint

    /// A slow rise and settle. Instructional, not decorative — it is the only thing
    /// telling a first-time reader that the knob moves — so it stops the moment the
    /// gesture is understood, and never runs under Reduce Motion.
    private func startHint() {
        guard !reduceMotion, !hasCommitted else { return }
        withAnimation(.easeInOut(duration: 1.15).repeatForever(autoreverses: true).delay(0.5)) {
            hint = 7
        }
    }

    /// Replaces the repeating animation with a finite one, which is what actually
    /// stops it.
    private func stopHint() {
        withAnimation(.easeOut(duration: 0.16)) { hint = 0 }
    }
}

#Preview {
    ZStack {
        VideoBackground(resource: "welcome_loop", poster: "welcome_bg")
            .ignoresSafeArea()
        PullUpControl(title: "Los", label: "Los — Reise entdecken") {}
    }
}
