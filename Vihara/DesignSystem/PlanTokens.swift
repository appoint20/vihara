import SwiftUI

extension Theme {

    /// Tokens for the planning surface, straight from PRD 5.2.
    ///
    /// **These deliberately differ from the tokens above.** The Welcome and Discover
    /// screens are a browsing surface: photo cards, 22pt–34pt radii, a 4pt grid. The
    /// plan is not. PRD 5.2 specifies a 5pt grid, a 2pt radius, no card boxes and no
    /// rules — separation by whitespace and type size alone — because the plan screen
    /// answers one question and every box drawn around a *Baustein* is a box the
    /// traveller has to read past.
    ///
    /// Two surfaces with two grids is a real cost, and it is on the open-questions
    /// list for the PM: either Discover moves onto the plan tokens, or we accept the
    /// split and name it in the design system rather than letting it drift.
    enum Plan {

        /// Three sizes on the main screen, and no more (PRD 5.2).
        enum F {
            /// "Dienstag · 14. April · Bologna"
            static let dayTitle = TextSpec(size: 22, weight: .semibold, lineHeight: 1.2,
                                           relativeTo: .title2)
            /// A *Baustein* — the name of the place.
            static let item = TextSpec(size: 17, lineHeight: 1.3, relativeTo: .body)
            /// Times, walking minutes, addresses, badges.
            static let meta = TextSpec(size: 13, lineHeight: 1.35, relativeTo: .footnote)
            /// VORMITTAG · NACHMITTAG · ABEND. Tracking is the specified +0.1em,
            /// which at 11pt is 1.1pt.
            static let blockLabel = TextSpec(size: 11, weight: .semibold, lineHeight: 1.2,
                                             tracking: 1.1, uppercase: true, relativeTo: .caption2)
            /// The one primary action a plan screen is allowed.
            static let action = TextSpec(size: 17, weight: .semibold, lineHeight: 1.2,
                                         relativeTo: .body)
        }

        /// 5pt base grid. Density is not adjustable — that is the point.
        enum S {
            static let s1: CGFloat = 5
            static let s2: CGFloat = 10
            static let s3: CGFloat = 15
            static let s4: CGFloat = 20
            static let s5: CGFloat = 25
            /// Between the three blocks of a day.
            static let block: CGFloat = 30
            /// Between days.
            static let day: CGFloat = 40
            /// Horizontal inset for the plan.
            static let screen: CGFloat = 20
        }

        /// Radius 2. Shadows only on modal layers, so there is no shadow token here.
        enum R {
            static let surface: CGFloat = 2
        }

        /// 180–240 ms, ease-out. No decorative animation (PRD 5.2).
        enum Motion {
            /// A newly validated day arriving in the stream.
            static let dayArrival = Animation.easeOut(duration: 0.24)
            /// Everything else.
            static let standard = Animation.easeOut(duration: 0.18)
        }
    }
}
