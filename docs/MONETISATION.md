# How Vihara earns

The brief: *"I mainly want to earn money with affiliate — if a user clicks or books
via the app I get paid by Booking or other portals."*

Three corrections before the plan, because each one changes what gets built.

## 1. You are paid per booking, not per click

Travel affiliate programmes are CPA, not CPC. Booking.com, GetYourGuide, Viator and
Expedia all pay on a **completed, consumed** booking — and in Booking.com's case on a
share of *their* commission, not of the trip price, which nets a partner roughly 4–8 %
of booking value. A few metasearch brands inside Travelpayouts still pay per click,
but the rates are cents and the volume needed is not a thing an indie app has.

Practically: a cancelled hotel pays nothing, a stay pays 30–60 days after checkout,
and payout minimums are typically $50. **Budget for money arriving one to three months
after the traveller returns**, not when they tap.

## 2. A day planner is the wrong place to sell a hotel

This is the most important conclusion in the document, and it follows from the
product, not from the rate cards.

People book accommodation **before** they plan their days. By the time someone opens a
day-by-day itinerary, the hotel is already booked and the flight is already flown. A
booking button sitting next to *Vormittag: Uffizien* is selling to a traveller who has
nothing left to buy.

What a day planner is uniquely good at selling is **what the plan itself implies**:

| Rank | Surface | Rate | Why it fits | Hook in the code today |
|---|---|---|---|---|
| **1** | **Attractions & activities** (GetYourGuide, Viator, Klook) | ~8 % | Every plan block *is* an activity, with a date and a city. GetYourGuide is Berlin-based and strongest exactly where this app is. | `Place.requiresTicket` |
| **2** | **Accommodation, at intake only** (Booking.com) | ~4–8 % effective | Highest value per booking by far. Worth ~€30 on a €600 stay — but only if asked *before* the plan exists. | `TripBrief`, intake |
| **3** | **Transfers & rail** (Trainline, Omio, DiscoverCars, Welcome Pickups) | ~4–6 % | The plan already knows city A, city B and the date. | `Transfer.Option.partner` — **already modelled** |
| **4** | **eSIM & insurance** (Airalo, hedgehog-type insurers) | ~10–15 % / flat fee | Cheap, late, impulse. Highest conversion of anything here because the decision is €20, not €600. | None yet |
| **5** | Restaurant reservations | ~0 | Mostly unpaid in the EU. | — |
| **—** | **Flights** | ~1–4 % | Booked first, lowest rate, competing with Google. **Do not build flight search.** | — |

The single cheapest monetisation change available: `Place.requiresTicket` currently
carries the comment *"surfaced as a warning, not a booking button."* Every place in
the catalogue with `requiresTicket == true` is a GetYourGuide commission the app
currently **warns the traveller about instead of earning from**. That is one UI
component and one link builder away from revenue.

## 3. The honest arithmetic

Industry benchmarks, not Vihara data. They conflict by an order of magnitude between
sources, so these are planning figures to be replaced by measurement as fast as
possible. Assumptions: 0.6 plans per active user per month, 80 % of plans carry at
least one offer, 20–30 % of travellers tap one, 3 % of taps convert.

| Monthly actives | Activities | Hotel at intake | Transfer + eSIM | **Total / month** |
|---|---|---|---|---|
| 1 000 | ~€17 | ~€52 | ~€21 | **~€90** |
| 10 000 | ~€170 | ~€520 | ~€210 | **~€900** |
| 100 000 | ~€1 700 | ~€5 200 | ~€2 100 | **~€9 000** |

That is roughly **€0.50–1.50 per active user per year**.

Two things follow:

- **At launch scale, affiliate revenue will not pay for the backend.** A thousand users
  is a hobby income. Nobody should be surprised by this in month three.
- **At every scale, it is worth about the same as a small subscription** — a €3.99/mo
  plan converting 4 % yields ~€1.90 per active user per year. Affiliate takes no 15–30 %
  Apple cut, needs no paywall, and costs no retention.

So the answer is not affiliate *instead of* the PRD's credits model. It is **both**,
with affiliate shipped first — see the sequencing argument below.

## 4. Who will actually approve an unlaunched app

This is the part with a lead time, and the current roadmap has it in the wrong phase.

Booking.com restructured in 2025 and now routes most small partners through the
networks **CJ** or **Awin** rather than direct, with approval set by the network. The
consistent criteria across every account: a **real property with real content and
organic traffic**, plus compliant affiliate disclosure. Their connectivity/Demand API
is partner-gated and was not accepting new registrations as of mid-2026 — assume no
API, deep links only.

