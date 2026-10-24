# Vihara

A native iOS travel planner: one sentence in, a verified day-by-day plan out.

The plan is the product. Everything else is one tap away from it.

| | |
|---|---|
| **Platform** | iOS 17+, iPhone, portrait, German |
| **Dependencies** | none — no packages, no CocoaPods, no SPM graph |
| **Backend** | the offer service is real ([`services/offers/`](services/offers/)); generation, rates and entitlements are still stubs |
| **Tests** | 339 Swift in 46 suites, plus 33 for the offer service under `node --test` |

## Architecture

Three targets. `Vihara` is the app, `ViharaShare` is the share extension, and
`ViharaShared` is the small folder compiled into **both** — it holds the entire
contract between them and depends on nothing but Foundation, because an app extension
links its own binary and gets a fraction of the app's memory.

Five layers in the app target, with the dependency rule pointing inward:

```
App/           composition root, routing            everything
Features/      screens and @Observable view models  Domain, DesignSystem
DesignSystem/  tokens and presentational views      SwiftUI only
Data/          HTTP, DTOs, mappers, repositories    Domain, Foundation
Domain/        entities, protocols, use cases       Foundation only
```

`Domain` knows nothing about SwiftUI, JSON or `URLSession`. `Data` implements the
protocols `Domain` declares. `Features` depend on protocols and use cases, never on a
concrete repository. `App/AppDependencies.swift` is the only file that names a
concrete type — swapping the stub generator for the real backend is one line in it.

Enforced, not hoped for:

```bash
./Scripts/check-layers.sh
```

The decisions behind the structure, including the ones that contradict the PRD, are
in [`docs/adr/`](docs/adr/). The commercial plan — the competitive gaps Vihara targets
and how it earns — is in [`docs/COMPETITION.md`](docs/COMPETITION.md) and
[`docs/MONETISATION.md`](docs/MONETISATION.md):

| | |
|---|---|
| [ADR-001](docs/adr/001-native-swiftui.md) | Native SwiftUI, not Flutter — **needs a product decision** |
| [ADR-002](docs/adr/002-modules.md) | Layered folders now, Swift packages at a named trigger |
| [ADR-003](docs/adr/003-domain-purity.md) | The domain is pure Swift; the wire format stops at the data layer |
| [ADR-004](docs/adr/004-server-authoritative-entitlements.md) | Entitlements are server-authoritative; the client cannot spend |
| [ADR-005](docs/adr/005-streaming-and-observation.md) | Streaming in the protocol, `@Observable` in the view models |
| [ADR-006](docs/adr/006-affiliate-links-server-authoritative.md) | Affiliate links are minted by the server; the client cannot construct a payable URL — **proposed** |

## What runs today

`Welcome → Discover → Intake → Plan`, end to end, against sample data.

- **Intake (F-01)** parses a German sentence into a `TripBrief` and mirrors it back as
  editable chips. `HeuristicTripBriefParser` stands in for the intake model; it
  resolves destinations through the curated catalogue rather than guessing, which is
  the product rule, not a shortcut.
- **Plan (F-02)** streams one validated day at a time — three named blocks, no cards,
  no map, one skeleton for the day being composed. `ItineraryRules` names every
  composition conflict locally, which is the half of reflow (F-06) that needs no
  round trip.
- **Diet signals (F-04)** distinguish *bestätigt* from *wahrscheinlich* visually,
  because only provider attributes and venue menus may claim the former. The shipped
  sample data claims only *wahrscheinlich*: nothing in it has been read from a
  provider or a menu, so nothing in it may say *bestätigt* (`PlanDisplayTests`).
- **Storage (F-14) is real.** `FileTripRepository` writes one JSON record per plan to
  Application Support, atomically, through a mapper — the domain stays non-`Codable`
  per [ADR-003](docs/adr/003-domain-purity.md). A plan survives the app being killed
  and opens from **Meine Reisen** without regenerating.
