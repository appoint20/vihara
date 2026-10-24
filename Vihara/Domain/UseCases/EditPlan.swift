import Foundation

/// What the traveller can do to a plan (F-05).
///
/// A closed set of named operations rather than free mutation of ``Trip``, for two
/// reasons. Every edit has to bump `revision` — exports are idempotent per
/// `(id, revision)`, so an edit that forgot to would hand back a stale PDF. And the
/// accessible path and the drag gesture must do **exactly** the same thing: both
/// produce a `PlanEdit` and nothing else, so "Verschieben nach…" cannot drift away
/// from dragging as the feature grows.
enum PlanEdit: Hashable, Sendable {
    /// Move an item to a half-day, appending it there. The same slot it already
    /// occupies is a no-op rather than a refusal.
    case move(item: Identifier<ItineraryItem>, toSlot: DaySlot, onDay: Identifier<TripDay>)
    /// Reorder within the block the item is already in.
    case reorder(item: Identifier<ItineraryItem>, toIndex: Int)
    case remove(item: Identifier<ItineraryItem>)
    /// Pinning is a promise to reflow, not a lock against the traveller: they may
    /// still move a pinned item by hand. See ``ItineraryItem/isPinned``.
    case setPinned(item: Identifier<ItineraryItem>, Bool)
}

/// Why an edit did not happen.
///
/// Refusals are for edits that cannot be represented — not for edits that merely
/// create a conflict. A conflict is a normal thing to do and comes back as a
/// ``PlanWarning``; this type is for "that item is not in this plan".
enum PlanEditRefusal: Hashable, Sendable {
    case itemNotFound
    case dayNotFound
    /// The pace has no room and the block already holds a headline sight — the
    /// conditions ``ItineraryRules/canAccept(_:into:)`` reports before a drop.
    case blockWouldNotAccept(slot: DaySlot)
}

/// The result of asking for an edit.
struct PlanEditResult: Sendable {
    /// The plan after the edit, or unchanged when `refusal` is set.
    let trip: Trip
    /// Every conflict in the edited plan, named rather than silently corrected.
    let warnings: [PlanWarning]
    /// Fixes the traveller may accept. Never applied on their behalf.
    let proposals: [ReflowProposal]
    let refusal: PlanEditRefusal?

    var didChange: Bool { refusal == nil }
}

/// A fix the planner would make, offered rather than performed (F-06).
///
/// The product rule the PRD sets against competitors: when an edit creates a
/// conflict we **say so**. Silent reshuffling is the trust-breaking behaviour, so a
/// proposal is a sentence with a button, never an animation that happens while the
/// traveller is still looking at what they did.
struct ReflowProposal: Hashable, Sendable, Identifiable {
    let id: Identifier<ReflowProposal>
    let itemID: Identifier<ItineraryItem>
    let itemName: String
    let fromSlot: DaySlot
    let toSlot: DaySlot
    let dayID: Identifier<TripDay>

    init(id: Identifier<ReflowProposal> = .generate(),
         itemID: Identifier<ItineraryItem>,
         itemName: String,
         fromSlot: DaySlot,
         toSlot: DaySlot,
         dayID: Identifier<TripDay>) {
        self.id = id
        self.itemID = itemID
        self.itemName = itemName
        self.fromSlot = fromSlot
        self.toSlot = toSlot
        self.dayID = dayID
    }

    /// The edit this proposal stands for. Accepting a proposal runs the ordinary
    /// edit path, so an accepted fix is indistinguishable from a hand-made one.
    var edit: PlanEdit {
        .move(item: itemID, toSlot: toSlot, onDay: dayID)
    }
}

/// Applies edits to a plan and names what they broke.
///
/// Pure, synchronous and offline. This is the half of reflow that needs no round
/// trip: after any edit the client can list every conflict and propose the obvious
/// moves instantly. The server is only needed to propose a *better* plan than
/// "put it in the next block that fits".
struct PlanEditor: Sendable {
    private let rules: ItineraryRules

    init(brief: TripBrief) {
        self.rules = ItineraryRules(brief: brief)
    }

    func apply(_ edit: PlanEdit, to trip: Trip) -> PlanEditResult {
        var trip = trip
        let refusal: PlanEditRefusal?

        switch edit {
        case let .move(itemID, slot, dayID):
            refusal = move(itemID, to: slot, onDay: dayID, in: &trip)
        case let .reorder(itemID, index):
            refusal = reorder(itemID, to: index, in: &trip)
        case let .remove(itemID):
            refusal = remove(itemID, from: &trip)
        case let .setPinned(itemID, pinned):
            refusal = setPinned(itemID, pinned, in: &trip)
        }

        guard refusal == nil else {
            return PlanEditResult(trip: trip, warnings: [], proposals: [], refusal: refusal)
        }

        // Exports are idempotent per `(id, revision)`. An edit that did not bump this
        // would let a retried export hand back the plan as it was before the edit.
        trip.revision += 1

        return PlanEditResult(trip: trip,
                              warnings: trip.days.flatMap(rules.warnings(for:)),
                              proposals: proposals(for: trip),
                              refusal: nil)
    }