An App Store listing that does not exist yet is not a property. **Vihara cannot be
approved for Booking.com today.** Therefore:

| Partner | Accepts a pre-launch iOS app? | Route | Do this |
|---|---|---|---|
| **Travelpayouts** | Yes — explicitly courts developers and travel startups; aggregates 100+ brands incl. Booking.com and GetYourGuide under one account; up to ~7 % | Direct | **Apply first, this week.** One integration, many brands, no launch requirement. |
| **GetYourGuide Partner** | Usually | Direct | Apply in parallel — it is surface #1 and the best fit. |
| **Viator** | Usually | Direct | Backup/complement to GYG for coverage gaps. |
| **Awin** | Needs a property | Network | Needs step 0.2 below first. |
| **CJ** | Needs traffic | Network | After launch, with real numbers. |
| **Booking.com direct** | No | Via CJ/Awin | Revisit at ~10k MAU. |

Travelpayouts is the unlock: it converts "get approved by six companies" into "get
approved by one", and it is the only one that will say yes before the app ships. Its
published white-label app is Android-only and irrelevant here — Vihara wants the
**deep links**, not the template.

Note one real technical cost: Travelpayouts attributes app-originated clicks through
**AppsFlyer**. That is an SDK, and the project's standing promise is zero
dependencies. See the decision list.

## 5. Architecture

Five rules. The first is the one that matters.

### Affiliate links are server-authoritative

No affiliate ID, tracking marker or partner URL template ships inside the binary.
The client asks for offers and receives opaque URLs it opens. Reasons, in order:

1. A shipped client cannot be changed when a programme terminates, a marker rotates,
   or a partner's terms change. App Review takes days; an affiliate account can be
   closed in an hour.
2. Commission splitting and partner A/B tests become config, not releases.
3. Click logging for EPC measurement happens server-side, so **no analytics SDK is
   needed to learn which surfaces convert**.

This mirrors [ADR-004](adr/004-server-authoritative-entitlements.md) exactly — the
client cannot spend, and the client cannot construct a payable link. Written up as
[ADR-006](adr/006-affiliate-links-server-authoritative.md).

### Open in `SFSafariViewController`, not `ASWebAuthenticationSession`

[ROADMAP.md](ROADMAP.md) currently specifies `ASWebAuthenticationSession` for F-10.
**That is the wrong API and it will cost conversions.** It exists for OAuth and
presents a system consent alert — *"Vihara" Wants to Use "booking.com" to Sign In* —
before the page loads. A traveller tapping *Ticket ansehen* is not signing in, and an
unexplained permission dialog at the top of a funnel is a funnel that does not convert.

`SFSafariViewController` is the correct surface: no alert, real Safari engine, shared
cookie store across presentations **within the app**, and the traveller stays in
Vihara.

### Keep the whole click-to-book flow in one browser context

Attribution is a cookie in whatever browser context the click happened. Since iOS 11
`SFSafariViewController` has a data store separate from Safari, so a click here and a
purchase in Safari later is **an unattributed, unpaid booking**.

The sharper version of the same problem: **universal links.** An affiliate
`booking.com` URL on a device with the Booking.com app installed can be intercepted by
that app, which drops the affiliate cookie entirely. Those are exactly the
high-intent users. Mitigating it properly needs app-to-app attribution — which is what
Travelpayouts' AppsFlyer requirement is for. Until that is decided, **measure the
leak** before paying an SDK to fix it.

### One sub-ID per click, carrying no identity

Each click-out carries an opaque sub-ID so revenue attributes back to the surface that
produced it — *which block, which partner, which position*. It must be a salted hash
of `(trip, slot, partner)`, never a user ID, device ID or anything re-identifiable.
This is how surface #1 vs #2 above stops being a guess.

### The plan must be complete with zero offers

Non-negotiable, for both review and product reasons — see below.

## 6. Compliance

