import SwiftUI

/// The guided interview, six steps deep.
///
/// It opens where the home surface left off rather than at question one, and every
/// step it passes writes a draft — so closing this sheet costs nothing but the sheet.
struct TripPlannerInterviewView: View {
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var model: TripPlannerInterviewViewModel

    init(model: TripPlannerInterviewViewModel) {
        _model = State(wrappedValue: model)
    }

    var body: some View {
        VStack(spacing: 0) {
            topNavigation
            progressBar

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.S.s5) {
                    stepHeader
                    stepContent
                }
                .padding(.horizontal, Theme.S.screen)
                .padding(.top, Theme.S.s4)
                .padding(.bottom, Theme.S.s8)
            }
            .scrollDismissesKeyboard(.interactively)

            bottomActionBar
        }
        .background(Theme.C.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task { await model.load() }
    }

    // MARK: - Navigation & progress

    private var topNavigation: some View {
        HStack {
            if model.currentStep > .destination {
                BackControl {
                    withAnimation(Theme.Plan.Motion.standard) { model.previousStep() }
                }
            } else {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .viharaText(Theme.Plan.F.meta)
                        .foregroundStyle(Theme.C.textMuted)
                        .frame(width: Theme.S.tapTarget, height: Theme.S.tapTarget)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("interview.close"))
            }

            Spacer()

            Text(localized("interview.progress",
                           model.currentStep.rawValue + 1,
                           model.stepCount,
                           locale: locale))
                .viharaText(Theme.Plan.F.blockLabel)
                .foregroundStyle(Theme.C.textFaint)
        }
        .padding(.horizontal, Theme.S.screen)
        .padding(.top, Theme.S.s2)
    }

    private var progressBar: some View {
        GeometryReader { proxy in
            let total = CGFloat(model.stepCount)
            let current = CGFloat(model.currentStep.rawValue + 1)

            ZStack(alignment: .leading) {
                Rectangle().fill(Theme.C.border)
                Rectangle()
                    .fill(Theme.C.accent)
                    .frame(width: proxy.size.width * (current / total))
            }
        }
        .frame(height: Theme.Size.progressBar)
        .padding(.top, Theme.S.s2)
        .animation(Theme.Plan.Motion.standard, value: model.currentStep)
    }

    private var stepHeader: some View {
        VStack(alignment: .leading, spacing: Theme.S.s1) {
            Text(LocalizedStringKey(model.currentStep.titleKey))
                .viharaText(Theme.Plan.F.dayTitle)
                .foregroundStyle(Theme.C.text)

            Text(LocalizedStringKey(model.currentStep.subtitleKey))
                .viharaText(Theme.Plan.F.meta)
                .foregroundStyle(Theme.C.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch model.currentStep {
        case .destination:      destinationStep
        case .datesAndDuration: datesStep
        case .styleAndPace:     paceStep
        case .travelParty:      TravelPartyStepView(model: model)
        case .budgetAndDiet:    budgetStep
        case .summary:          summaryStep
        }
    }

    // MARK: - 1 · Destination

    private var destinationStep: some View {
        VStack(alignment: .leading, spacing: Theme.S.s4) {
            CitySearchField(text: $model.searchQuery,
                            placeholder: localized("home.sentence.placeholder", locale: locale)) {
                Task { await model.updateSearch() }
            } onClear: {
                Task { await model.updateSearch() }
            }
            .onChange(of: model.searchQuery) { _, newValue in
                if !newValue.isEmpty { model.applyCustomDestination(newValue) }
                Task { await model.updateSearch() }
            }

            Text("home.rail.title")
                .viharaText(Theme.Plan.F.blockLabel)
                .foregroundStyle(Theme.C.textFaint)

            VStack(spacing: Theme.S.s2) {
                ForEach(model.searchResults) { destination in
                    InterviewOptionCard(title: LocalizedStringKey(destination.name),
                                        subtitle: LocalizedStringKey(destination.region),
                                        iconName: "building.2",
                                        isSelected: model.destinationName == destination.name) {
                        withAnimation(Theme.Plan.Motion.standard) {
                            model.selectDestination(destination)
                        }
                    }
                }
            }
        }
    }

    // MARK: - 2 · Dates

    private var datesStep: some View {
        VStack(alignment: .leading, spacing: Theme.S.s5) {
            DatePicker(selection: $model.startDate,
                       in: model.earliestStartDate...,
                       displayedComponents: .date) {
                Text("slot.dates")
                    .viharaText(Theme.Plan.F.meta)
                    .foregroundStyle(Theme.C.textMuted)
            }
            .datePickerStyle(.compact)
            .tint(Theme.C.accent)
            .padding(Theme.S.s3)
            .background {
                RoundedRectangle(cornerRadius: Theme.R.compactCard, style: .continuous)
                    .fill(Theme.C.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.R.compactCard, style: .continuous)
                            .strokeBorder(Theme.C.border, lineWidth: Theme.Size.hairline)
                    }
            }

            StepperControl(title: "slot.nights",
                           value: HomeDisplay.nights(model.nights, locale: locale),
                           range: 1...30,
                           count: Binding(get: { model.nights },
                                          set: { model.setNights($0) }))
                .padding(Theme.S.s4)
                .background {
                    RoundedRectangle(cornerRadius: Theme.R.compactCard, style: .continuous)
                        .fill(Theme.C.surface)
                        .overlay {
                            RoundedRectangle(cornerRadius: Theme.R.compactCard, style: .continuous)
                                .strokeBorder(Theme.C.border, lineWidth: Theme.Size.hairline)
                        }
                }

            NotePanel {
                Text(localized("days.count", model.nights + 1, locale: locale))
                    .viharaText(Theme.Plan.F.meta)
                    .foregroundStyle(Theme.C.accentDeep)
            }
        }
    }

    // MARK: - 3 · Style and pace

    private var paceStep: some View {
        VStack(alignment: .leading, spacing: Theme.S.s5) {
            VStack(spacing: Theme.S.s2) {
                InterviewOptionCard(title: "style.cityBreak",
                                    subtitle: "style.cityBreak.detail",
                                    iconName: "building.2",
                                    isSelected: model.travelStyle == .cityBreak) {
                    model.travelStyle = .cityBreak
                }
                InterviewOptionCard(title: "style.roundTrip",
                                    subtitle: "style.roundTrip.detail",
                                    iconName: "map",
                                    isSelected: model.travelStyle == .roundTrip) {
                    model.travelStyle = .roundTrip
                }
            }

            VStack(spacing: Theme.S.s2) {
                ForEach(TripBrief.Pace.allCases, id: \.self) { pace in
                    InterviewOptionCard(title: LocalizedStringKey("pace.\(pace.rawValue)"),
                                        subtitle: LocalizedStringKey("pace.\(pace.rawValue).detail"),
                                        iconName: symbol(for: pace),
                                        isSelected: !model.isCustomPace && model.pace == pace) {
                        withAnimation(Theme.Plan.Motion.standard) { model.selectPace(pace) }
                    }
                }

                // The last card of the step is always the traveller's own numbers.
                InterviewOptionCard(title: "interview.custom",
                                    subtitle: "interview.custom.subtitle",
                                    iconName: "slider.horizontal.3",
                                    isSelected: model.isCustomPace,
                                    footnote: paceFootnote,
                                    action: {
                    withAnimation(Theme.Plan.Motion.standard) { model.selectCustomPace() }
                }) {
                    customPaceControls
                }
            }
        }
    }

    @ViewBuilder
    private var customPaceControls: some View {
        if model.paceOverride != nil {
            let override = Binding(get: { model.paceOverride ?? .init() },
                                   set: { model.paceOverride = $0 })

            StepperControl(title: "interview.control.perBlock",
                           value: "\(override.wrappedValue.itemsPerBlock)",
                           range: 1...3,
                           count: Binding(get: { override.wrappedValue.itemsPerBlock },
                                          set: { override.wrappedValue.itemsPerBlock = $0 }))

            SegmentedChips(title: "interview.control.startTime",
                           options: [7, 8, 9, 10, 11].map { hour in
                               .init(id: "\(hour)",
                                     value: hour,
                                     label: MinuteOfDay(hour: hour).label)
                           },
                           selection: Binding(get: { override.wrappedValue.dayStartsAt.hour },
                                              set: { override.wrappedValue.dayStartsAt = MinuteOfDay(hour: $0) }))

            AccentSlider(title: "interview.control.walking",
                         value: walkingLabel(override.wrappedValue.walkingMetres),
                         range: 500...3000,
                         step: 100,
                         amount: Binding(get: { Double(override.wrappedValue.walkingMetres) },
                                         set: { override.wrappedValue.walkingMetres = Int($0) }))
        }
    }

    /// What the current numbers produce. The reason the card is worth expanding.
    private var paceFootnote: String {
        let brief = model.brief
        let blocks = localized("interview.footnote.blocks",
                               brief.estimatedBlockCount,
                               brief.dayCount,
                               locale: locale)
        let meal = localized("interview.footnote.meal",
                             brief.party.eveningMealStart.label,
                             locale: locale)
        return "\(blocks) \(meal)"
    }

    /// Metres are how composition thinks; minutes are how a traveller does. Roughly
    /// 80 m a minute at a strolling pace.
    private func walkingLabel(_ metres: Int) -> String {
        localized("interview.footnote.walking", max(1, metres / 80), locale: locale)
    }

    private func symbol(for pace: TripBrief.Pace) -> String {
        switch pace {
        case .relaxed:  "cup.and.saucer"
        case .balanced: "figure.walk"
        case .packed:   "bolt"
        }
    }

    // MARK: - 5 · Budget and diet

    private var budgetStep: some View {
        VStack(alignment: .leading, spacing: Theme.S.s5) {
            VStack(spacing: Theme.S.s2) {
                ForEach(TripBrief.BudgetBand.allCases, id: \.self) { band in
                    InterviewOptionCard(title: LocalizedStringKey("budget.\(band.rawValue)"),
                                        subtitle: LocalizedStringKey("budget.\(band.rawValue).detail"),
                                        iconName: budgetSymbol(band),
                                        isSelected: model.budget == band) {
                        model.budget = band
                    }
                }
            }

            VStack(spacing: Theme.S.s2) {
                ForEach(TripBrief.DietRequirement.allCases, id: \.self) { diet in
                    InterviewOptionCard(title: LocalizedStringKey("diet.\(diet.rawValue)"),
                                        subtitle: LocalizedStringKey("diet.\(diet.rawValue).detail"),
                                        iconName: dietSymbol(diet),
                                        isSelected: model.diet == diet) {
                        model.diet = diet
                    }
                }
            }
        }
    }

    private func budgetSymbol(_ band: TripBrief.BudgetBand) -> String {
        switch band {
        case .thrifty: "tag"
        case .middle:  "creditcard"
        case .premium: "sparkles"
        }
    }

    private func dietSymbol(_ diet: TripBrief.DietRequirement) -> String {
        switch diet {
        case .none:       "fork.knife"
        case .vegetarian: "leaf"
        case .vegan:      "carrot"
        }
    }

    // MARK: - 6 · Summary

    private var summaryStep: some View {
        VStack(alignment: .leading, spacing: Theme.S.s4) {
            VStack(alignment: .leading, spacing: Theme.S.s3) {
                summaryRow("slot.destination", model.destinationName)
                summaryRow("slot.dates", model.startDate.formatted(
                    .dateTime.weekday(.abbreviated).day().month(.wide).locale(locale)))
                summaryRow("slot.nights", HomeDisplay.nights(model.nights, locale: locale))
                summaryRow("style.cityBreak", localized("style.\(model.travelStyle.rawValue)",
                                                        locale: locale))
                summaryRow("slot.pace", paceSummary)
                summaryRow("slot.party", HomeDisplay.partyLabel(model.party, locale: locale))
                summaryRow("slot.diet", localized("diet.\(model.diet.rawValue)", locale: locale))
            }
            .padding(Theme.S.s4)
            .background {
                RoundedRectangle(cornerRadius: Theme.R.compactCard, style: .continuous)
                    .fill(Theme.C.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.R.compactCard, style: .continuous)
                            .strokeBorder(Theme.C.border, lineWidth: Theme.Size.hairline)
                    }
                    .viharaShadow(Theme.Shadow.card)
            }

            NotePanel {
                Text(paceFootnote)
                    .viharaText(Theme.Plan.F.meta)
                    .foregroundStyle(Theme.C.accentDeep)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var paceSummary: String {
        model.isCustomPace
            ? localized("interview.custom", locale: locale)
            : localized("pace.\(model.pace.rawValue)", locale: locale)
    }

    private func summaryRow(_ title: LocalizedStringKey, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .viharaText(Theme.Plan.F.meta)
                .foregroundStyle(Theme.C.textMuted)

            Spacer(minLength: Theme.S.s3)

            Text(value)
                .viharaText(Theme.F.compactTitle)
                .foregroundStyle(Theme.C.text)
                .multilineTextAlignment(.trailing)
        }
    }

    // MARK: - Bottom bar

    private var bottomActionBar: some View {
        VStack(spacing: Theme.S.s2) {
            if model.isLastStep {
                PrimaryAction(title: localized("interview.create", locale: locale),
                              isEnabled: model.canProceed) {
                    model.clearDraft()
                    dismiss()
                    router.push(.plan(brief: model.brief))
                }
            } else {
                PrimaryAction(title: localized("interview.next", locale: locale),
                              isEnabled: model.canProceed) {
                    withAnimation(Theme.Plan.Motion.standard) { model.nextStep() }
                }
            }
        }
        .padding(.horizontal, Theme.S.screen)
        .padding(.vertical, Theme.S.s3)
        .background(Theme.C.bg)
    }
}

#Preview("Interview · Deutsch") {
    let dependencies = AppDependencies.stubbed()
    return TripPlannerInterviewView(
        model: TripPlannerInterviewViewModel(catalogue: dependencies.destinations,
                                             drafts: dependencies.interviewDrafts)
    )
    .environment(Router())
    .environment(\.locale, Locale(identifier: "de"))
}

#Preview("Interview · English") {
    let dependencies = AppDependencies.stubbed()
    return TripPlannerInterviewView(
        model: TripPlannerInterviewViewModel(catalogue: dependencies.destinations,
                                             drafts: dependencies.interviewDrafts)
    )
    .environment(Router())
    .environment(\.locale, Locale(identifier: "en"))
}
