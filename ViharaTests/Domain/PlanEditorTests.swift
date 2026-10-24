import Testing
import Foundation
@testable import Vihara

@Suite("Editing a plan")
struct PlanEditorTests {

    private let brief = Fixture.brief(destination: "Bologna", nights: 1)

    private var editor: PlanEditor { PlanEditor(brief: brief) }

    /// Morning holds two sights, afternoon and evening are empty.
    private func trip(morning: [ItineraryItem] = [],
                      afternoon: [ItineraryItem] = [],
                      evening: [ItineraryItem] = []) -> Trip {
        let day = TripDay(date: Fixture.date(2026, 4, 14), city: "Bologna", blocks: [
            DayBlock(slot: .morning, items: morning),
            DayBlock(slot: .afternoon, items: afternoon),
            DayBlock(slot: .evening, items: evening),
        ])
        return Trip(id: Identifier("t1"), brief: brief, days: [day])
    }

    private func items(_ trip: Trip, _ slot: DaySlot) -> [String] {
        (trip.days[0][slot]?.items ?? []).map(\.place.name)
    }

    // MARK: - Moving

    @Test("A stop moves to another half-day")
    func moveBetweenBlocks() throws {
        let item = Fixture.item("Torre")
        let start = trip(morning: [item])

        let result = editor.apply(.move(item: item.id, toSlot: .afternoon, onDay: start.days[0].id),
                                  to: start)

        #expect(result.didChange)
        #expect(items(result.trip, .morning).isEmpty)
        #expect(items(result.trip, .afternoon) == ["Torre"])
    }

    /// Exports are idempotent per `(id, revision)`. An edit that did not bump it
    /// would let a retried export hand back the plan as it was before the edit.
    @Test("Every accepted edit bumps the revision")
    func revisionBumps() throws {
        let item = Fixture.item("Torre")
        let start = trip(morning: [item])
        #expect(start.revision == 0)

        let moved = editor.apply(.move(item: item.id, toSlot: .evening, onDay: start.days[0].id),
                                 to: start)
        #expect(moved.trip.revision == 1)

        let pinned = editor.apply(.setPinned(item: item.id, true), to: moved.trip)
        #expect(pinned.trip.revision == 2)
    }

    @Test("A refused edit changes nothing, including the revision")
    func refusalChangesNothing() throws {
        // Pace allows a limited number of items; two headline sights in one block is
        // refused outright by `canAccept`.
        let a = Fixture.item("Torre", kind: .sight)
        let b = Fixture.item("San Petronio", kind: .sight)
        let start = trip(morning: [a], afternoon: [b])

        let result = editor.apply(.move(item: b.id, toSlot: .morning, onDay: start.days[0].id),
                                  to: start)

        #expect(!result.didChange)
        #expect(result.refusal == .blockWouldNotAccept(slot: .morning))
        #expect(result.trip.revision == 0)
        #expect(items(result.trip, .afternoon) == ["San Petronio"])
    }

    /// Dropping an item back where it came from is a cancelled drag. A traveller who
    /// thought better of a move should not get an error for it.
    @Test("Moving a stop to the block it is already in is a no-op, not a refusal")
    func moveToSameBlockIsHarmless() throws {
        let item = Fixture.item("Torre")
        let start = trip(morning: [item])

        let result = editor.apply(.move(item: item.id, toSlot: .morning, onDay: start.days[0].id),
                                  to: start)

        #expect(result.didChange)
        #expect(items(result.trip, .morning) == ["Torre"])
    }

    /// "7 Min. zu Fuß" described getting here from the stop before it, which is no
    /// longer the stop before it. A stale travel time is a wrong fact.
    @Test("A moved stop drops the travel time that no longer applies")
    func moveDropsStaleTravelLeg() throws {
        let first = Fixture.item("Piazza")
        let second = Fixture.item("Torre", walk: 7)
        let start = trip(morning: [first, second])
        #expect(start.days[0][.morning]?.items[1].travelFromPrevious != nil)

        let result = editor.apply(.move(item: second.id, toSlot: .evening, onDay: start.days[0].id),
                                  to: start)

        let moved = try #require(result.trip.days[0][.evening]?.items.first)
        #expect(moved.travelFromPrevious == nil)
    }

    @Test("An edit naming a stop that is not in the plan is refused")
    func unknownItem() throws {
        let start = trip(morning: [Fixture.item("Torre")])
        let result = editor.apply(.remove(item: Identifier("nope")), to: start)
        #expect(result.refusal == .itemNotFound)
    }

    @Test("An edit naming a day that is not in the plan is refused")
    func unknownDay() throws {
        let item = Fixture.item("Torre")
        let start = trip(morning: [item])
        let result = editor.apply(.move(item: item.id, toSlot: .evening, onDay: Identifier("nope")),
                                  to: start)
        #expect(result.refusal == .dayNotFound)
    }

    // MARK: - Removing, reordering, pinning

    @Test("A stop can be removed")
    func remove() throws {
        let item = Fixture.item("Torre")
        let start = trip(morning: [item, Fixture.item("Piazza")])

        let result = editor.apply(.remove(item: item.id), to: start)

        #expect(items(result.trip, .morning) == ["Piazza"])
    }