- **A plan can leave the app.** *Plan teilen* renders the days as plain text and hands
  them to the share sheet — no paywall, no account, no PDF renderer. F-08's
  watermarked export replaces it as the primary action later.
- **The Welcome control is a track, not a button.** Pull the knob to the head of the
  capsule to go on — clamped rather than rubber-banded, committing on distance *or*
  flick velocity, with haptics on pick-up and drop. A tap does the same thing and runs
  the same animation. The thresholds live in
  [`PullTrack`](Vihara/DesignSystem/Components/PullTrack.swift) so they are tested
  rather than eyeballed.

- **Search finds 285 cities (F-01).** `Cities.json` is a bundled corpus standing in
  for Google Places, so the search field works with no key, no network and no
  per-request bill. Everything in it reports `isPlannable == false`, which is not a
  limitation of the mock — a city is plannable only once its POI index is curated, so
  the corpus names Lissabon and honestly refuses to plan it. Regenerate it with
  `Scripts/generate-cities.py`; do not hand-edit it.
- **The plan is editable (F-05/F-06).** Drag a stop between half-days, or use
  *Verschieben nach…* in the context menu — both emit the same `PlanEdit`, so the
  accessible path cannot drift away from the gesture. Conflicts are **named, never
  silently corrected**: an overfull block keeps everything in it and offers a move the
  traveller can take or leave. Pinning is a promise to reflow, not a lock.
- **Booking offers are live on stubs (F-10).** A stop that `requiresTicket` now
  carries a GetYourGuide link instead of only a warning. The links carry **no
  affiliate marker and earn nothing** — they point at public search pages, because
  inventing a tracking parameter would misrepresent an account we do not hold. The
  architecture is the point: see
  [ADR-006](docs/adr/006-affiliate-links-server-authoritative.md) and
  [`docs/MONETISATION.md`](docs/MONETISATION.md).
- **Budget and packing compose themselves (F-11/F-12).** Both are one tap from the
  plan, never beside it. The budget separates what it *knows* (admissions, from
  provider data) from what it *assumes* (meals), the same way `DietSignal` separates
  *bestätigt* from *wahrscheinlich*, and names what it had to leave out. The packing
  list gives every line its reason — "70 Min. zu Fuß an einem Tag" rather than
  "comfortable shoes".

- **The plan exports as a PDF (F-08).** CoreText, vector text, A4, paginated — not a
  screenshot, because a plan gets printed at a hotel desk and searched in a mail
  client. Colours are resolved against **light mode explicitly**: `Theme.C` carries
  both appearances, and a PDF exported at night would otherwise be near-white ink on
  white paper. A free account gets a watermarked preview holding day one, with the
  remaining days named rather than silently dropped.
- **The paywall is both PRD 4.1 variants (F-09).** Which one appears comes from
  `Wallet.exportOutlook`, so the traveller sees the sheet they are about to get with
  no flicker. StoreKit 2, with restore. The sheet never blocks the door — the
  watermarked preview is shareable from inside it, unbought.
  **Receipts are not verified**: StoreKit saying *verified* means Apple signed the
  transaction, not that the account is entitled. That decision belongs to the server,
  and `InMemoryEntitlementServer` is the server, faked — the same pretence as
  `StubAuthenticationService`, to be deleted the day a backend exists.

- **Reels and TikToks come in through the share sheet.** Nobody starts a trip in a
  trip planner; they start in a Reel, and Wanderlog has no way in from one on iOS.
  Share a post into Vihara and the places named in its caption are waiting on Home.
  **The extension captures and nothing else** — it writes a link and whatever text
  came with it to the App Group, and the app does the matching, because that is where
  the vocabulary and the memory are. See [`ViharaShare/`](ViharaShare/) and
  [`CaptureInboxViewModel`](Vihara/Features/Home/CaptureInboxViewModel.swift).

  What it can and cannot read is worth knowing before judging it: **TikTok** publishes
  an unauthenticated oEmbed endpoint that returns the caption, so a bare TikTok link
  resolves. **Instagram and Reels** have required an access token for oEmbed since
  2020, so a bare Reel link resolves to nothing and the sheet says so plainly rather
  than shrugging. Closing that gap needs a backend holding a token, not more client
  code.

  Matching is vocabulary-based and deliberately has a ceiling: it finds the 285 cities
  and the curated destinations, including hashtags (`#bologna`) and endonyms
  (`Firenze` → Florenz), and it refuses to guess. A caption saying "this little place
  near the market" names a restaurant no vocabulary holds, and inventing one would put
  a place in a plan that nobody can visit — the exact failure `Place`'s validation gate
  exists to prevent.

