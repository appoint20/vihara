import SwiftUI

/// F-01 — the whole intake, on one screen.
///
/// One question ("worauf hast du Lust?"), one primary action, and the parsed answer
/// mirrored back as chips. Everything the sentence did not say already has a value,
/// so the traveller corrects rather than fills in.
struct IntakeView: View {
    @Environment(\.locale) private var locale
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    @State private var model: IntakeViewModel
    @State private var isEditingDate = false
    @State private var isInterviewPresented = false
    @FocusState private var isWriting: Bool

    init(model: IntakeViewModel) {
        _model = State(wrappedValue: model)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Plan.S.block) {
                prompt
                sentenceField
                if model.hasBrief { chips }
            }
            .padding(.horizontal, Theme.Plan.S.screen)
            .padding(.top, Theme.Plan.S.s2)
            .padding(.bottom, Theme.Plan.S.day)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.C.bg.ignoresSafeArea())
        .safeAreaInset(edge: .top, spacing: 0) {
            BackControl { dismiss() }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Theme.Plan.S.screen - Theme.S.s4)
                .background(Theme.C.bg)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PrimaryAction(title: "Plan erstellen", isEnabled: model.canGenerate) {
                router.push(.plan(brief: model.brief))
            }
            .padding(.horizontal, Theme.Plan.S.screen)
            .padding(.top, Theme.Plan.S.s2)
            .padding(.bottom, Theme.Plan.S.s3)
            .background(Theme.C.bg)
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await model.loadDestinations() }
        .sheet(isPresented: $isEditingDate) { datePicker }
        .sheet(isPresented: $isInterviewPresented) {
            TripPlannerInterviewView(
                model: TripPlannerInterviewViewModel(
                    catalogue: model.catalogue,
                    initialCity: model.brief.destination.isEmpty ? nil : model.brief.destination
                )
            )
        }
    }

    // MARK: - Prompt

    private var prompt: some View {
        VStack(alignment: .leading, spacing: Theme.Plan.S.s2) {
            HStack(alignment: .top) {
                Text("intake.title")
                    .viharaText(Theme.Plan.F.dayTitle)
                    .foregroundStyle(Theme.C.text)

                Spacer()

                Button {
                    isInterviewPresented = true
                } label: {
                    HStack(spacing: Theme.S.s1) {
                        Image(systemName: "sparkles")
                        Text("intake.mode")
                    }
                    .viharaText(Theme.Plan.F.meta)
                    .foregroundStyle(Theme.C.accentDeep)
                    .viharaInlineHitTarget()
                }
                .buttonStyle(.plain)
            }

            Text("intake.hint")
                .viharaText(Theme.Plan.F.meta)
                .foregroundStyle(Theme.C.textMuted)
        }
    }

    private var sentenceField: some View {
        VStack(alignment: .leading, spacing: Theme.Plan.S.s3) {
            TextField("5 Tage Bologna, vegetarisch",
                      text: $model.sentence,
                      axis: .vertical)
                .viharaText(Theme.Plan.F.item)
                .foregroundStyle(Theme.C.text)
                .lineLimit(2...5)
                .focused($isWriting)
                .padding(Theme.Plan.S.s3)
                .background {
                    RoundedRectangle(cornerRadius: Theme.Plan.R.surface, style: .continuous)
                        .strokeBorder(isWriting ? Theme.C.accent : Theme.C.border,
                                      lineWidth: Theme.Size.hairline)
                }

            HStack(spacing: Theme.Plan.S.s3) {
                // Secondary by the rule: textual, no surface of its own.
                Button {
                    isWriting = false
                    Task { await model.interpret() }
                } label: {
                    Text(model.isInterpreting ? "Verstehe …" : "Satz übernehmen")
                        .viharaText(Theme.Plan.F.meta)
                        .foregroundStyle(Theme.C.accentDeep)
                        .viharaInlineHitTarget()
                }
                .buttonStyle(.plain)
                .disabled(model.sentence.isEmpty || model.isInterpreting)

                if let unmatched = model.unrecognisedDestination {
                    Text(localized("intake.unmatched", unmatched, locale: locale))
                        .viharaText(Theme.Plan.F.meta)
                        .foregroundStyle(Theme.C.price)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Chips

    private var chips: some View {
        VStack(alignment: .leading, spacing: Theme.Plan.S.s3) {
            Text("intake.summary")
                .viharaText(Theme.Plan.F.blockLabel)
                .foregroundStyle(Theme.C.textFaint)

            FlowLayout {
                PlanChip(caption: "Ziel",
                         value: model.brief.destination.isEmpty ? "Wählen" : model.brief.destination,
                         isUnset: model.brief.destination.isEmpty) {
                    model.cycleDestination()
                }
                PlanChip(caption: "Ab", value: model.brief.startDateLabel(locale: locale)) {
                    isEditingDate = true
                }
                nightsChip
                PlanChip(caption: "Art", value: model.brief.travelStyle.label(locale: locale)) { model.cycleStyle() }
                PlanChip(caption: "Tempo", value: model.brief.pace.label(locale: locale)) { model.cyclePace() }
                PlanChip(caption: "Budget", value: model.brief.budget.label(locale: locale)) { model.cycleBudget() }
                PlanChip(caption: "Ernährung", value: model.brief.diet.label(locale: locale)) { model.cycleDiet() }
            }
        }
    }

    /// The one chip that is not a cycle: nights step in both directions, so the two
    /// halves are separate controls rather than one that only ever counts up.
    private var nightsChip: some View {
        HStack(spacing: 0) {
            stepper("minus", label: "Eine Nacht weniger") { model.adjustNights(by: -1) }

            VStack(alignment: .leading, spacing: Theme.S.s05) {
                Text("intake.duration")
                    .viharaText(Theme.Plan.F.blockLabel)
                    .foregroundStyle(Theme.C.textFaint)
                Text(model.brief.nightsLabel(locale: locale))
                    .viharaText(Theme.Plan.F.meta)
                    .foregroundStyle(Theme.C.text)
            }
            .accessibilityElement(children: .combine)

            stepper("plus", label: "Eine Nacht mehr") { model.adjustNights(by: 1) }
        }
        .padding(.vertical, Theme.Plan.S.s1 + 1)
        .frame(minHeight: Theme.S.tapTarget)
        .background {
            RoundedRectangle(cornerRadius: Theme.Plan.R.surface, style: .continuous)
                .strokeBorder(Theme.C.border, lineWidth: Theme.Size.hairline)
        }
    }

    private func stepper(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .viharaText(Theme.Plan.F.meta)
                .foregroundStyle(Theme.C.accentDeep)
                .frame(width: Theme.S.tapTarget, height: Theme.S.tapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var datePicker: some View {
        NavigationStack {
            DatePicker("Abreise",
                       selection: Binding(get: { model.brief.startDate },
                                          set: { model.setStartDate($0) }),
                       in: model.earliestStartDate...,
                       displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(Theme.C.accent)
                .padding(Theme.Plan.S.s3)
                .navigationTitle("Abreise")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Fertig") { isEditingDate = false }
                    }
                }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    let dependencies = AppDependencies.stubbed()
    return NavigationStack {
        IntakeView(model: IntakeViewModel(parser: dependencies.briefParser,
                                          catalogue: dependencies.destinations))
    }
    .environment(Router())
}
