# ADR-006 — Affiliate links are server-authoritative; the client cannot construct a payable URL

**Status:** accepted — implemented on both sides; markers still to be confirmed
**Date:** 2026-10-23

## Decision

No affiliate ID, tracking marker, partner URL template or commission rule ships inside
the binary. `BookableOffer` carries an **opaque** URL the client only opens; the client
can render an offer, open it, and report the click, and nothing else.

The surface used to open it is **`SFSafariViewController`**, not
`ASWebAuthenticationSession`.

Each click-out carries one sub-ID: a salted hash of `(trip, slot, partner)`. Never a
user id, device id, IDFA, or anything re-identifiable.

## Why

Three independent reasons, each sufficient on its own.

**Commercial.** A marker baked into a shipped build cannot be changed when a programme
terminates, a network migrates, or terms change. Booking.com restructured its
programme in 2025 and rerouted small partners through CJ and Awin; a client holding its
own links would have shipped dead links and earned nothing until the next release
cleared review. App Review takes days. An affiliate account can be closed in an hour.

**Measurement.** If the server mints every link and logs every click, EPC per surface
is known without an analytics SDK in the app. The ranking of booking surfaces in
[MONETISATION §2](../MONETISATION.md) is a hypothesis, and this is what tests it. It
also keeps `PrivacyInfo.xcprivacy` honest for longer.

**Symmetry with [ADR-004](004-server-authoritative-entitlements.md).** The client
cannot spend money and the client cannot mint a link that earns money. Both are
expressed as type structure rather than as a convention, so the mistake cannot be made
by accident: there is no template to fill in.

### Why not `ASWebAuthenticationSession`

[ROADMAP.md](../ROADMAP.md) Phase 2 names it for F-10. It is the wrong API. It exists
for OAuth, and it presents a system consent alert — *"Vihara" Wants to Use
"booking.com" to Sign In* — before the page loads. A traveller tapping *Ticket
ansehen* is not signing in. An unexplained permission dialog at the top of a
conversion funnel suppresses that funnel, and the one thing F-10 exists to do is
convert.

`SFSafariViewController` presents no alert, runs the real Safari engine, shares a
cookie store across presentations within the app, and returns the traveller to Vihara.

## Consequences

- **Enforced, not hoped for.** `Scripts/check-layers.sh` fails the build if a marker
  (`aid=`, `marker=`, `partner_id=`, `utm_source=`, …) appears in any Swift file
  outside a comment.
- **The link service exists**: [`services/offers/`](../../services/offers/), a
  dependency-free Worker tested with `node --test`. It mints a redirect on our own
  origin rather than a partner link, so the marker never appears in a response at all
  — stronger than this ADR originally asked for. Its tests pin that invariant, and
  pin that a validly-signed token for an unknown partner does not redirect.
- **A link service is a prerequisite for F-10**, and it is not the AI backend. Two
  endpoints — offers out, clicks in — sized like a Cloudflare Worker. It is the
  smallest useful backend this project can have, which makes it the right first one.
- **Offers are network-dependent and must degrade to nothing.** Offline, or with the
  service down, the plan renders without them. This is also what keeps the app clear
  of guideline 4.2.2 (*"a collection of links"*), so the degraded path is the
  compliance story, not just resilience. A test pins it.
- Attribution is per-browser-context. A click in `SFSafariViewController` and a
  purchase in Safari an hour later is an unpaid booking, and an affiliate universal
  link intercepted by an installed partner app drops the cookie altogether. Closing
  that leak needs app-to-app attribution (Travelpayouts routes it through AppsFlyer),
  which contradicts the zero-dependency promise — **open decision**. Measure the leak
  before paying for it.
- The sub-ID is a tracking identifier in the DSGVO sense even though it names nobody.
  Consent comes before the first click report, and `PrivacyInfo.xcprivacy` plus the
  App Store Connect answers change in the same commit as the first sub-ID.
- Prices shown next to an offer come from the service at display time, or are a
  `PriceBand` and not a number. A cached price that has drifted is a
  Preisangabenverordnung problem, not only a conversion problem.
