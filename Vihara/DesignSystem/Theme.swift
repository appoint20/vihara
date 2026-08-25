import SwiftUI

/// Vihara design tokens.
///
/// This is the single source of truth for colour, type, radius, spacing, shadow and
/// scrim. No other file in the app contains a literal hex value, font size, corner
/// radius or spacing constant — reach for `Theme.C`, `Theme.F`, `Theme.R`, `Theme.S`,
/// `Theme.Size`, `Theme.O` and `Theme.G` instead.
enum Theme {

    // MARK: - Colour

    /// Every colour carries both appearances.
    ///
    /// Dark mode is required at launch (PRD 5.2), and retrofitting appearance into a
    /// palette that only ever had one value is the expensive version of this work.
    /// Defining the pair now costs a second literal and keeps every call site — and
    /// every preview — unchanged. The dark ramp is the neutral scale inverted, with
    /// the accents one step brighter so they hold their contrast on a dark ground.
    enum C {
        /// Paper ground — the app background.
        static let bg = Color(light: 0xF3F2F2, dark: 0x141312)
        /// Cards.
        static let surface = Color(light: 0xFFFFFF, dark: 0x1F1D1C)
        /// Primary text.
        static let text = Color(light: 0x201E1D, dark: 0xF2F0EF)
        static let textMuted = Color(light: 0x605D5D, dark: 0xA8A4A3)
        static let textFaint = Color(light: 0x9B9797, dark: 0x7A7676)
        static let border = Color(light: 0xD7D3D3, dark: 0x383534)
        /// Interactive only — never body text.
        static let accent = Color(light: 0x0088B0, dark: 0x35B4DC)
        /// Accent-coloured body text.
        static let accentDeep = Color(light: 0x006786, dark: 0x6FCBE8)
        /// Prices and warnings ONLY. Never in the same component as `accent`.
        static let price = Color(light: 0xAA0B56, dark: 0xE86BA5)

        /// Stands in for a photograph that failed to load, so image views degrade
        /// gracefully instead of collapsing to nothing.
        static let imageFallback = Color(light: 0x5A6B4E, dark: 0x3F4A38)
    }

    // MARK: - Typography
    //
    // Everything is a serif. `.system(design: .serif)` resolves to New York on iOS,
    // and — unlike `Font.custom("NewYorkMedium-Regular")` — it picks up the correct
    // optical size and stays available on every device. Never a sans-serif, including
    // chrome.

    enum F {
        // Core scale.
        static let h1 = TextSpec(size: 34, weight: .semibold, lineHeight: 1.1, relativeTo: .largeTitle)
        static let h2 = TextSpec(size: 28, weight: .semibold, lineHeight: 1.1, relativeTo: .title)
        static let h3 = TextSpec(size: 20, weight: .semibold, lineHeight: 1.2, relativeTo: .title3)
        static let body = TextSpec(size: 16, lineHeight: 1.5, relativeTo: .body)
        static let small = TextSpec(size: 13, lineHeight: 1.35, relativeTo: .footnote)
        static let label = TextSpec(size: 11, weight: .semibold, lineHeight: 1.2,
                                    tracking: 1.4, uppercase: true, relativeTo: .caption2)

        // Component steps derived from the scale.
        /// Screen 1 wordmark — `label` opened up.
        static let brand = TextSpec(size: 11, weight: .semibold, lineHeight: 1.2,
                                    tracking: 2.8, uppercase: true, relativeTo: .caption2)
        /// The `Los` call to action.
        static let cta = TextSpec(size: 21, weight: .semibold, lineHeight: 1.2, relativeTo: .title3)
        static let cardTitle = TextSpec(size: 16, weight: .semibold, lineHeight: 1.2, relativeTo: .body)
        static let compactTitle = TextSpec(size: 14.5, weight: .semibold, lineHeight: 1.2, relativeTo: .subheadline)
        static let rating = TextSpec(size: 12, weight: .semibold, lineHeight: 1.2, relativeTo: .caption)
        static let navLabel = TextSpec(size: 14, lineHeight: 1.2, relativeTo: .subheadline)
        /// One step down, for narrow devices where the four nav labels cannot hold
        /// their designed size. Unlike `minimumScaleFactor` this reports an honestly
        /// smaller width, so `ViewThatFits` can actually choose it.
        static let navLabelCompact = TextSpec(size: 13, lineHeight: 1.2, relativeTo: .subheadline)
        static let glyph = TextSpec(size: 15, weight: .semibold, lineHeight: 1.2, relativeTo: .subheadline)
        static let tabActive = TextSpec(size: 16, weight: .semibold, lineHeight: 1.2, relativeTo: .body)
        static let tabInactive = TextSpec(size: 16, lineHeight: 1.2, relativeTo: .body)
        static let chevron = TextSpec(size: 15, weight: .semibold, lineHeight: 1.2, relativeTo: .subheadline)
    }

