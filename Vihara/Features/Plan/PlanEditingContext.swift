import Foundation

/// What a day needs in order to be editable, bundled so the view hierarchy threads
/// one value instead of four closures.
///
/// `disabled` is a real state, not a test double: a plan is not editable while it is
/// still streaming, and a shared or read-only plan never is. Defaulting to it means a
/// day that is handed no editing context simply renders — which is also what keeps
/// ``DayView`` previewable.
struct PlanEditingContext {
    let isEnabled: Bool
    /// Which half-days this item could move to. Computed from the same rule that
    /// decides whether a drop target lights up, so the menu never offers a move the
    /// drag would refuse.
    let moveTargets: (ItineraryItem, TripDay) -> [DaySlot]
    /// The only way an edit happens. Both the gesture and the menu call this.
    let apply: (PlanEdit) -> Void

    static let disabled = PlanEditingContext(isEnabled: false,
                                             moveTargets: { _, _ in [] },
                                             apply: { _ in })
}
