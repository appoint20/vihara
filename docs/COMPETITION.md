# Where Wanderlog stops

Vihara's competitor is **Wanderlog** (wanderlog.com) — assumed from "Wunderlog"; the
name in the brief matches no shipping product. Correct this before anyone quotes the
document.

A warning about the evidence below. Almost every "Wanderlog review 2026" on the open
web is published by a competing trip planner and ranks itself first. The complaints
are therefore treated as *hypotheses to verify*, not findings — the column that
matters is **Verified**, and it is empty until someone on this team has installed the
app and reproduced the behaviour. Two weeks of a paid Wanderlog Pro account is the
cheapest research this project can buy.

## What Wanderlog is good at — do not attack these

| | Why it is not worth fighting |
|---|---|
| **Free tier breadth** | Reviewers call it the most complete free tier in the category. Competing on free scope is competing on their strength with none of their scale. |
| **Live group collaboration, free, cross-platform** | iOS + Android + web, real-time. This is a backend and a platform bet. It is Vihara's F-13, Phase 4, and it should stay there. |
| **Booking-confirmation import** | Flight and hotel confirmations parsed out of Gmail into the trip. Mature, and it needs mail access Vihara has no reason to ask for yet. |
| **Road-trip driving times** | Long-standing strength, well reviewed. |

Vihara is **iOS-only, German-first, one region**. Against a cross-platform incumbent
with a free tier, breadth is a losing axis. Depth on a narrow promise is not.

## The gaps, ranked by whether Vihara can own them

| # | Gap in Wanderlog | Evidence | What Vihara does instead | Built? | Verified? |
|---|---|---|---|---|---|
| 1 | **AI suggests, it does not compose.** The assistant proposes places the traveller then places by hand; it will not hand back a finished itinerary. | Multiple 2026 reviews; one tester reports the AI cannot even add a place to the map from chat | One sentence in, a day-by-day plan out. The whole premise. | F-01/F-02 running on a stub | ☐ |
| 2 | **Nothing guarantees a place is real or open.** User- and AI-added POIs, no validation gate. The category's standard failure is a confident plan built on a closed restaurant. | Inherent to the model; the common AI-planner complaint | `Place` cannot be constructed without having passed validation — there is no unverified state to render. `checkedAt` is what earns the word *bestätigt*. | By construction; F-03 needs the backend | ☐ |
| 3 | **No dietary intelligence.** Vegan, halal, coeliac travellers get a generic plan. | Absent from every feature list | `DietSignal` separates *bestätigt* from *wahrscheinlich*, and only a provider attribute or a read menu may claim the former. A test fails the build if sample data overclaims. | **Done and tested** | ☐ |
| 4 | **No way in from TikTok, Reels or Instagram.** Places saved in social apps must be re-typed by hand. | Named explicitly in reviews as a missing path | A **Share Extension**: share a post into Vihara and the places named in its caption are waiting on Home. | **Built** · TikTok captions resolve through oEmbed; Instagram's needs a backend token | ☐ |
| 5 | **Budgets are manual.** Every cost typed by hand, no currency conversion, no estimates. | Consistent across reviews | The plan already knows the places, the admissions and the dates. The budget should compose itself. | `Admission`/`PriceBand` exist; `Money` is **EUR-only** | ☐ |
| 6 | **Offline is paywalled.** Along with route optimisation and live flight updates, roughly $40/yr. | Reported pricing, one 1-star review calls it a scam | Vihara is offline-first by architecture. **Keep offline free** — it is the cheapest marketing claim available, because it is already true. | F-14 real: `FileTripRepository` | ☐ |
| 7 | **It gets slow.** The single most-cited complaint; degrades as a trip fills. | Traces to a 2024 Reddit thread — may be dated | Native SwiftUI, zero dependencies, streaming one day at a time. Structural, not an optimisation to do later. | Structural | ☐ |
| 8 | **Overwhelming UI.** Feature-dense; reviewers say the interface gets in the way. | Recurring | "Kein Tab-Bar-Zoo". The plan surface separates by whitespace alone — no cards, no rules. Two nav items, because two screens exist. | Done | ☐ |
| 9 | **No ticket intake from Viator / GetYourGuide.** | One Trustpilot review | If Vihara *sells* the ticket (see [MONETISATION](MONETISATION.md)) it owns the confirmation and never needs an upload path. A gap that monetisation closes for free. | Follows from affiliates | ☐ |
| 10 | **No metric/imperial switch.** | One Trustpilot review | Trivial. Named only because it shows the long tail is unattended. | Not started | ☐ |
| 11 | **Accessibility is not modelled.** No step-free data, no minimum ages. | Absent | `Place.isStepFree` is `Bool?` on purpose — unchecked is not the same as false. `minimumAge` stops a plan sending a family with a 7-year-old to a tower that refuses under-12s. | Modelled | ☐ |

## The three wedges

Nine gaps is a backlog, not a strategy. Three of them are worth the first year.

1. **Composed, not suggested** (#1 + #2). The plan arrives finished and every place in
   it resolved. This is the product and it is already most of the way built on a stub.
   Its cost is a backend, and that is the real schedule.
2. **Constraints nobody else honours** (#3 + #11). Diet, age, step-free. A vegan
   coeliac travelling with a parent who cannot manage stairs is badly served by every
   planner on the market, searches with high intent, and tells people. Already built,
   already tested, and currently unmarketed — the cheapest wedge on this list.
3. **Social is the front door** (#4). Nobody starts a trip in a trip planner; they
   start in a Reel. A Share Extension that turns saved video into planned days is both
   the acquisition channel and a feature the incumbent cannot quickly copy on iOS.
   **Built**, with one honest limit: TikTok publishes an unauthenticated oEmbed
   endpoint so its captions resolve, while Instagram has required a token since 2020
   and resolves only from text the share sheet happened to carry. The Instagram half
   is a backend task, not a client one, and it is the single highest-leverage thing
   the first backend could add to this wedge.

## What not to build

- **Flight search.** Pays ~1–4%, is booked before anyone plans days, and competes with
  Google Flights. See [MONETISATION](MONETISATION.md).
- **Real-time collaboration** before Phase 4. It is their strength and a backend.
- **Android**, until ADR-001 is actually decided. The PRD says Flutter; the code is
  native. That contradiction is still open and gets more expensive every week.
- **A breadth race on the free tier.**