    // MARK: - Radius

    enum R {
        static let card: CGFloat = 22
        static let photoCard: CGFloat = 26
        static let hero: CGFloat = 30
        static let thumb: CGFloat = 17
        static let pill: CGFloat = 100

        /// Screen 1's inset photo container.
        static let welcome: CGFloat = 34
        /// The white caption card nested inside a `DestinationCard`.
        static let destInner: CGFloat = 18
        static let compactCard: CGFloat = 20
        static let compactThumb: CGFloat = 15
    }

    // MARK: - Spacing (4pt base)

    enum S {
        /// Half step, for hairline gaps between stacked lines of type.
        static let s05: CGFloat = 2
        static let s1: CGFloat = 4
        static let s2: CGFloat = 8
        static let s3: CGFloat = 12
        static let s4: CGFloat = 16
        static let s5: CGFloat = 20
        static let s6: CGFloat = 24
        static let s7: CGFloat = 28
        static let s8: CGFloat = 32

        /// Horizontal inset for screen-level content.
        static let screen: CGFloat = 22
        /// Breathing room between the device edge and Screen 1's photo container.
        static let welcomeInset: CGFloat = 14
        /// Gap between cards in a horizontal rail.
        static let rail: CGFloat = 14
        /// Space above a section heading.
        static let sectionTop: CGFloat = 26
        /// Gap between the floating nav and the bottom safe area.
        static let navBottom: CGFloat = 30
        /// Horizontal padding inside a `DestinationCard`'s caption card.
        static let cardCaptionH: CGFloat = 14
        /// Padding inside a `CompactCard` …
        static let compact: CGFloat = 9
        /// … opened up on the trailing edge so the text has room to breathe.
        static let compactTrailing: CGFloat = 13
        /// Minimum hit area for anything tappable.
        static let tapTarget: CGFloat = 44
    }

    // MARK: - Component sizes

    enum Size {
        static let destCard = CGSize(width: 212, height: 296)
        static let compactCardWidth: CGFloat = 170
        static let compactThumb: CGFloat = 52
        static let welcomeCapsule = CGSize(width: 104, height: 150)
        static let losCircle: CGFloat = 86
        static let headerButton: CGFloat = 40
        static let headerDot: CGFloat = 6
        static let tabUnderline = CGSize(width: 26, height: 2.5)
        static let hairline: CGFloat = 1
        /// Caps Screen 1's supporting copy at roughly 26 characters per line.
        static let heroMeasure: CGFloat = 200
    }

    // MARK: - Opacity

    enum O {
        static let brandMark: Double = 0.80
        static let heroBody: Double = 0.78
        static let chevron: Double = 0.85
        static let ratingPill: Double = 0.94
        static let destInnerCard: Double = 0.95
        static let glassFill: Double = 0.16
        static let glassStroke: Double = 0.28
    }

    // MARK: - Scrims

    enum G {
        /// Screen 1: dark at the top for the wordmark, opens up through the middle of
        /// the frame, then closes down hard so the headline stays legible.
        static let welcomeScrim = LinearGradient(
            stops: [
                .init(color: .black.opacity(0.50), location: 0.00),
                .init(color: .black.opacity(0.12), location: 0.34),
                .init(color: .black.opacity(0.50), location: 0.72),
                .init(color: .black.opacity(0.86), location: 1.00),
            ],
            startPoint: .top, endPoint: .bottom
        )

