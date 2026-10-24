# Vihara — engineering roadmap

Against **PRD v1.0** (Wayfare), 23 August 2026. The presentation version of this
document is published as an artifact; this is the copy that lives with the code.

Two companion documents cover the commercial side, which the PRD does not:
[COMPETITION.md](COMPETITION.md) (what Wanderlog does not do, and which three gaps are
worth owning) and [MONETISATION.md](MONETISATION.md) (how affiliate revenue actually
works, what it is worth, and the step-by-step plan to it). Where they disagree with
the phases below, the disagreement is listed as blocking decision 4.

## Blocking decisions

Cheap this week, expensive in six. Everything below assumes an answer.

1. **Flutter or native iOS?** The PRD picks Flutter (§6.1); the codebase is native
   SwiftUI. See [ADR-001](adr/001-native-swiftui.md). The honest cost of native is a
   separate Android codebase.
2. **Italy or Spain for the pilot?** The PRD's own open question (§10.3), and it gates
   Phase 0 rather than following it — the POI index is curated once, by hand, and every
   cost estimate is measured against that one region.
3. ~~**Does the free tier really need a PDF viewer?**~~ **Answered in the build.** No
   custom viewer was written: the export hands a PDF to the share sheet, and iOS
   previews it with Quick Look for free. The preview is both watermarked *and*
   truncated to day one, with the remaining days named — the cheaper alternative from
   this entry, adopted on top of the watermark rather than instead of it, because a
   watermarked *complete* plan is still a complete plan and so is not a paywall. The
   number of full days is server-set (`previewDaysInFull`). **Confirm the truncation
   is wanted before launch** — it is a pricing decision, not a technical one.
