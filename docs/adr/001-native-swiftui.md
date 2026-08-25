# ADR-001 — Native SwiftUI on iOS, not Flutter

**Status:** proposed · needs a product decision
**Date:** 2026-08-23

## Context

The PRD (§6.1) picks **Flutter 3.x** for the mobile client, on the grounds of one
codebase, good gesture handling, and a smaller team. The repository I joined is a
**native SwiftUI** app targeting iOS 17.

That is a contradiction, and it has to be resolved before Phase 0 rather than
discovered in Phase 2.

## Decision

Continue in native SwiftUI for iOS, and treat Android as a separate, later decision.

## Why

The PRD's own requirements argue against Flutter more than for it:

- **Drag-and-drop is the product** (F-05/F-06), and the PRD asks for 120 fps on
  ProMotion with haptics on pick-up and drop. That is native territory. Flutter can
  get close; it cannot use `UIDragInteraction`, and it re-implements rather than
  inherits the platform's drag semantics.
- **Accessibility is launch-critical** (§8): VoiceOver across the whole planning
  flow, Dynamic Type to 200 %, and an alternative menu-driven path for drag-and-drop.
  Native gets the first two nearly free; Flutter's accessibility bridge makes both a
  line item.
- **StoreKit 2 and the credit model** (§4) are the revenue path. RevenueCat abstracts
  both platforms either way, so Flutter's advantage here is nil, while native gets
  first-day support for new StoreKit behaviour.
- **PDF and map snapshots** are server-side (§6.1), so no client rendering advantage
  is lost.

The real cost is honest and should be stated plainly: **Android needs its own
codebase.** For a launch scoped to DACH, iOS-first, one region and one language, that
cost lands after the hypothesis is tested rather than before.

## Consequences

- Android is descoped from the MVP. It becomes a Phase 4 decision, informed by real
  iOS conversion numbers.
- The design tokens are the shared asset across platforms, not the code. `Theme.swift`
  stays literal-free and mechanically portable.
- If the PM decides Android must ship alongside iOS, **this ADR is void** and the
  existing SwiftUI work becomes a design prototype. That is a cheap outcome today and
  an expensive one in six weeks — which is why the decision is needed now.