        /// Destination card: clear over the photo, weighted at the foot.
        static let destinationScrim = LinearGradient(
            stops: [
                .init(color: .clear, location: 0.46),
                .init(color: .black.opacity(0.50), location: 1.00),
            ],
            startPoint: .top, endPoint: .bottom
        )
    }

    // MARK: - Motion

    enum Motion {
        /// Moving the active pill in the floating nav.
        static let navPill = Animation.snappy(duration: 0.25)
        /// Switching category tabs.
        static let tab = Animation.snappy(duration: 0.20)
    }

    // MARK: - Shadow

    enum Shadow {
        static let card = ShadowSpec(color: .black.opacity(0.08), radius: 2, y: 1)
        static let floatingNav = ShadowSpec(color: .black.opacity(0.16), radius: 10, y: 3)
    }
}

// MARK: - Specs

extension Theme {

    /// A point-accurate type step that still honours Dynamic Type.
    struct TextSpec {
        let size: CGFloat
        let weight: Font.Weight
        /// Multiple of `size`, as in the design spec (34/1.1 → `lineHeight` 1.1).
        let lineHeight: CGFloat
        let tracking: CGFloat
        let uppercase: Bool
        /// The built-in style this step scales alongside.
        let relativeTo: Font.TextStyle

        init(size: CGFloat,
             weight: Font.Weight = .regular,
             lineHeight: CGFloat,
             tracking: CGFloat = 0,
             uppercase: Bool = false,
             relativeTo: Font.TextStyle) {
            self.size = size
            self.weight = weight
            self.lineHeight = lineHeight
            self.tracking = tracking
            self.uppercase = uppercase
            self.relativeTo = relativeTo
        }

        /// The extra leading SwiftUI must add to reach the designed line height.
        var lineSpacing: CGFloat { size * (lineHeight - 1) }
    }

    struct ShadowSpec {
        let color: Color
        let radius: CGFloat
        let y: CGFloat
    }
}

// MARK: - Modifiers

private struct ViharaTextModifier: ViewModifier {
    @ScaledMetric private var size: CGFloat
    @ScaledMetric private var lineSpacing: CGFloat
    private let spec: Theme.TextSpec

    init(_ spec: Theme.TextSpec) {
        self.spec = spec
        _size = ScaledMetric(wrappedValue: spec.size, relativeTo: spec.relativeTo)
        _lineSpacing = ScaledMetric(wrappedValue: spec.lineSpacing, relativeTo: spec.relativeTo)
    }

    func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: spec.weight, design: .serif))
            .tracking(spec.tracking)
            .lineSpacing(lineSpacing)
            .textCase(spec.uppercase ? .uppercase : nil)
    }
}

extension View {
    /// Applies a Vihara type step: serif face, exact point size, designed line height
    /// and tracking — all scaling with the reader's Dynamic Type setting.
    func viharaText(_ spec: Theme.TextSpec) -> some View {
        modifier(ViharaTextModifier(spec))
    }

    func viharaShadow(_ spec: Theme.ShadowSpec) -> some View {
        shadow(color: spec.color, radius: spec.radius, x: 0, y: spec.y)
    }

    /// Grows the hit area to at least 44×44pt without disturbing the visual size.
    func viharaHitTarget() -> some View {
        frame(minWidth: Theme.S.tapTarget, minHeight: Theme.S.tapTarget)
            .contentShape(Rectangle())
    }

    /// Grows the hit area to at least 44×44pt *and* keeps the original layout
    /// footprint, by padding the touch region out and pulling the layout back in.
    /// For inline controls that must not disturb a baseline-aligned row.
    func viharaInlineHitTarget() -> some View {
        padding(Theme.S.s4)
            .contentShape(Rectangle())
            .padding(-Theme.S.s4)
    }
}

// MARK: - Hex

/// Deliberately fileprivate: hex literals live here and nowhere else.
private extension Color {
    /// A colour that resolves per appearance.
    ///
    /// Built through `UIColor`'s dynamic provider rather than a SwiftUI
    /// `@Environment(\.colorScheme)` lookup, so it also resolves correctly outside a
    /// view's body — in `UIImage` rendering, in the PDF template preview, and in
    /// anything drawn through `CALayer`.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    /// `0xRRGGBB`, sRGB.
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