    /// Where the given item currently sits.
    private func locate(_ itemID: Identifier<ItineraryItem>,
                        in trip: Trip) -> (day: Int, block: Int, item: Int)? {
        for (d, day) in trip.days.enumerated() {
            for (b, block) in day.blocks.enumerated() {
                if let i = block.items.firstIndex(where: { $0.id == itemID }) {
                    return (d, b, i)
                }
            }
        }
        return nil
    }

    private func move(_ itemID: Identifier<ItineraryItem>,
                      to slot: DaySlot,
                      onDay dayID: Identifier<TripDay>,
                      in trip: inout Trip) -> PlanEditRefusal? {
        guard let from = locate(itemID, in: trip) else { return .itemNotFound }
        guard let targetDay = trip.days.firstIndex(where: { $0.id == dayID }) else {
            return .dayNotFound
        }
        guard let targetBlock = trip.days[targetDay].blocks.firstIndex(where: { $0.slot == slot }) else {
            return .dayNotFound
        }

        // Already there. A no-op, not a refusal: dropping an item back where it came
        // from is a cancelled drag, and a drag the traveller thought better of should
        // not raise an error.
        if from.day == targetDay, from.block == targetBlock { return nil }

        let item = trip.days[from.day].blocks[from.block].items[from.item]
        guard rules.canAccept(item, into: trip.days[targetDay].blocks[targetBlock]) else {
            return .blockWouldNotAccept(slot: slot)
        }

        trip.days[from.day].blocks[from.block].items.remove(at: from.item)
        // The travel leg described getting here from the item before it in the old
        // block, which is no longer the item before it. A stale "7 Min. zu Fuß" is a
        // wrong fact, so it is dropped rather than carried.
        var moved = item
        moved.travelFromPrevious = nil
        trip.days[targetDay].blocks[targetBlock].items.append(moved)
        return nil
    }

    private func reorder(_ itemID: Identifier<ItineraryItem>,
                         to index: Int,
                         in trip: inout Trip) -> PlanEditRefusal? {
        guard let at = locate(itemID, in: trip) else { return .itemNotFound }
        var items = trip.days[at.day].blocks[at.block].items
        let item = items.remove(at: at.item)
        items.insert(item, at: min(max(index, 0), items.count))
        trip.days[at.day].blocks[at.block].items = items
        return nil
    }

    private func remove(_ itemID: Identifier<ItineraryItem>,
                        from trip: inout Trip) -> PlanEditRefusal? {
        guard let at = locate(itemID, in: trip) else { return .itemNotFound }
        trip.days[at.day].blocks[at.block].items.remove(at: at.item)
        return nil
    }

    private func setPinned(_ itemID: Identifier<ItineraryItem>,
                           _ pinned: Bool,
                           in trip: inout Trip) -> PlanEditRefusal? {
        guard let at = locate(itemID, in: trip) else { return .itemNotFound }
        trip.days[at.day].blocks[at.block].items[at.item].isPinned = pinned
        return nil
    }

    // MARK: - Reflow

    /// The obvious moves, for blocks that hold more than the pace allows.
    ///
    /// Deliberately modest. It proposes moving the **last unpinned** item of an
    /// overfull block into the nearest block that would accept it, and nothing
    /// cleverer: a local heuristic that the traveller can predict beats one that
    /// surprises them, and anything better needs the composing model.
    ///
    /// A pinned item is never proposed for a move. That is what pinning means.
    func proposals(for trip: Trip) -> [ReflowProposal] {
        var found: [ReflowProposal] = []

        for day in trip.days {
            for block in day.blocks {
                let overfull = rules.warnings(for: block).contains {
                    if case .blockOverfull = $0.kind { return true }
                    if case .competingHeadlines = $0.kind { return true }
                    return false
                }
                guard overfull else { continue }
                guard let candidate = block.items.last(where: { !$0.isPinned }) else { continue }

                for target in Self.nearestSlots(to: block.slot) {
                    guard let targetBlock = day[target],
                          rules.canAccept(candidate, into: targetBlock) else { continue }
                    found.append(ReflowProposal(itemID: candidate.id,
                                                itemName: candidate.place.name,
                                                fromSlot: block.slot,
                                                toSlot: target,
                                                dayID: day.id))
                    break
                }
            }
        }
        return found
    }

    /// Adjacent half-days first: an afternoon sight pushed to the evening is a
    /// smaller change to someone's day than one pushed to the next morning.
    static func nearestSlots(to slot: DaySlot) -> [DaySlot] {
        switch slot {
        case .morning:   [.afternoon, .evening]
        case .afternoon: [.evening, .morning]
        case .evening:   [.afternoon, .morning]
        }
    }
}
