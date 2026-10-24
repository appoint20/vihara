import Foundation
import Testing
@testable import Vihara

@Suite("Trip Planner Interview Flow")
struct TripPlannerInterviewTests {

    private let catalogue = PilotDestinationCatalogue()

    @Test("Initial state starts at destination step with defaults")
    @MainActor
    func initialState() async {
        let vm = TripPlannerInterviewViewModel(catalogue: catalogue)
        #expect(vm.currentStep == .destination)
        #expect(vm.nights == 3)
        #expect(vm.travelStyle == .cityBreak)
        #expect(vm.pace == .balanced)
        #expect(vm.budget == .middle)
        #expect(vm.diet == .none)
        #expect(vm.party == .couple)
        #expect(!vm.isCustomPace)
        #expect(!vm.canProceed)
    }

    @Test("Preselecting a destination fast-forwards to dates step")
    @MainActor
    func preselection() async {
        let bologna = PilotDestinationCatalogue.curated.first { $0.name == "Bologna" }!
        let vm = TripPlannerInterviewViewModel(catalogue: catalogue, preselectedDestination: bologna)

        #expect(vm.currentStep == .datesAndDuration)
        #expect(vm.destinationName == "Bologna")
        #expect(vm.nights == 3)
        #expect(vm.canProceed)
    }

    @Test("Step progression runs through all six phases, party before budget")
    @MainActor
    func stepProgression() async {
        let vm = TripPlannerInterviewViewModel(catalogue: catalogue)
        vm.applyCustomDestination("Bologna")
        #expect(vm.canProceed)
        #expect(vm.stepCount == 6)

        vm.nextStep()
        #expect(vm.currentStep == .datesAndDuration)

        vm.nextStep()
        #expect(vm.currentStep == .styleAndPace)

        // Who is coming is asked before what it costs, because it changes more.
        vm.nextStep()
        #expect(vm.currentStep == .travelParty)

        vm.nextStep()
        #expect(vm.currentStep == .budgetAndDiet)

        vm.nextStep()
        #expect(vm.currentStep == .summary)
        #expect(vm.isLastStep)

        vm.previousStep()
        #expect(vm.currentStep == .budgetAndDiet)
    }

    @Test("The interview compiles a valid brief")
    @MainActor
    func briefCompilation() async {
        let vm = TripPlannerInterviewViewModel(catalogue: catalogue)
        vm.applyCustomDestination("Bologna")
        vm.setNights(4)
        vm.travelStyle = .cityBreak
        vm.selectPace(.relaxed)
        vm.budget = .premium
        vm.diet = .vegetarian
        vm.applyPreset(.family)

        let brief = vm.brief
        #expect(brief.destination == "Bologna")
        #expect(brief.nights == 4)
        #expect(brief.dayCount == 5)
        #expect(brief.travelStyle == .cityBreak)
        #expect(brief.pace == .relaxed)
        #expect(brief.budget == .premium)
        #expect(brief.diet == .vegetarian)
        #expect(brief.party == .family)
        #expect(brief.paceOverride == nil)
        #expect(brief.isGeneratable)
    }

    @Test("Duration adjustments clamp within safe bounds")
    @MainActor
    func durationClamping() async {
        let vm = TripPlannerInterviewViewModel(catalogue: catalogue)
        vm.setNights(1)
        vm.adjustNights(by: -5)
        #expect(vm.nights == 1)

        vm.setNights(30)
        vm.adjustNights(by: 5)
        #expect(vm.nights == 30)
    }

    // MARK: - Picking up where the home surface left off

    @Test("A seeded interview does not re-ask what the sentence already answered")
    @MainActor
    func seedingSkipsTheDestinationStep() async {
        let seed = TripBrief(destination: "Ravenna",
                             startDate: Fixture.date(2026, 5, 2),
                             nights: 5,
                             pace: .packed,
                             diet: .vegan,
                             party: TravelParty(adults: 1))
        let vm = TripPlannerInterviewViewModel(catalogue: catalogue, seed: seed)

        #expect(vm.currentStep == .datesAndDuration)
        #expect(vm.destinationName == "Ravenna")
        #expect(vm.nights == 5)
        #expect(vm.pace == .packed)
        #expect(vm.diet == .vegan)
        #expect(vm.party.adults == 1)
    }

    @Test("Resuming a draft opens at the step it was left on")
    @MainActor
    func resumingADraft() async {
        let vm = TripPlannerInterviewViewModel(catalogue: catalogue,
                                               seed: TripBrief(destination: "Bologna",
                                                               startDate: .now,
                                                               nights: 3),
                                               resumingAt: TripPlannerInterviewViewModel.Step.travelParty.rawValue)
        #expect(vm.currentStep == .travelParty)
    }

    @Test("Walking through the interview leaves a draft to come back to")
    @MainActor
    func stepsWriteADraft() async throws {
        let store = InMemoryInterviewDraftStore()
        let vm = TripPlannerInterviewViewModel(catalogue: catalogue, drafts: store)
        vm.applyCustomDestination("Bologna")
        vm.nextStep()
        vm.nextStep()

        // The save is fire-and-forget, so give the task a turn.
        try await Task.sleep(for: .milliseconds(50))
        let drafts = await store.drafts()

        #expect(drafts.count == 1)
        #expect(drafts.first?.destination == "Bologna")
        #expect(drafts.first?.step == TripPlannerInterviewViewModel.Step.styleAndPace.rawValue)
        #expect(drafts.first?.totalSteps == 6)
    }