Jump straight to a screen while iterating:

```bash
xcrun simctl launch booted com.vihara.app -vihara-route plan
```

### Testing purchases without App Store Connect

`Vihara.storekit` sits at the repository root and the shared scheme already points at
it, so the paywall has real products, real prices and a real purchase sheet in the
simulator with no account and no configured app.

It lives **outside** `Vihara/` deliberately: that folder is a synchronized group, so
anything inside it is copied into the app bundle, and a StoreKit test configuration is
a development artefact that must never ship.

To exercise the states App Review will: **Debug → StoreKit → Manage Transactions**
while running, where a purchase can be refunded, a subscription expired, or
ask-to-buy turned on. `_failTransactionsEnabled` in the file forces failures.

**The configuration is attached by the scheme, so it only applies when you run from
Xcode.** A build launched with `xcrun simctl launch` has no store at all: `prices()`
returns `[:]` and the paywall says the store is not answering, which is the same path
a real device takes when the App Store is unreachable. That is worth seeing
deliberately — it is a state travellers will hit — but do not mistake it for a bug in
the paywall.

### The App Group, which is a provisioning dependency

The extension and the app hand captures through `group.com.vihara.app`, declared in
[`Vihara/AppGroup.entitlements`](Vihara/AppGroup.entitlements) and wired for both
targets. **The simulator works immediately.** A device build needs the group
registered on both App IDs (`com.vihara.app` and `com.vihara.app.share`) and enabled
for both targets, or `containerURL(forSecurityApplicationGroupIdentifier:)` returns
`nil` and every capture is silently lost.

That is the same trap the Sign in with Apple section below describes, so it is handled
the same way: `SharedInbox.isAvailable` exists and the extension *says* it cannot save
rather than appearing to succeed.

`AppGroup.entitlements` is deliberately separate from `Vihara.entitlements`. A target
has one entitlements file, and the latter carries Sign in with Apple, which is not
wired on purpose — merging them would break device builds for two reasons instead of
one. When Sign in with Apple is finally switched on, the two should be merged.

To check the container really exists:

```bash
xcrun simctl get_app_container booted com.vihara.app groups
```

## Signing in, and the two keys you need

The app is gated: nothing past the Welcome screen is reachable without an account.
`RootView` resolves **every** route to `AuthView` while signed out, including a deep
link — a check written into a button would miss exactly that case.

Three ways in. Two of them need configuration you have to supply:

```bash
cp Vihara/Secrets.example.plist Vihara/Secrets.plist   # git-ignored
```

| Key | Where it comes from | Without it |
|---|---|---|
| `GooglePlacesAPIKey` | Google Cloud → Credentials → API key, with **Places API (New)** enabled | Place search falls back to the curated catalogue |
| `GoogleOAuthClientID` | Same console → OAuth client ID, type **iOS** | The Google button is disabled and says why |

**Restrict the Places key** to iOS apps and to `com.vihara.app` before it goes near a
build anyone else can run. A key inside a shipped app is extractable, and Places bills
per request.

For Google sign-in you must also add the reversed client id as a URL scheme under
`CFBundleURLTypes` (`com.googleusercontent.apps.…`), or the browser has nowhere to
hand the authorisation code back to. The flow itself is Authorization Code + PKCE
through `ASWebAuthenticationSession` — no SDK, so the no-dependencies promise holds.

