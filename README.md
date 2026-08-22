# Vihara — SwiftUI UI spike

The first two screens of the Vihara travel-planning app, built natively so they can
be run on a real iPhone today. The PRD picks Flutter for production; this is a
throwaway-friendly prototype, but the design tokens in
[`Theme.swift`](Vihara/DesignSystem/Theme.swift) transfer to Flutter 1:1.

No third-party packages, no network calls, no backend — static sample data only.
Targets iOS 17, portrait, light appearance, iPhone.

| | |
|---|---|
| **Screen 1** | `WelcomeView` — full-bleed photo, wordmark, headline, `Los` |
| **Screen 2** | `DiscoverView` — header, category tabs, two horizontal rails, floating nav |

## Opening and running

The `.xcodeproj` is checked in and hand-written — there is no XcodeGen or other
generation step, and nothing to install first.

```bash
open Vihara.xcodeproj
```

To run on your iPhone: plug it in, pick it from the device menu in the toolbar, then
select the **Vihara** target → **Signing & Capabilities** and choose your team under
*Automatic signing* (it is deliberately left unset). Press ⌘R.

The bundle id is `com.vihara.app`; change it in the same pane if it collides with
something already on your account.

To check it builds without opening Xcode:

```bash
xcodebuild -project Vihara.xcodeproj -scheme Vihara -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build
```

## Swapping the placeholder colours for real photographs

The asset catalog ships solid muted-green PNGs so the app runs before any
photography exists. Each image set is configured as a **single-scale universal
image**, so replacing one is a single-file drop — no `@2x`/`@3x` variants needed:

```
Vihara/Assets.xcassets/
  welcome_bg.imageset/welcome_bg.png              portrait, fills Screen 1
  dest_bologna.imageset/dest_bologna.png          portrait ~3:4, destination rail
  dest_sansebastian.imageset/dest_sansebastian.png
  top_modena.imageset/top_modena.png              square, 52pt thumb
  top_ravenna.imageset/top_ravenna.png
```

Drop your photograph in with **the same filename**, or drag it onto the image set in
Xcode's asset catalog editor. Everything is drawn with `.scaledToFill()` inside a
clipped container, so aspect ratio is forgiving — match the rough shape noted above
and the crop takes care of itself. Supply roughly 3× the point size (Screen 1 wants
~1200×2600) so it stays sharp on a Retina display.

Every image goes through [`AssetImage`](Vihara/Components/AssetImage.swift), which
keeps a muted fill behind the photo. A missing or misnamed asset degrades to that
colour field instead of collapsing the layout, so a typo during the swap will not
break the build or the screen.

## Retuning the design

Everything lives in [`Theme.swift`](Vihara/DesignSystem/Theme.swift). No other file
contains a literal hex value, font size, corner radius or spacing constant — the hex
initialiser is deliberately `fileprivate` so it cannot leak out.

| Want to change | Touch |
|---|---|
| Any colour | `Theme.C` — `bg`, `surface`, `text`, `textMuted`, `textFaint`, `border`, `accent`, `accentDeep`, `price` |
| Type scale, weight, line height, tracking | `Theme.F` — `h1`, `h2`, `h3`, `body`, `small`, `label`, plus component steps |
| Corner radii | `Theme.R` |
| Spacing, screen inset, tap targets | `Theme.S` — `screen` (22) drives every screen-level inset |
| Card and control dimensions | `Theme.Size` |
| Opacity of the white overlays on photos | `Theme.O` |
| The two photo scrims | `Theme.G` |
| Card and floating-nav shadows | `Theme.Shadow` |

A few practical notes:

- **Type is serif everywhere, including chrome.** `Theme.F` builds fonts with
  `.system(design: .serif)`, which resolves to New York on iOS while keeping the
  correct optical size at every point size — `Font.custom("NewYorkMedium-Regular")`
  does not. Apply a step with `.viharaText(Theme.F.h3)`; never `.font(...)` directly.
- **Dynamic Type is honoured.** `viharaText` pairs the exact point size with
  `@ScaledMetric`, and card dimensions scale alongside, so the designed scale survives
  rather than opting out. To retune a step, change its `size` — the scaling follows.
- **`price` is reserved** for prices and warnings. It is used once, for the dot on the
  notifications button. `accent` is for interactive elements; `accentDeep` is the one
  to use when accent-coloured text sits in a run of copy.
- Radii and paddings the brief specified per-component (`R.welcome` 34, `R.destInner`
  18, `R.compactCard` 20, `R.compactThumb` 15, `S.cardCaptionH`, `S.compact`) are
  named tokens rather than inline numbers, so they can be retuned independently of
  the core scale.

## Known behaviour worth knowing

- **`DiscoverView` does not scroll vertically** — by design. Only the two horizontal
  rails scroll, so at large Dynamic Type the rails simply scroll further.
- **The bottom nav adapts in tiers.** Four German labels plus the 20pt-padded active
  pill do not fit a 375pt screen at the designed size, so `BottomNav` uses
  `ViewThatFits`: distributed → tight → one type step down (what an iPhone SE needs) →
  horizontally scrollable at full size (what large Dynamic Type needs). Nothing ever
  truncates.
- **Category tabs are interactive.** The brief only called for `Kulinarik` to be
  active, but a tab row that does not respond reads as broken in a prototype, so the
  selection is `@State`-driven like the nav.
- The header's `Su` / `Ne` buttons and `Alle ansehen` are tappable but have no
  destination yet.
