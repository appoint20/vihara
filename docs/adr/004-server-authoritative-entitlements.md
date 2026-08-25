# ADR-004 — Entitlements are server-authoritative; the client cannot spend

**Status:** accepted
**Date:** 2026-08-23

## Decision

`Wallet` is an immutable read projection. It has no mutating members and no `spend`
anything. Every grant decision is made by `POST /v1/trips/:id/export` and finalised on
delivery.

The client keeps one derived value, `Wallet.exportOutlook(for:)`, which mirrors the
server's decision order from PRD §4.1 — used **only** to choose which paywall variant
to raise, so the sheet does not flicker between tap and answer.

## Why

Credits are money. PRD §7.3 makes the ledger server-side and idempotent per
transaction id; §4.2 reserves a credit on export and commits it only on a delivered
signed URL. A client that can decrement a counter is a client that can be made to
grant a download by changing its clock or its storage.

Encoding this as *type structure* rather than as a convention means the mistake cannot
be made by accident: there is no method to call.

## Consequences

- `WalletRepository` is read-only.
- The prediction and the authority can disagree (a credit spent on another device, a
  refund not yet propagated). The server wins, always, and the UI must handle being
  told "no" after predicting "yes".
- Open question raised against PRD §4.1: purchased credits are sold as never
  expiring, but the decision order gates them on an **active** subscription — so an
  expired subscriber cannot spend a credit they own. Implemented as written and pinned
  by a test; needs a product answer.