4. **Affiliates before the paywall, or after?** The table below follows the PRD:
   F-09 (paywall) and F-10 (affiliates) both land in Phase 2, applications in Phase 1.
   [MONETISATION §7](MONETISATION.md#7-the-sequencing-change) argues for swapping them —
   programme approval has weeks of lead time and may be refused pre-launch, affiliate
   needs no pricing decision, it carries no 3.1.1 review risk, and measured affiliate
   ARPU is what tells you how to price the subscription. Answering this also makes
   decision 3 cheaper. **Until it is answered the phase table below is stale.**

## Phases

The PRD's phases, kept intact, with what the client does in each.

| | Phase | Client work | Leave when |
|---|---|---|---|
| **0** | Foundation · 3 wk | **Done.** Architecture, tokens, intake, streaming plan, constraint engine, tests, CI lint. Start drag-and-drop against the stub immediately. | 95 % of POIs pass live validation; decisions 1–3 answered |
| **1** | Closed alpha · 6 wk | F-05 drag/swap/pin with the accessible menu path built alongside · F-06 reflow · F-14 on-device store · F-15 accounts **early** · F-08 export | 70 % finish a plan; qualitative yes to "would you pay 5 €" |
| **2** | Public beta · 6 wk | F-09 paywall and RevenueCat · F-07 transfers · F-10 affiliates in `SFSafariViewController` ([ADR-006](adr/006-affiliate-links-server-authoritative.md)) · F-11 · F-12 · dark-mode audit | Conversion ≥ 6 %, affiliate click rate ≥ 12 % |
| **3** | Store launch · 4 wk | EN alongside DE · two more curated regions · onboarding, ASO · full accessibility pass | Approval first time; crash-free ≥ 99.5 % |
| **4** | Growth | F-13 groups · credit bundles · package extraction · Android if deferred | — |

### Two critical paths

Phase 0 is entirely backend. The client has nothing to do in it, which is why the
foundation exists now: the hardest client work in the product is drag-and-reflow, and
it can be built against the stub while the index is curated. Waiting would push the
riskiest client work into the same weeks as the paywall.

### Sequencing correction

The PRD lists **F-15 (accounts)** as one Phase-1 item among many. It is a
prerequisite: entitlements follow the account, so nothing monetised can be tested
until accounts exist. Build it early in Phase 1, not late.

## Feature status

| ID | Feature | Status |
|---|---|---|
| F-01 | Trip intake | Running · local parser stands in for the intake model · search covers 285 cities from a bundled corpus |
| F-02 | AI first draft | Running on a stub · streaming and skeleton states are real |
| F-03 | Live validation | Backend · client models only validated places, by construction |
| F-04 | Diet filter | Running · confirmed and likely are visually distinct |
| F-05 | Block editing | **Running** · drag and the accessible menu emit the same `PlanEdit` |
| F-06 | AI reflow | **Running, locally** · conflicts named and moves proposed; the model half is still backend |
| F-07 | Transfer check | Modelled · no UI, no partners |
| F-08 | PDF export | **Running** · CoreText, paginated, watermarked preview truncated to day one |
| F-09 | Credits & paywall | **Running** · both PRD 4.1 variants, StoreKit 2, restore; receipts still unverified |
| F-10 | Affiliate buttons | **Running on a stub** · surface, disclosure and hand-off built; needs the link service (step 2) and an approved programme · apply **now** |
| F-11 | Budget tracking | **Running** · composed from the plan, multi-currency on a static rate table |
| F-12 | Packing list | **Running** · derived from month, party, walking and tickets |
| F-13 | Group collaboration | Phase 4 |
| F-14 | Offline mode | Phase 1 · architecture is already offline-first |
| F-15 | Account & sync | Phase 1, **early** |

## Where the PRD and the code disagree

Six things found while implementing the spec. None blocks work; all are cheaper to
settle now than in review.

1. **A day has no midday block, but composition asks for a midday meal** (§3.1 vs
   Abb. 1). Implemented as evening-only — requiring a meal in a block ending at 18:00
   would warn on every plan. *Does lunch belong to Vormittag, Nachmittag, or neither?*
2. **Purchased credits are sold as permanent but spend like a subscription perk**
   (§4.1). "Verfallen nicht", yet gated on an *active* subscription. Implemented as
   written and pinned by a test. See [ADR-004](adr/004-server-authoritative-entitlements.md).
3. **Two grids** (§5.2 vs the existing screens): the plan surface is 5pt/2pt-radius,
   Discover is 4pt with 22–34pt photo cards. Both are named token sets now rather than
   drifting. *Does Discover move onto the plan tokens?*
4. **Four bottom-nav items against "kein Tab-Bar-Zoo"** (§5.1 rule 2). Merkliste has
   no feature ID behind it. *Real feature, or drop to three?*
5. **Nobody owns the per-region curation cost.** Phase 3 opens three regions; curation
   is the one genuinely manual cost and has no owner and no estimate.
6. **Revalidation 24 h before departure needs a floor on start dates** (§6.5). A plan
   generated for today ships unchecked. Intake now refuses a start date before
   tomorrow. *Confirm, or define what a same-day plan promises.*

## Engineering risks to add to §10.2

| Risk | Why it bites | Countermeasure |
|---|---|---|
| Accessible drag-and-drop | An alternative to dragging cannot be bolted on; it changes the edit model | Build the "Verschieben nach…" path in the same week as the gesture |
| Streaming on a flaky network | A dropped SSE mid-generation must not discard a readable partial plan | Handled; needs a real-network test pass in Phase 1 |
| Export double-charging | A retried export that is not deduplicated costs the traveller money | **Done** · grants are cached per `(trip, revision)`; a preview is deliberately *not* cached, so a purchase takes effect at once |
| Unverified receipts | StoreKit says "verified", which means Apple signed it — not that the account is entitled | The ledger decides; `InMemoryEntitlementServer` is the faked server and must be deleted when the real one lands |
| Wire contract drift | Two teams, no shared types, one JSON shape | Client expectations are executable tests, not prose |
| Affiliate attribution leak | A partner universal link opens the partner's installed app and drops the cookie — losing exactly the highest-intent users | Measure the leak before buying an SDK to close it ([ADR-006](adr/006-affiliate-links-server-authoritative.md)) |
| Rejection under guideline 4.2.2 | "A collection of links" is the real App Store risk for affiliate surfaces, not IAP | The plan must render completely with offers switched off; pinned by a test |
| Affiliate approval refused pre-launch | Booking.com now routes small partners through CJ/Awin, which require a property with real traffic | Travelpayouts first (accepts pre-launch), plus a public property in step 0.2 |
