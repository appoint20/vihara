import SwiftUI

/// Wanderlog-style interactive trip planner interview flow.
///
/// Guides the traveller through structured steps (Destination, Dates, Style, Budget/Diet)
/// while compiling a valid ``TripBrief`` for instant itinerary generation.
struct TripPlannerInterviewView: View {
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
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
        .task {
            await model.load()
        }
    }

    // MARK: - Navigation & Progress

    private var topNavigation: some View {
        HStack {
            if model.currentStep > .destination {
                BackControl {
                    withAnimation(Theme.Plan.Motion.standard) {
                        model.previousStep()
                    }
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
                .accessibilityLabel("Schließen")
            }

            Spacer()

            Text("Schritt \(model.currentStep.rawValue + 1) von \(TripPlannerInterviewViewModel.Step.allCases.count)")
                .viharaText(Theme.Plan.F.blockLabel)
                .foregroundStyle(Theme.C.textFaint)
        }
        .padding(.horizontal, Theme.S.screen)
        .padding(.top, Theme.S.s2)
    }

    private var progressBar: some View {
        GeometryReader { proxy in
            let totalSteps = CGFloat(TripPlannerInterviewViewModel.Step.allCases.count)
            let current = CGFloat(model.currentStep.rawValue + 1)
            let progressWidth = (proxy.size.width * (current / totalSteps))

            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Theme.C.border)
                    .frame(height: 3)

                Rectangle()
                    .fill(Theme.C.accent)
                    .frame(width: progressWidth, height: 3)
            }
        }
        .frame(height: 3)
        .padding(.top, Theme.S.s2)
        .animation(Theme.Plan.Motion.standard, value: model.currentStep)
    }

    // MARK: - Step Header

    private var stepHeader: some View {
        VStack(alignment: .leading, spacing: Theme.S.s1) {
            Text(model.currentStep.title)
                .viharaText(Theme.Plan.F.dayTitle)
                .foregroundStyle(Theme.C.text)

            Text(model.currentStep.subtitle)
                .viharaText(Theme.Plan.F.meta)
                .foregroundStyle(Theme.C.textMuted)
        }
    }

    // MARK: - Dynamic Step Content

    @ViewBuilder
    private var stepContent: some View {
        switch model.currentStep {
        case .destination:
            destinationStep
        case .datesAndDuration:
            datesAndDurationStep
        case .styleAndPace:
            styleAndPaceStep
        case .budgetAndDiet:
            budgetAndDietStep
        case .summary:
            summaryStep
        }
    }

    // MARK: - Step 1: Destination

    private var destinationStep: some View {
        VStack(alignment: .leading, spacing: Theme.S.s4) {
            CitySearchField(text: $model.searchQuery,
                            placeholder: "Stadt eingeben (z.B. Bologna, Rom...)") {
                Task { await model.updateSearch() }
            } onClear: {
                Task { await model.updateSearch() }
            }
            .onChange(of: model.searchQuery) { _, newValue in
                if !newValue.isEmpty {
                    model.applyCustomDestination(newValue)
                }
                Task { await model.updateSearch() }
            }

            if !model.destinationName.isEmpty {
                HStack(spacing: Theme.S.s2) {
                    Text("Ausgewählt:")
                        .viharaText(Theme.Plan.F.blockLabel)
                        .foregroundStyle(Theme.C.textFaint)

                    Text(model.destinationName)
                        .viharaText(Theme.F.compactTitle)
                        .foregroundStyle(Theme.C.accentDeep)
                }
                .padding(.horizontal, Theme.S.s2)
            }

            Text("Kuratierte Regionen")
                .viharaText(Theme.Plan.F.blockLabel)
                .foregroundStyle(Theme.C.textFaint)
                .padding(.top, Theme.S.s2)

            VStack(spacing: Theme.S.s2) {
                ForEach(model.searchResults) { dest in
                    let isSelected = model.destinationName == dest.name
                    Button {
                        withAnimation(Theme.Plan.Motion.standard) {
                            model.selectDestination(dest)
                        }
                    } label: {
                        HStack(spacing: Theme.S.s3) {
                            RoundedRectangle(cornerRadius: Theme.R.compactThumb, style: .continuous)
                                .fill(Theme.C.imageFallback)
                                .frame(width: 44, height: 44)
                                .overlay {
                                    Image(systemName: "building.2")
                                        .foregroundStyle(.white.opacity(0.8))
                                }

                            VStack(alignment: .leading, spacing: Theme.S.s05) {
                                Text(dest.name)
                                    .viharaText(Theme.F.cardTitle)
                                    .foregroundStyle(Theme.C.text)

                                Text(dest.region)
                                    .viharaText(Theme.Plan.F.meta)
                                    .foregroundStyle(Theme.C.textMuted)
                            }

                            Spacer()

                            Text("★ \(dest.formattedRating)")
                                .viharaText(Theme.F.rating)
                                .foregroundStyle(Theme.C.textMuted)

                            Circle()
                                .strokeBorder(isSelected ? Theme.C.accent : Theme.C.border, lineWidth: isSelected ? 4 : 1)
                                .frame(width: 18, height: 18)
                        }
                        .padding(Theme.S.s3)
                        .background {
                            RoundedRectangle(cornerRadius: Theme.R.compactCard, style: .continuous)
                                .fill(isSelected ? Theme.C.surface : Theme.C.surface.opacity(0.8))
                                .overlay {
                                    RoundedRectangle(cornerRadius: Theme.R.compactCard, style: .continuous)
                                        .strokeBorder(isSelected ? Theme.C.accent : Theme.C.border, lineWidth: isSelected ? 1.5 : Theme.Size.hairline)
                                }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Step 2: Dates & Duration

    private var datesAndDurationStep: some View {
        VStack(alignment: .leading, spacing: Theme.S.s5) {
            // Quick Date Presets
            VStack(alignment: .leading, spacing: Theme.S.s2) {
                Text("Startdatum")
                    .viharaText(Theme.Plan.F.blockLabel)
                    .foregroundStyle(Theme.C.textFaint)

                HStack(spacing: Theme.S.s2) {
                    quickDateChip("Nächstes WE", days: 7)
                    quickDateChip("In 2 Wochen", days: 14)
                    quickDateChip("In 1 Monat", days: 30)
                }

                DatePicker("Abreisedatum",
                           selection: $model.startDate,
                           in: model.earliestStartDate...,
                           displayedComponents: .date)
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
            }

            // Duration Stepper & Presets
            VStack(alignment: .leading, spacing: Theme.S.s2) {
                Text("Dauer der Reise")
                    .viharaText(Theme.Plan.F.blockLabel)
                    .foregroundStyle(Theme.C.textFaint)

                HStack {
                    VStack(alignment: .leading, spacing: Theme.S.s05) {
                        Text("\(model.nights) Nächte")
                            .viharaText(Theme.Plan.F.dayTitle)
                            .foregroundStyle(Theme.C.text)

                        Text("entspricht \(model.nights + 1) Reisetagen")
                            .viharaText(Theme.Plan.F.meta)
                            .foregroundStyle(Theme.C.textMuted)
                    }

                    Spacer()

                    HStack(spacing: Theme.S.s2) {
                        durationButton(symbol: "minus", label: "Weniger") {
                            model.adjustNights(by: -1)
                        }

                        durationButton(symbol: "plus", label: "Mehr") {
                            model.adjustNights(by: 1)
                        }
                    }
                }
                .padding(Theme.S.s4)
                .background {
                    RoundedRectangle(cornerRadius: Theme.R.compactCard, style: .continuous)
                        .fill(Theme.C.surface)
                        .overlay {
                            RoundedRectangle(cornerRadius: Theme.R.compactCard, style: .continuous)
                                .strokeBorder(Theme.C.border, lineWidth: Theme.Size.hairline)
                        }
                }

                HStack(spacing: Theme.S.s2) {
                    durationPresetChip("Wochenende (2 N)", nights: 2)
                    durationPresetChip("Kurztrip (3 N)", nights: 3)
                    durationPresetChip("1 Woche (6 N)", nights: 6)
                }
            }
        }
    }

    private func quickDateChip(_ label: String, days: Int) -> some View {
        Button {
            withAnimation(Theme.Plan.Motion.standard) {
                model.setQuickDate(daysFromNow: days)
            }
        } label: {
            Text(label)
                .viharaText(Theme.Plan.F.meta)
                .foregroundStyle(Theme.C.text)
                .padding(.horizontal, Theme.S.s3)
                .padding(.vertical, Theme.S.s2)
                .background {
                    RoundedRectangle(cornerRadius: Theme.R.pill, style: .continuous)
                        .strokeBorder(Theme.C.border, lineWidth: Theme.Size.hairline)
                }
        }
        .buttonStyle(.plain)
    }

    private func durationPresetChip(_ label: String, nights: Int) -> some View {
        let isSelected = model.nights == nights
        return Button {
            withAnimation(Theme.Plan.Motion.standard) {
                model.setNights(nights)
            }
        } label: {
            Text(label)
                .viharaText(Theme.Plan.F.meta)
                .foregroundStyle(isSelected ? Theme.C.accentDeep : Theme.C.text)
                .padding(.horizontal, Theme.S.s3)
                .padding(.vertical, Theme.S.s2)
                .background {
                    RoundedRectangle(cornerRadius: Theme.R.pill, style: .continuous)
                        .fill(isSelected ? Theme.C.surface : Theme.C.surface.opacity(0.6))
                        .overlay {
                            RoundedRectangle(cornerRadius: Theme.R.pill, style: .continuous)
                                .strokeBorder(isSelected ? Theme.C.accent : Theme.C.border,
                                              lineWidth: isSelected ? 1.5 : Theme.Size.hairline)
                        }
                }
        }
        .buttonStyle(.plain)
    }

    private func durationButton(symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .viharaText(Theme.F.glyph)
                .foregroundStyle(Theme.C.accentDeep)
                .frame(width: Theme.S.tapTarget, height: Theme.S.tapTarget)
                .background {
                    Circle()
                        .strokeBorder(Theme.C.border, lineWidth: Theme.Size.hairline)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Step 3: Style & Pace

    private var styleAndPaceStep: some View {
        VStack(alignment: .leading, spacing: Theme.S.s5) {
            VStack(alignment: .leading, spacing: Theme.S.s2) {
                Text("Reiseart")
                    .viharaText(Theme.Plan.F.blockLabel)
                    .foregroundStyle(Theme.C.textFaint)

                VStack(spacing: Theme.S.s2) {
                    InterviewOptionCard(title: "Städtereise",
                                        subtitle: "Fokus auf eine Stadt, Kultur, Genuss & Viertel",
                                        iconName: "building.2",
                                        isSelected: model.travelStyle == .cityBreak) {
                        model.travelStyle = .cityBreak
                    }

                    InterviewOptionCard(title: "Rundreise",
                                        subtitle: "Mehrere Etappen, Tagesausflüge & Region",
                                        iconName: "map",
                                        isSelected: model.travelStyle == .roundTrip) {
                        model.travelStyle = .roundTrip
                    }
                }
            }

            VStack(alignment: .leading, spacing: Theme.S.s2) {
                Text("Tages-Tempo")
                    .viharaText(Theme.Plan.F.blockLabel)
                    .foregroundStyle(Theme.C.textFaint)

                VStack(spacing: Theme.S.s2) {
                    InterviewOptionCard(title: "Entspannt",
                                        subtitle: "1 Highlight pro Block · Viel Zeit zum Treibenlassen",
                                        iconName: "cup.and.saucer",
                                        isSelected: model.pace == .relaxed) {
                        model.pace = .relaxed
                    }

                    InterviewOptionCard(title: "Ausgewogen",
                                        subtitle: "2 Highlights pro Block · Die goldene Mitte",
                                        iconName: "figure.walk",
                                        isSelected: model.pace == .balanced) {
                        model.pace = .balanced
                    }

                    InterviewOptionCard(title: "Intensiv",
                                        subtitle: "3 Highlights pro Block · Maximal viel entdecken",
                                        iconName: "bolt",
                                        isSelected: model.pace == .packed) {
                        model.pace = .packed
                    }
                }
            }
        }
    }

    // MARK: - Step 4: Budget & Diet

    private var budgetAndDietStep: some View {
        VStack(alignment: .leading, spacing: Theme.S.s5) {
            VStack(alignment: .leading, spacing: Theme.S.s2) {
                Text("Budget-Rahmen")
                    .viharaText(Theme.Plan.F.blockLabel)
                    .foregroundStyle(Theme.C.textFaint)

                VStack(spacing: Theme.S.s2) {
                    InterviewOptionCard(title: "Günstig",
                                        subtitle: "Fokus auf kostenlose Kultur & Street Food",
                                        iconName: "tag",
                                        isSelected: model.budget == .thrifty) {
                        model.budget = .thrifty
                    }

                    InterviewOptionCard(title: "Mittel",
                                        subtitle: "Gute Trattorien, Museen & ausgewählte Erlebnisse",
                                        iconName: "creditcard",
                                        isSelected: model.budget == .middle) {
                        model.budget = .middle
                    }

                    InterviewOptionCard(title: "Gehoben",
                                        subtitle: "Besondere Restaurants, Führungen & Premium-Spots",
                                        iconName: "sparkles",
                                        isSelected: model.budget == .premium) {
                        model.budget = .premium
                    }
                }
            }

            VStack(alignment: .leading, spacing: Theme.S.s2) {
                Text("Ernährung & Präferenzen")
                    .viharaText(Theme.Plan.F.blockLabel)
                    .foregroundStyle(Theme.C.textFaint)

                VStack(spacing: Theme.S.s2) {
                    InterviewOptionCard(title: "Keine Einschränkung",
                                        subtitle: "Volle Auswahl aller lokalen Spezialitäten",
                                        iconName: "fork.knife",
                                        isSelected: model.diet == .none) {
                        model.diet = .none
                    }

                    InterviewOptionCard(title: "Vegetarisch",
                                        subtitle: "Geprüfte fleischlose Gerichte & Optionen",
                                        iconName: "leaf",
                                        isSelected: model.diet == .vegetarian) {
                        model.diet = .vegetarian
                    }

                    InterviewOptionCard(title: "Vegan",
                                        subtitle: "Rein pflanzliche Restaurantempfehlungen",
                                        iconName: "carrot",
                                        isSelected: model.diet == .vegan) {
                        model.diet = .vegan
                    }
                }
            }
        }
    }

    // MARK: - Step 5: Summary

    private var summaryStep: some View {
        VStack(alignment: .leading, spacing: Theme.S.s4) {
            VStack(alignment: .leading, spacing: Theme.S.s3) {
                summaryRow(title: "Zielort", value: model.destinationName)
                summaryRow(title: "Abreise", value: model.formattedStartDate)
                summaryRow(title: "Dauer", value: "\(model.nights) Nächte (\(model.nights + 1) Tage)")
                summaryRow(title: "Reiseart", value: model.travelStyle.label)
                summaryRow(title: "Tempo", value: model.pace.label)
                summaryRow(title: "Budget", value: model.budget.label)
                summaryRow(title: "Ernährung", value: model.diet.label)
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

            VStack(alignment: .leading, spacing: Theme.S.s1) {
                Text("Zusammenfassung")
                    .viharaText(Theme.Plan.F.blockLabel)
                    .foregroundStyle(Theme.C.textFaint)

                Text("„\(model.synthesizedSentence)“")
                    .viharaText(Theme.Plan.F.meta)
                    .foregroundStyle(Theme.C.accentDeep)
            }
            .padding(.horizontal, Theme.S.s2)
        }
    }

    private func summaryRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .viharaText(Theme.Plan.F.meta)
                .foregroundStyle(Theme.C.textMuted)

            Spacer()

            Text(value)
                .viharaText(Theme.F.compactTitle)
                .foregroundStyle(Theme.C.text)
        }
    }

    // MARK: - Bottom Action Bar

    private var bottomActionBar: some View {
        VStack(spacing: Theme.S.s2) {
            if model.isLastStep {
                PrimaryAction(title: "Plan erstellen", isEnabled: model.canProceed) {
                    dismiss()
                    router.push(.plan(brief: model.brief))
                }
            } else {
                PrimaryAction(title: "Weiter", isEnabled: model.canProceed) {
                    withAnimation(Theme.Plan.Motion.standard) {
                        model.nextStep()
                    }
                }
            }
        }
        .padding(.horizontal, Theme.S.screen)
        .padding(.vertical, Theme.S.s3)
        .background(Theme.C.bg)
    }
}

#Preview {
    let dependencies = AppDependencies.stubbed()
    return TripPlannerInterviewView(model: TripPlannerInterviewViewModel(catalogue: dependencies.destinations))
        .environment(Router())
}