**Sign in with Apple is not switched on yet, deliberately.** The entitlement file
exists at `Vihara/Vihara.entitlements`, but nothing references it — wiring it up
before the capability is enabled on the App ID fails *every device build*:

```
Provisioning profile "iOS Team Provisioning Profile: com.vihara.app"
doesn't support the Sign in with Apple capability.
```

The entitlement and the portal have to be turned on together, and Xcode does both in
one step: target **Vihara** → **Signing & Capabilities** → **+ Capability** →
**Sign in with Apple**. That writes `CODE_SIGN_ENTITLEMENTS` and updates the App ID.

Until then the Apple button is visible and reports that it is unavailable rather than
failing silently — the cancel case and the missing-capability case are told apart in
`AuthView.handleApple`, because a button that appears to do nothing is worse than
either.

### Signing in while there is no backend

```
vihara-app@gmail.com  /  vihara007
```

Seeded into the credential store on first use rather than special-cased at the
sign-in call, so it walks the whole path — salt, hash, compare, session, Keychain —
instead of stepping around it. A wrong password against that address is refused like
any other. When `POST /v1/auth/*` exists, `seedDemoAccountIfNeeded()` is the only
thing that has to be deleted.

### What is real, and what is not

Apple and Google authenticate for real. **Nothing verifies their tokens**, because
verification belongs on a server and there is no server — see
`StubAuthenticationService`, which is a stub in the same sense `StubTripGenerator` is.
Email accounts are stored on the device: salted SHA-256 in the Keychain, which is
enough that a stolen phone does not hand over a plaintext password and nowhere near
enough for a real account system. That wants a slow KDF and a backend.

Jump past the gate while iterating:

```bash
xcrun simctl launch booted com.vihara.app -vihara-route home -vihara-signed-in Sanya
```


## Opening and running

The `.xcodeproj` is checked in and hand-written — there is no XcodeGen or other
generation step, and nothing to install first.

```bash
open Vihara.xcodeproj
```

To run on your iPhone: plug it in, pick it from the device menu in the toolbar, then
select the **Vihara** target → **Signing & Capabilities**. Automatic signing is on and
`DEVELOPMENT_TEAM` is set to the team the project was created under — change it to
yours in that pane. Press ⌘R.

The bundle id is `com.vihara.app`; change it in the same pane if it collides with
something already on your account.

To build and test without opening Xcode:

```bash
xcodebuild -project Vihara.xcodeproj -scheme Vihara -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test
```

## Swapping the placeholder colours for real photographs

The asset catalog ships solid muted-green PNGs so the app runs before any
photography exists. Each image set is configured as a **single-scale universal
image**, so replacing one is a single-file drop — no `@2x`/`@3x` variants needed:

```
Vihara/Resources/
  welcome_loop.mp4                                Screen 1's looping backdrop
Vihara/Assets.xcassets/
  welcome_bg.imageset/welcome_bg.jpg              poster frame of the clip above
  dest_bologna.imageset/dest_bologna.png          portrait ~3:4, rail — placeholder
  top_modena.imageset/top_modena.png              square, 52pt thumb — placeholder
  top_ravenna.imageset/top_ravenna.png            placeholder
  dest_formentera.imageset/dest_formentera.jpg    real photo, currently unused
  dest_sansebastian.imageset/dest_sansebastian.png  placeholder, currently unused
```

The last two belong to destinations in `awaitingCuration`, so nothing draws them yet.
They stay in the catalog because the expensive half of adding a region is the POI
index, not the artwork.

**The three placeholders above are a submission blocker, not a cosmetic one.** Apple
rejects placeholder assets, and `AppIcon.png` is one too.

**Screen 1 plays a video, not a still.** `welcome_loop.mp4` loops silently behind the
headline; `welcome_bg` is a frame taken from it, and sits underneath the player at all
times — it covers the moment before the first frame decodes, it is what someone with
Reduce Motion sees, and it is the fallback if the clip is ever missing. Swapping the
clip means regenerating the poster too, or the two will not match — so do both at
once, from the repository root:

```bash
Scripts/prepare-welcome-clip.swift ~/Desktop/my-clip.mp4
```

That strips the audio track (passthrough, no re-encode) and writes a fresh poster
frame. Do not skip the audio strip: a backdrop that still carries an audio track can
make `AVPlayer` claim the audio session and stop whatever the traveller is listening
to.

Drop your photograph in with **the same filename**, or drag it onto the image set in
Xcode's asset catalog editor. Everything is drawn with `.scaledToFill()` inside a
clipped container, so aspect ratio is forgiving — match the rough shape noted above
and the crop takes care of itself. Supply roughly 3× the point size (Screen 1 wants
~1200×2600) so it stays sharp on a Retina display.

Every image goes through
[`AssetImage`](Vihara/DesignSystem/Components/AssetImage.swift), which
keeps a muted fill behind the photo. A missing or misnamed asset degrades to that
colour field instead of collapsing the layout, so a typo during the swap will not
break the build or the screen.

## Retuning the design

Everything lives in [`Theme.swift`](Vihara/DesignSystem/Theme.swift) and
[`PlanTokens.swift`](Vihara/DesignSystem/PlanTokens.swift). No other file contains a
literal hex value, font size, corner radius or spacing constant — the hex initialiser
is deliberately `fileprivate` so it cannot leak out, and `check-layers.sh` fails the
build if one escapes.

**There are two token sets, and that is a live design question.** `Theme` is the
browsing surface: photo cards, 22–34pt radii, a 4pt grid. `Theme.Plan` is the
planning surface as PRD §5.2 specifies it: a 5pt grid, 2pt radius, three type sizes,
no card boxes, no rules — separation by whitespace alone. Either Discover adopts the
plan tokens or we accept the split deliberately; it is on the open-questions list
rather than left to drift.

Every colour carries both appearances. Dark mode is required at launch, and the app
no longer pins itself to the light appearance.

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

- **The plan screen's primary action is sharing, not exporting.** The watermarked PDF
  (F-08) and the paywall (F-09) are the next slice; the entitlement logic behind them
  is implemented and tested in `Wallet.exportOutlook(for:)`, so the remaining work is
  the paywall UI and RevenueCat.
- **The catalogue only offers what it can plan.** `PilotDestinationCatalogue` splits
  `curated` from `awaitingCuration`, and every read path serves the former. Formentera
  and San Sebastián have photography and metadata but no POI index, so they are not
  offered — a card that cannot produce a plan is worse than no card. A test fails the
  build if a served destination has no itinerary behind it.
- **Editing is not built.** Drag, swap, delete and pin (F-05/F-06) come next. The
  constraint engine they need — `ItineraryRules` — is done and tested.

- **`DiscoverView` does not scroll vertically** — by design. Only the two horizontal
  rails scroll, so at large Dynamic Type the rails simply scroll further.
- **The bottom nav shows two items, because two screens exist.** *Merkliste* and
  *Profil* had no feature and no destination behind them; inert primary navigation
  reads as a broken app. `BottomNav` itself is unchanged and still adapts in tiers
  (`ViewThatFits`: distributed → tight → one type step down → horizontally scrollable
  at full size), so it holds four labels again the day two more screens exist.
- **Category tabs are interactive.** The brief only called for `Kulinarik` to be
  active, but a tab row that does not respond reads as broken in a prototype, so the
  selection is `@State`-driven like the nav.
- The header's `Su` / `Ne` buttons and `Alle ansehen` are tappable but have no
  destination yet.
- **`PrivacyInfo.xcprivacy` declares nothing collected and nobody tracked**, which is
  true today: no account, no analytics, no advertising identifier. It ships in the app
  bundle. When the backend lands, whatever it receives has to be added there *and* to
  App Store Connect's privacy answers, and the two must agree.
- **`APIConfiguration.localhost` is `#if DEBUG`.** App Transport Security blocks
  cleartext HTTP in a release build, and there is deliberately no ATS exception to
  lean on — shipping against a real server means an `https` base URL.
