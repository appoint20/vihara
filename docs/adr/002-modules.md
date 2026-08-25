# ADR-002 — Layered folders now, Swift packages at a named trigger

**Status:** accepted
**Date:** 2026-08-23

## Context

Clean architecture needs its dependency rule enforced. The strongest enforcement is
compile-time: put each layer in its own Swift package and an upward import stops
being possible. The cost is build time, flakier previews, and a package graph to
maintain.

The project uses Xcode 16 **file-system-synchronized groups**, so adding a file needs
no project edit — which removes the usual second argument for packages (escaping
`.pbxproj` merge conflicts).

Team size today: one mobile developer.

## Decision

Ship the layers as folders inside one app target:

```
Vihara/Domain      entities, repository protocols, use cases   (Foundation only)
Vihara/Data        HTTP, DTOs, mappers, repositories, stubs    (Domain + Foundation)
Vihara/DesignSystem tokens and presentational components       (SwiftUI, no Domain)
Vihara/Features    screens and view models                     (all of the above)
Vihara/App         composition root and routing                (everything)
```

Enforce the dependency rule with `Scripts/check-layers.sh` in CI, and extract real
packages at a **named trigger**, whichever comes first:

1. a second engineer joins the mobile codebase, or
2. app-target incremental builds pass ~30 s, or
3. the first feature needs to be reused outside the app (an App Intent, a widget, a
   share extension).

## Why

Convention does not hold on its own — but neither does a package graph maintained by
one person under launch pressure. A lint that actually fails the build is most of the
enforcement for a fraction of the cost, and the folder layout is already
package-shaped, so extraction is mechanical rather than a rewrite.

Naming the trigger is the point of the ADR. "We'll modularise later" without one is
how a codebase arrives at Phase 3 with none.

## Consequences

- `Scripts/check-layers.sh` must run in CI from the first pipeline, or this ADR is
  worthless.
- Every layer stays import-clean, so extraction is a matter of moving folders and
  adding `public`.