    @Test("A stop can be reordered inside its block")
    func reorder() throws {
        let a = Fixture.item("Erste", kind: .meal)
        let b = Fixture.item("Zweite", kind: .meal)
        let start = trip(morning: [a, b])

        let result = editor.apply(.reorder(item: b.id, toIndex: 0), to: start)

        #expect(items(result.trip, .morning) == ["Zweite", "Erste"])
    }

    @Test("An out-of-range reorder clamps instead of trapping")
    func reorderClamps() throws {
        let a = Fixture.item("Erste", kind: .meal)
        let b = Fixture.item("Zweite", kind: .meal)
        let start = trip(morning: [a, b])

        #expect(editor.apply(.reorder(item: a.id, toIndex: 99), to: start).didChange)
        #expect(editor.apply(.reorder(item: a.id, toIndex: -5), to: start).didChange)
    }

    /// Pinning is a promise to reflow, not a lock against the traveller.
    @Test("A pinned stop can still be moved by hand")
    func pinnedStopIsStillMovableByHand() throws {
        let item = Fixture.item("Torre", pinned: true)
        let start = trip(morning: [item])

        let result = editor.apply(.move(item: item.id, toSlot: .afternoon, onDay: start.days[0].id),
                                  to: start)

        #expect(result.didChange)
        #expect(items(result.trip, .afternoon) == ["Torre"])
        #expect(result.trip.days[0][.afternoon]?.items.first?.isPinned == true)
    }

    @Test("Pinning and unpinning round-trips")
    func pinning() throws {
        let item = Fixture.item("Torre")
        let start = trip(morning: [item])

        let pinned = editor.apply(.setPinned(item: item.id, true), to: start)
        #expect(pinned.trip.days[0][.morning]?.items.first?.isPinned == true)

        let loosed = editor.apply(.setPinned(item: item.id, false), to: pinned.trip)
        #expect(loosed.trip.days[0][.morning]?.items.first?.isPinned == false)
    }

    // MARK: - Reflow (F-06)

    /// The product rule the PRD sets against competitors: a conflict is *named*, not
    /// silently corrected. So an overfull block still holds everything it held.
    @Test("An edit that overfills a block is allowed, and reported")
    func conflictIsNamedNotPrevented() throws {
        let a = Fixture.item("Eins", kind: .meal)
        let b = Fixture.item("Zwei", kind: .meal)
        let c = Fixture.item("Drei", kind: .meal)
        // Build the overfull state directly: `canAccept` would refuse the last move.
        let start = trip(evening: [a, b, c])

        let result = editor.apply(.setPinned(item: a.id, true), to: start)

        #expect(result.didChange)
        #expect(items(result.trip, .evening).count == 3)
        #expect(result.warnings.contains { if case .blockOverfull = $0.kind { true } else { false } })
    }

    @Test("An overfull block is offered a move to an adjacent half-day")
    func proposesAMove() throws {
        let start = trip(evening: [
            Fixture.item("Eins", kind: .meal),
            Fixture.item("Zwei", kind: .meal),
            Fixture.item("Drei", kind: .meal),
        ])

        let proposals = editor.proposals(for: start)

        #expect(proposals.count == 1)
        let proposal = try #require(proposals.first)
        #expect(proposal.fromSlot == .evening)
        // Adjacent first: an evening stop pushed to the afternoon is a smaller
        // change than one pushed to the morning.
        #expect(proposal.toSlot == .afternoon)
        #expect(proposal.itemName == "Drei")
    }

    /// That is what pinning means.
    @Test("Reflow never proposes moving a pinned stop")
    func pinnedStopsAreNeverProposed() throws {
        let start = trip(evening: [
            Fixture.item("Eins", kind: .meal),
            Fixture.item("Zwei", kind: .meal),
            Fixture.item("Drei", kind: .meal, pinned: true),
        ])

        let proposals = editor.proposals(for: start)

        #expect(proposals.first?.itemName == "Zwei")
        #expect(!proposals.contains { $0.itemName == "Drei" })
    }

    @Test("A plan with no conflicts is offered nothing")
    func noProposalsForACleanPlan() throws {
        let start = trip(morning: [Fixture.item("Torre")],
                         evening: [Fixture.item("Osteria", kind: .meal)])
        #expect(editor.proposals(for: start).isEmpty)
    }

    /// Accepting a fix runs the ordinary edit path, so an accepted fix is
    /// indistinguishable from a hand-made one — same validation, same revision bump.
    @Test("A proposal carries the edit that performs it")
    func proposalRoundTrips() throws {
        let start = trip(evening: [
            Fixture.item("Eins", kind: .meal),
            Fixture.item("Zwei", kind: .meal),
            Fixture.item("Drei", kind: .meal),
        ])
        let proposal = try #require(editor.proposals(for: start).first)

        let result = editor.apply(proposal.edit, to: start)

        #expect(result.didChange)
        #expect(result.trip.revision == 1)
        #expect(items(result.trip, .evening).count == 2)
        #expect(items(result.trip, .afternoon) == ["Drei"])
        // The conflict it was about is gone.
        #expect(!result.warnings.contains { if case .blockOverfull = $0.kind { true } else { false } })
    }

    @Test("Adjacency ordering is stated once, for all three slots")
    func adjacencyOrdering() {
        #expect(PlanEditor.nearestSlots(to: .morning) == [.afternoon, .evening])
        #expect(PlanEditor.nearestSlots(to: .afternoon) == [.evening, .morning])
        #expect(PlanEditor.nearestSlots(to: .evening) == [.afternoon, .morning])
    }
}
