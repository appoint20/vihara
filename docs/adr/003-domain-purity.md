# ADR-003 — The domain is pure Swift; the wire format stops at the data layer

**Status:** accepted
**Date:** 2026-08-23

## Decision

Domain types (`Trip`, `TripDay`, `ItineraryItem`, `Wallet`, …) are **not `Codable`**.
The wire format lives in `Vihara/Data/DTO` and is translated by explicit mappers.

## Why

The backend does not exist yet, and the endpoint list (PRD §6.4) will change once it
does. Making the domain `Codable` welds the plan model to whatever JSON the first
NestJS iteration happens to emit: every rename becomes a migration, every optional on
the wire becomes an optional in the model, and `CodingKeys` accumulate in types that
should read like the product.

With a mapper in between, a backend rename is a one-line change in one file.

The mappers also **fail loudly**. A day with an unknown slot or an unparseable time
throws rather than degrading, because a half-understood plan that looks plausible is
worse than an error the traveller can retry. The single exception is the diet signal,
which degrades toward *less* confidence — mislabelling a meat menu as vegan is the one
failure that actually hurts someone.

## Consequences

- One extra type and one mapper per endpoint. Accepted.
- The DTOs double as the executable half of the API contract; `TripStreamMapperTests`
  is where the client's expectations are written down.
