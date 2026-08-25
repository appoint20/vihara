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

    @Test("Step progression navigates through all 5 interview phases")
    @MainActor
    func stepProgression() async {
        let vm = TripPlannerInterviewViewModel(catalogue: catalogue)
        vm.applyCustomDestination("Firenze")
        #expect(vm.canProceed)

        // Step 0 -> Step 1 (Dates)
        vm.nextStep()
        #expect(vm.currentStep == .datesAndDuration)

        // Step 1 -> Step 2 (Style & Pace)
        vm.nextStep()
        #expect(vm.currentStep == .styleAndPace)

        // Step 2 -> Step 3 (Budget & Diet)
        vm.nextStep()
        #expect(vm.currentStep == .budgetAndDiet)

        // Step 3 -> Step 4 (Summary)
        vm.nextStep()
        #expect(vm.currentStep == .summary)
        #expect(vm.isLastStep)

        // Previous step
        vm.previousStep()
        #expect(vm.currentStep == .budgetAndDiet)
    }

    @Test("Interview compiles a valid TripBrief with synthesized German sentence")
    @MainActor
    func briefCompilation() async {
        let vm = TripPlannerInterviewViewModel(catalogue: catalogue)
        vm.applyCustomDestination("Bologna")
        vm.setNights(4)
        vm.travelStyle = .cityBreak
        vm.pace = .relaxed
        vm.budget = .premium
        vm.diet = .vegetarian

        let brief = vm.brief
        #expect(brief.destination == "Bologna")
        #expect(brief.nights == 4)
        #expect(brief.dayCount == 5)
        #expect(brief.travelStyle == .cityBreak)
        #expect(brief.pace == .relaxed)
        #expect(brief.budget == .premium)
        #expect(brief.diet == .vegetarian)
        #expect(brief.isGeneratable)

        #expect(vm.synthesizedSentence.contains("5 Tage Bologna"))
        #expect(vm.synthesizedSentence.contains("vegetarisch"))
        #expect(vm.synthesizedSentence.contains("entspanntes Tempo"))
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
}