    @Test("Generating the plan clears the draft it came from")
    @MainActor
    func generatingClearsTheDraft() async throws {
        let store = InMemoryInterviewDraftStore(seed: [
            InterviewDraft(destination: "Bologna", step: 2, totalSteps: 6, nights: 3),
        ])
        let vm = TripPlannerInterviewViewModel(catalogue: catalogue, drafts: store)
        vm.applyCustomDestination("Bologna")
        vm.clearDraft()

        try await Task.sleep(for: .milliseconds(50))
        #expect(await store.drafts().isEmpty)
    }

    @Test("A draft is only offered back once it got somewhere")
    func draftsWorthResuming() {
        #expect(!InterviewDraft(destination: "Bologna", step: 0, totalSteps: 6, nights: 3).isWorthResuming)
        #expect(InterviewDraft(destination: "Bologna", step: 2, totalSteps: 6, nights: 3).isWorthResuming)
        // A finished interview is a plan, not a draft.
        #expect(!InterviewDraft(destination: "Bologna", step: 5, totalSteps: 5, nights: 3).isWorthResuming)
    }

    // MARK: - "Eigene Werte"

    @Test("Choosing your own numbers starts from whichever preset was live")
    @MainActor
    func customPaceSeedsFromThePreset() async {
        let vm = TripPlannerInterviewViewModel(catalogue: catalogue)
        vm.selectPace(.packed)
        vm.selectCustomPace()

        #expect(vm.isCustomPace)
        #expect(vm.paceOverride?.itemsPerBlock == TripBrief.Pace.packed.maxItemsPerBlock)
        #expect(vm.paceOverride?.walkingMetres == TripBrief.Pace.packed.maxWalkingDistanceInBlock)
    }

    @Test("Picking a preset again drops the custom numbers")
    @MainActor
    func presetClearsTheOverride() async {
        let vm = TripPlannerInterviewViewModel(catalogue: catalogue)
        vm.selectCustomPace()
        #expect(vm.isCustomPace)

        vm.selectPace(.relaxed)
        #expect(!vm.isCustomPace)
        #expect(vm.brief.paceOverride == nil)
    }

    /// The whole point of the custom card: composition has to read the traveller's
    /// numbers, not the bucket's.
    @Test("Custom numbers reach composition, not the bucket's defaults")
    @MainActor
    func overrideReachesComposition() async {
        let vm = TripPlannerInterviewViewModel(catalogue: catalogue)
        vm.applyCustomDestination("Bologna")
        vm.selectPace(.relaxed)          // one item per block
        vm.selectCustomPace()
        vm.paceOverride?.itemsPerBlock = 3
        vm.paceOverride?.walkingMetres = 2500

        let brief = vm.brief
        #expect(brief.pace == .relaxed)
        #expect(brief.maxItemsPerBlock == 3)
        #expect(brief.maxWalkingDistanceInBlock == 2500)
    }

    @Test("An override is clamped to the three slots a block actually has")
    func overrideClamps() {
        #expect(TripBrief.PaceOverride(itemsPerBlock: 9).itemsPerBlock == 3)
        #expect(TripBrief.PaceOverride(itemsPerBlock: 0).itemsPerBlock == 1)
    }

    @Test("The block estimate follows whichever numbers are live")
    func blockEstimate() {
        let relaxed = TripBrief(destination: "Bologna", startDate: .now, nights: 3, pace: .relaxed)
        // 4 days × 3 blocks × 1 item.
        #expect(relaxed.estimatedBlockCount == 12)

        var custom = relaxed
        custom.paceOverride = TripBrief.PaceOverride(itemsPerBlock: 3)
        #expect(custom.estimatedBlockCount == 36)
    }

    // MARK: - Party effects

    @Test("The party step can name what it changes once candidates are loaded")
    @MainActor
    func partyEffectsAreAvailable() async {
        let vm = TripPlannerInterviewViewModel(catalogue: catalogue)
        vm.applyCustomDestination("Bologna")
        await vm.load()
        vm.applyPreset(TravelParty(adults: 2, childAges: [4]))

        #expect(!vm.candidatePlaces.isEmpty)
        #expect(vm.partyEffects.contains(.stopDropped(place: "Torre degli Asinelli",
                                                      minimumAge: 12,
                                                      childAge: 4)))
    }

    @Test("Children steppers add and remove ages rather than a bare count")
    @MainActor
    func childCountKeepsAges() async {
        let vm = TripPlannerInterviewViewModel(catalogue: catalogue)
        vm.setChildren(2)
        #expect(vm.party.childAges.count == 2)

        vm.setAge(3, forChildAt: 0)
        #expect(vm.party.childAges[0] == 3)

        vm.setChildren(1)
        #expect(vm.party.childAges == [3])

        // Clamped: a party is one to nine adults and nought to six children.
        vm.setChildren(99)
        #expect(vm.party.childAges.count == 6)
        vm.setAdults(0)
        #expect(vm.party.adults == 1)
    }

    @Test("Accommodations toggle both ways")
    @MainActor
    func accommodationToggling() async {
        let vm = TripPlannerInterviewViewModel(catalogue: catalogue)
        vm.toggle(.middaySleep)
        #expect(vm.party.accommodations == [.middaySleep])
        vm.toggle(.middaySleep)
        #expect(vm.party.accommodations.isEmpty)
    }
}
