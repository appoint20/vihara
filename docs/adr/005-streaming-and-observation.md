# ADR-005 — Streaming in the protocol, `@Observable` in the view models

**Status:** accepted
**Date:** 2026-08-23

## Decision

`TripGenerating.generate(from:)` returns `AsyncThrowingStream<TripGenerationEvent, Error>`,
not `async throws -> Trip`. View models are `@MainActor @Observable` classes, one per
screen, constructed by the routing layer from the composition root.

## Why

Day-by-day arrival is a **product rule**, not an optimisation: the first validated day
must be readable while the rest compose, and there is never a full-screen spinner
(PRD §5.1, rule 7). A method returning a finished `Trip` makes that rule
unimplementable, so the shape belongs in the protocol where it cannot be lost.

`StubTripGenerator` deliberately streams *with latency* for the same reason. A stub
that returns instantly would let a missing skeleton state ship unnoticed.

`@Observable` over `ObservableObject`: iOS 17 is the floor, and the plan screen
appends to an array many times during generation — per-property tracking avoids
re-rendering every day on every append.

## Consequences

- Cancellation is real: leaving the plan screen cancels the generation task.
- View models are built in `RootView`, the one place that reads the composition root.
  Screens never reach into the environment for a dependency, so each is previewable
  and testable with whatever collaborators the case needs.