| Risk | Rule | What it means here |
|---|---|---|
| **Rejection as a link aggregator** | **4.2.2**: *"apps shouldn't primarily be marketing materials, advertisements, web clippings, content aggregators, or a collection of links"* | The real App Store risk — not IAP. A limo app was rejected under 4.2 for a booking flow that depended on a third-party platform. Vihara is safe *because* the plan is the product and offers are additive. Never let a plan's value depend on an offer. |
| Paying for bookings | **3.1.3(e)**: physical goods/services consumed outside the app **must not** use IAP | Travel bookings are exactly this. Affiliate link-outs are the sanctioned path, in every storefront. Not a grey area. |
| Vihara's own credits | **3.1.1**: unlocking features in-app requires IAP | **Built** — `StoreKitPurchases`, StoreKit 2, with restore. The two revenue streams follow opposite rules and the code keeps them apart: IAP for credits, `SFSafariViewController` link-out for bookings. |
| Anti-steering | 3.1.1(a) | Applies to *digital* purchases, with a US-storefront exception. Irrelevant to booking link-outs; relevant the day credits are sold. |
| **DSGVO / TTDSG** | German-first app | Affiliate click tracking with sub-IDs, and certainly AppsFlyer, need **consent before the first call**. Not a launch-week afterthought. |
| **Werbekennzeichnung** | §5a UWG + every network's T&Cs | Booking buttons must be labelled as paid placement, in German, visibly. One `DesignSystem` component, used everywhere, no exceptions. |
| Privacy manifest | `PrivacyInfo.xcprivacy` | Currently declares **nothing collected, nobody tracked**. True today, false the day a sub-ID ships. It and the App Store Connect answers must change together and agree. |
| Stale prices | Preisangabenverordnung | A wrong price is a legal problem as well as a conversion problem. Prices render from a server call at display time, or the app shows a band, never a cached number. |
| Network T&Cs | All | No bidding on partner brand terms, no cookie stuffing, no incentivised clicks. Any of these closes the account. |

## 7. The sequencing change

The PRD puts the paywall (F-09) in Phase 2 ahead of affiliates (F-10), with
applications in Phase 1. **Swap them.** Affiliates go first, for four reasons:

1. **Approval has a lead time measured in weeks**, and may be refused pre-launch.
   Starting the applications is free and must happen now regardless.
2. **Affiliate needs no pricing decision.** The paywall needs a price, a tier
   structure, RevenueCat, StoreKit, and a view on what a plan is worth — none of which
   anyone knows yet.
3. **Affiliate revenue is measurable without asking anyone to pay Vihara.** Real EPC
   from real travellers is the number that tells you whether the subscription is even
   necessary, and at what price.
4. **It carries no review risk** under 3.1.3(e), where the paywall carries 3.1.1 risk.

Blocking decision 3 in [ROADMAP.md](ROADMAP.md) — whether the free tier needs a PDF
viewer — gets cheaper to answer too: if affiliate ARPU holds up, the watermarked
preview is not worth building.

## 8. The step-by-step plan

### Step 0 — This week. No code.

| | Task | Why it is first |
|---|---|---|
| 0.1 | **Apply to Travelpayouts, GetYourGuide and Viator** | Weeks of lead time. Nothing downstream is real without it. |
| 0.2 | **Stand up a public property**: a landing page plus three destination guides for the pilot region | The literal approval requirement for Awin/CJ/Booking.com. Doubles as ASO and as the pilot region's curation output. |
| 0.3 | **Buy two weeks of Wanderlog Pro and fill the Verified column** in [COMPETITION.md](COMPETITION.md) | Every gap in that document is currently a competitor's blog post. |
| 0.4 | **Answer ADR-001: native or Flutter** | The code says native, the PRD says Flutter. It gets more expensive every week and it decides whether Android exists. |
| 0.5 | **Pick the pilot region** (Italy or Spain — ROADMAP decision 2) | Gates curation, and curation is the one irreducibly manual cost. |

### Step 1 — ~~Weeks 1–3~~ **Done.** Client only, no backend, no approvals.

The bookable domain layer, against stubs. This is real, shippable, testable work that
depends on nothing outside the repo.

- `BookableOffer` in `Domain/Model` — partner, `PriceBand`, an opaque URL, a label.
  Pure Swift, per [ADR-003](adr/003-domain-purity.md).
- Extend `AffiliatePartner` beyond today's four; attach offers to `ItineraryItem` and
  to `Place.requiresTicket`.
- `OfferProviding` protocol in `Domain/Repositories`, a stub implementation in
  `Data/Stubs` — the same pattern `StubTripGenerator` already establishes.
- `DesignSystem` components: the offer row and the **mandatory disclosure label**.
- `SFSafariViewController` presentation + click reporting, behind a protocol.
- Tests: a plan renders completely with zero offers; disclosure is present on every
  offer; no offer can be constructed without one.

**Exit — met.** A stubbed GetYourGuide offer sits under every `requiresTicket` place
in the shipped sample itinerary, and the plan still reads correctly with the offer
provider set to `nil`. Both are pinned by tests (`SampleDataOfferTests`,
`planIsCompleteWithoutOffers`), and `check-layers.sh` now fails the build if an
affiliate marker ever reaches the binary.

What landed beyond the original scope: the hand-off uses `SFSafariViewController`
with the URL scheme checked before presentation, click reporting is behind
`OfferClickReporting` and never awaited, and the disclosure label has no initialiser
that omits it.

