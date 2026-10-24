import SwiftUI

/// Step 4 — who is coming.
///
/// The most consequential question in the interview, and the one most often reduced
/// to a headcount. Ages matter because age limits are real: the Torre degli Asinelli
/// turns away anyone under twelve, and a plan that puts a family with a seven-year-old
/// at its foot has wasted their afternoon before they set off.
///
/// Everything the traveller sets here is answered back in the panel at the bottom,
/// computed from the same values composition reads. That panel is the point of the
/// step — a question whose consequences cannot be named should not be asked.
struct TravelPartyStepView: View {
    @Environment(\.locale) private var locale
    @Bindable var model: TripPlannerInterviewViewModel

    @State private var editingChild: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.S.s5) {
            presets
            counts
            childAges
            accommodations
            effects
        }
        .sheet(item: $editingChild) { index in
            ChildAgeSheet(index: index,
                          age: model.party.childAges.indices.contains(index)
                              ? model.party.childAges[index] : 7) { age in
                model.setAge(age, forChildAt: index)
            }
        }
    }

    // MARK: - Presets

    private var presets: some View {
        VStack(spacing: Theme.S.s2) {
            preset(.solo, title: "party.preset.solo",
                   detail: "party.preset.solo.detail", symbol: "person")
            preset(.couple, title: "party.preset.couple",
                   detail: "party.preset.couple.detail", symbol: "person.2")
            preset(.family, title: "party.preset.family",
                   detail: "party.preset.family.detail", symbol: "figure.2.and.child.holdinghands")
        }
    }

    private func preset(_ value: TravelParty,
                        title: LocalizedStringKey,
                        detail: LocalizedStringKey,
                        symbol: String) -> some View {
        InterviewOptionCard(title: title,
                            subtitle: detail,
                            iconName: symbol,
                            isSelected: matches(value)) {
            withAnimation(Theme.Plan.Motion.standard) { model.applyPreset(value) }
        }
    }

    /// A preset is "selected" while the party still has its shape. Touching a stepper
    /// moves off it, which is correct — the tiles are starting points, not modes.
    private func matches(_ preset: TravelParty) -> Bool {
        model.party.adults == preset.adults && model.party.childAges.count == preset.childAges.count
    }

    // MARK: - Counts

    private var counts: some View {
        VStack(alignment: .leading, spacing: Theme.S.s3) {
            StepperControl(title: "party.adults",
                           value: "\(model.party.adults)",
                           range: 1...9,
                           count: Binding(get: { model.party.adults },
                                          set: { model.setAdults($0) }))

            Divider().background(Theme.C.border)

            StepperControl(title: "party.children",
                           value: "\(model.party.childCount)",
                           range: 0...6,
                           count: Binding(get: { model.party.childCount },
                                          set: { model.setChildren($0) }))
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
    }

    // MARK: - Ages

    @ViewBuilder
    private var childAges: some View {
        if model.party.hasChildren {
            FlowLayout(spacing: Theme.S.s2, lineSpacing: Theme.S.s2) {
                ForEach(Array(model.party.childAges.enumerated()), id: \.offset) { index, age in
                    Button {
                        editingChild = index
                    } label: {
                        Text(childLabel(index: index, age: age))
                            .viharaText(Theme.F.chip)
                            .foregroundStyle(Theme.C.text)
                            .padding(.horizontal, Theme.S.s4)
                            .padding(.vertical, Theme.S.s2)
                            .frame(minHeight: Theme.S.tapTarget)
                            .background {
                                RoundedRectangle(cornerRadius: Theme.R.pill, style: .continuous)
                                    .fill(Theme.C.surface)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: Theme.R.pill, style: .continuous)
                                            .strokeBorder(Theme.C.accent,
                                                          lineWidth: Theme.Size.hairline)
                                    }
                            }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(Text(localized("party.child.pick", index + 1, locale: locale)))
                }
            }
        }
    }

    private func childLabel(index: Int, age: Int) -> String {
        age == 1 ? localized("party.child.age.one", index + 1, locale: locale)
                 : localized("party.child.age", index + 1, age, locale: locale)
    }

    // MARK: - Accommodations

    private var accommodations: some View {
        VStack(alignment: .leading, spacing: Theme.S.s3) {
            Text("party.accommodations.title")
                .viharaText(Theme.Plan.F.blockLabel)
                .foregroundStyle(Theme.C.textFaint)

            FlowLayout(spacing: Theme.S.s2, lineSpacing: Theme.S.s2) {
                ForEach(TravelParty.Accommodation.allCases) { accommodation in
                    SelectChip(title: LocalizedStringKey(accommodation.localizationKey),
                               symbol: accommodation.symbol,
                               isSelected: model.party.accommodations.contains(accommodation)) {
                        withAnimation(Theme.Plan.Motion.standard) {
                            model.toggle(accommodation)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Consequences

    private var effects: some View {
        NotePanel(title: "party.effects.title") {
            if model.partyEffects.isEmpty {
                Text("party.effects.none")
                    .viharaText(Theme.Plan.F.meta)
                    .foregroundStyle(Theme.C.accentDeep)
            } else {
                VStack(alignment: .leading, spacing: Theme.S.s2) {
                    ForEach(model.partyEffects) { effect in
                        Text(PartyEffectDisplay.sentence(for: effect, locale: locale))
                            .viharaText(Theme.Plan.F.meta)
                            // A dropped stop is something taken away, so it is drawn
                            // like a cost rather than like the planner's working.
                            .foregroundStyle(PartyEffectDisplay.isLoss(effect)
                                             ? Theme.C.price : Theme.C.accentDeep)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .animation(Theme.Plan.Motion.standard, value: model.partyEffects)
    }
}

// MARK: - Age picker

/// One child's age.
///
/// A sheet rather than an inline wheel: ages only change when somebody taps the chip,
/// and a picker sitting permanently in the step would take more room than the four
/// controls above it combined.
private struct ChildAgeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    let index: Int
    @State var age: Int
    let onPick: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.S.s4) {
            Text(localized("party.child.pick", index + 1, locale: locale))
                .viharaText(Theme.F.h3)
                .foregroundStyle(Theme.C.text)

            FlowLayout(spacing: Theme.S.s2, lineSpacing: Theme.S.s2) {
                ForEach(0...17, id: \.self) { candidate in
                    Button {
                        age = candidate
                        onPick(candidate)
                        Haptics.pickUp()
                        dismiss()
                    } label: {
                        Text("\(candidate)")
                            .viharaText(Theme.F.chip)
                            .monospacedDigit()
                            .foregroundStyle(candidate == age ? Theme.C.surface : Theme.C.text)
                            .frame(minWidth: Theme.S.tapTarget, minHeight: Theme.S.tapTarget)
                            .background {
                                let shape = Circle()
                                if candidate == age {
                                    shape.fill(Theme.C.text)
                                } else {
                                    shape.strokeBorder(Theme.C.border, lineWidth: Theme.Size.hairline)
                                }
                            }
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(localized("party.child.years", candidate, locale: locale)))
                }
            }

            Spacer(minLength: 0)
        }
        .padding(Theme.S.screen)
        .background(Theme.C.bg.ignoresSafeArea())
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

/// `sheet(item:)` needs an `Identifiable`, and an index is the identity here.
extension Int: @retroactive Identifiable {
    public var id: Int { self }
}

// MARK: - Wording

enum PartyEffectDisplay {

    static func sentence(for effect: TravelPartyEffect, locale: Locale) -> String {
        switch effect {
        case let .stopDropped(place, minimumAge, childAge):
            localized("party.effect.dropped", place, minimumAge, childAge, locale: locale)
        case let .afternoonHeldForNap(window):
            localized("party.effect.nap", window.label, locale: locale)
        case let .dinnerMovedEarlier(time):
            localized("party.effect.dinner", time.label, locale: locale)
        case let .childrenEnterFree(count, place):
            localized("party.effect.free", count, place, locale: locale)
        case let .admission(place, total, heads):
            localized("party.effect.admission", place, total.label(locale: locale), heads, locale: locale)
        case .stepFreeOnly:
            localized("party.effect.stepFree", locale: locale)
        case .noLongStanding:
            localized("party.effect.standing", locale: locale)
        }
    }

    /// Whether the effect takes something away rather than adding to the plan.
    static func isLoss(_ effect: TravelPartyEffect) -> Bool {
        if case .stopDropped = effect { return true }
        return false
    }
}

extension Money {
    /// "24,00 €" — the locale decides where the symbol goes.
    func label(locale: Locale) -> String {
        amount.formatted(.currency(code: currency.rawValue.uppercased()).locale(locale))
    }
}

#Preview("Begleitung · Deutsch") {
    let dependencies = AppDependencies.stubbed()
    let model = TripPlannerInterviewViewModel(catalogue: dependencies.destinations)
    model.destinationName = "Bologna"
    model.party = TravelParty(adults: 2, childAges: [4], accommodations: [.middaySleep])

    return ScrollView {
        TravelPartyStepView(model: model)
            .padding(Theme.S.screen)
    }
    .background(Theme.C.bg)
    .environment(\.locale, Locale(identifier: "de"))
    .task { await model.load() }
}

#Preview("Party · English") {
    let dependencies = AppDependencies.stubbed()
    let model = TripPlannerInterviewViewModel(catalogue: dependencies.destinations)
    model.destinationName = "Bologna"
    model.party = TravelParty(adults: 2, childAges: [4, 9], accommodations: [.pushchair])

    return ScrollView {
        TravelPartyStepView(model: model)
            .padding(Theme.S.screen)
    }
    .background(Theme.C.bg)
    .environment(\.locale, Locale(identifier: "en"))
    .task { await model.load() }
}
