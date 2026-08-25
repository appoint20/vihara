import UIKit

/// Physical feedback for direct manipulation.
///
/// Only ever fired for something the hand did — picking a control up, putting it
/// down, crossing a threshold. Never for something that merely happened on screen.
@MainActor
enum Haptics {

    /// Picking a draggable control up.
    static func pickUp() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Putting it down where it commits to something.
    static func commit() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    /// Putting it down short of the threshold, so it springs back.
    static func release() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.6)
    }
}
