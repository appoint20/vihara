import Testing
import Foundation
@testable import Vihara

@Suite("Meine Reisen")
struct SavedTripsTests {

    private func trip(_ destination: String, createdAt: Date) -> Trip {
        Trip(brief: TripBrief(destination: destination,
                              startDate: Fixture.date(2026, 4, 14),
                              nights: 2),
             days: [TripDay(date: Fixture.date(2026, 4, 14), city: destination, blocks: [
                 DayBlock(slot: .morning, items: [
                     ItineraryItem(place: Fixture.place("Santo Stefano"), kind: .sight),
                 ]),
                 DayBlock(slot: .afternoon),
                 DayBlock(slot: .evening),
             ])],
             createdAt: createdAt)
    }

    @Test("An empty store reads as empty, not as loading forever")
    @MainActor
    func emptyState() async {
        let model = SavedTripsViewModel(trips: InMemoryTripRepository())
        await model.load()

        #expect(model.isEmpty)
        #expect(model.saved.isEmpty)
    }

    @Test("Saved plans are listed newest first")
    @MainActor
    func listing() async {
        let repository = InMemoryTripRepository(seed: [
            trip("Modena", createdAt: Fixture.date(2026, 3, 1)),
            trip("Ravenna", createdAt: Fixture.date(2026, 5, 1)),
        ])
        let model = SavedTripsViewModel(trips: repository)
        await model.load()

        #expect(!model.isEmpty)
        #expect(model.saved.map(\.brief.destination) == ["Ravenna", "Modena"])
    }

    @Test("Deleting a plan removes it from the list")
    @MainActor
    func deletion() async {
        let plan = trip("Bologna", createdAt: Fixture.date(2026, 4, 1))
        let model = SavedTripsViewModel(trips: InMemoryTripRepository(seed: [plan]))
        await model.load()
        await model.delete(plan)

        #expect(model.isEmpty)
    }

    @Test("A row says which trip it is and how big the plan is")
    func rowLabels() {
        let plan = trip("Bologna", createdAt: Fixture.date(2026, 4, 1))

        #expect(plan.summaryLabel.hasPrefix("2 Nächte · ab "))
        #expect(plan.sizeLabel == "1 Baustein")
    }

    /// Opening a plan the traveller already has must not compose a second one: that
    /// would spend a free generation and could return something other than what they
    /// saved.
    @Test("A stored plan opens finished, without generating anything")
    @MainActor
    func storedPlanDoesNotRegenerate() {
        let plan = trip("Bologna", createdAt: Fixture.date(2026, 4, 1))
        let model = PlanViewModel(trip: plan)

        #expect(model.phase == .ready)
        #expect(model.days.count == 1)
        #expect(model.tripID == plan.id)
        #expect(!model.showsSkeleton)

        // Both are no-ops for a stored plan — there is nothing to start and nothing
        // to retry.
        model.startIfNeeded()
        model.retry()

        #expect(model.phase == .ready)
        #expect(model.days.count == 1)
    }

    @Test("A stored plan still shares as text")
    @MainActor
    func storedPlanShares() {
        let model = PlanViewModel(trip: trip("Bologna", createdAt: Fixture.date(2026, 4, 1)))
        #expect(model.shareText.contains("Santo Stefano"))
    }
}