### Step 2 — ~~Weeks 2–4~~ **Done.** The smallest possible backend.

Not the AI backend. A link service: `GET /v1/offers?place=…&date=…` returns offers;
`POST /v1/clicks` logs one. A Cloudflare Worker and a table will do. It holds the
affiliate markers, builds the deep links, and logs clicks for EPC.

**Exit — met, except for the markers themselves.** [`services/offers/`](../services/offers/)
is a Cloudflare Worker with no dependencies: `GET /v1/offers`, `GET /go/:token`,
`POST /v1/clicks`, 33 tests under `node --test`. `AppDependencies.live` points at it.
Clicks go to the log until a table is bound, which is enough to count EPC.

Three things worth knowing before it earns anything:

- **It mints a redirect, not a partner link.** `/v1/offers` returns a URL on our own
  origin; the marker is attached at `/go/:token`, server side. So a marker never
  reaches the client even in a response, and a link can be rotated after it was
  handed out. Tokens are HMAC-signed with constant-time comparison and expire, and
  the redirect target is checked against a host allowlist — a leaked signing key must
  not become an open redirect in a phishing mail.
- **Tap and arrival are logged separately**, and the gap between them *is* the
  attribution leak ADR-006 says to measure before paying for an SDK. Only logging the
  redirect would make that leak invisible.
- **Half the affiliate parameter names are unconfirmed.** GetYourGuide's `partner_id`
  and Booking.com's `aid` come from their own documentation. Viator, Trainline,
  Welcome Pickups and Airalo are placeholders marked `confirmed: false`, and a partner
  with no marker configured is not offered at all. **Check each against the partner's
  own dashboard before sending traffic**: a wrong parameter does not fail — the link
  works, the traveller books, and nobody is paid. That is the worst failure mode in
  this document, because it is invisible.

### Step 3 — Weeks 3–6. Curation, with product IDs attached.

The real POI index for the pilot region — and while curating, **attach the GYG/Viator
product ID to every ticketed place**. Doing it in the same pass costs almost nothing;
doing it later means curating twice.

**Exit:** ≥95 % of POIs pass live validation (the PRD's own Phase 0 gate), and every
`requiresTicket` place has an offer behind it.

### Step 4 — Weeks 6–8. Ship it.

TestFlight, then the App Store, with affiliates live and no paywall. Blockers that are
already known and are not negotiable: the three placeholder images and `AppIcon.png`
are **rejections**, not cosmetics; Sign in with Apple must be enabled in the portal and
the entitlement together; EN alongside DE.

**Exit:** approved, and the first click-outs measured.

### Step 5 — Weeks 8–12. Measure, then decide.

The paywall it refers to now exists (F-09), so this step is no longer blocked on
building one — only on having real click data to price against. What is still missing
is the receipt verification that makes a purchase mean anything: today the ledger is
`InMemoryEntitlementServer`, in process, and anyone who can edit memory can grant
themselves an export.

Real EPC per surface. The ranking in §2 is a hypothesis — the data may well say
activities beat hotels, or that the intake hotel question annoys more than it earns.

**Then** decide the paywall, with numbers: if affiliate ARPU clears ~€1.50/user/year,
price the subscription as an add-on; if it is under €0.50, the subscription is the
business and affiliate is garnish.

### Step 6 — Ongoing, in parallel. The wedges.

Only after revenue is instrumented, in [COMPETITION](COMPETITION.md) order:
Share Extension for social import (#4, the acquisition wedge) → auto-budget and
multi-currency (#5, which needs `Money` to stop being EUR-only) → market the diet and
accessibility constraints that are **already built and currently unmarketed** (#3, #11).

## 9. Decisions needed from you

| # | Decision | Default if you say nothing |
|---|---|---|
| 1 | Is the competitor really **Wanderlog**? | Assumed yes throughout both documents |
| 2 | **AppsFlyer** for app-to-app attribution — or keep the zero-dependency promise and accept the leak on users with partner apps installed? | Measure the leak first, add nothing |
| 3 | Affiliates **before** the paywall, as argued in §7? | Yes — swap F-09 and F-10 |
| 4 | Who builds and hosts the link service in Step 2? | Unowned, and it blocks Step 3 |
| 5 | Who owns **per-region curation**? Still unowned and unestimated ([ROADMAP](ROADMAP.md) disagreement 5) | Unowned, which is why it will slip |
| 6 | Hotel offer at intake — does asking "schon gebucht?" fit the No-Cockpit rule? | Build it, measure it, remove it if it earns nothing |
