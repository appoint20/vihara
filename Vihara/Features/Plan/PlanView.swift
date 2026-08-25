import SwiftUI

/// F-02 — the plan.
///
/// A vertical list of days and nothing else: no dashboard, no map behind it, no
/// counters. Days appear as they validate, so this screen is readable seconds after
/// it opens rather than after the whole trip is composed.
struct PlanView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: PlanViewModel

    init(model: PlanViewModel) {
        _model = State(wrappedValue: model)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Theme.Plan.S.day) {
                header

                ForEach(model.days) { day in
                    DayView(day: day, warnings: model.warnings(for: day))
                }

                if model.showsSkeleton {
                    DaySkeletonView(dayNumber: model.days.count + 1)
                }

                if case let .failed(error) = model.phase {
                    failure(error)
                }

                if model.phase == .ready {
                    footnote
                }
            }
            .padding(.horizontal, Theme.Plan.S.screen)
            .padding(.bottom, Theme.Plan.S.day)
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(Theme.Plan.Motion.dayArrival, value: model.days.count)
        }
        .background(Theme.C.bg.ignoresSafeArea())
        .safeAreaInset(edge: .top, spacing: 0) {
            BackControl { dismiss() }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Theme.Plan.S.screen - Theme.S.s4)
                .background(Theme.C.bg)
        }
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            shareAction
        }
        .task { model.startIfNeeded() }
        .onDisappear { model.cancel() }
    }

    /// The screen's one primary action (PRD 5.1, rule 3).
    ///
    /// Sharing rather than exporting: a `ShareLink` needs no paywall, no account and
    /// no PDF renderer, so the plan becomes portable now instead of in phase 1. It
    /// appears only once generation finishes — offering to share half a plan invites
    /// the traveller to send someone a trip that is still being written.
    ///
    /// A `ShareLink` rather than a ``PrimaryAction`` wrapping one, because the system
    /// control brings its own accessibility and its own press behaviour; only the
    /// label is ours.
    @ViewBuilder
    private var shareAction: some View {
        if model.phase == .ready {
            ShareLink(item: model.shareText) {
                Text("Plan teilen")
                    .viharaText(Theme.Plan.F.action)
                    .foregroundStyle(Theme.C.bg)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: Theme.S.tapTarget + Theme.Plan.S.s1)
                    .background(Theme.C.text,
                                in: RoundedRectangle(cornerRadius: Theme.Plan.R.surface,
                                                     style: .continuous))
            }
            .padding(.horizontal, Theme.Plan.S.screen)
            .padding(.top, Theme.Plan.S.s2)
            .padding(.bottom, Theme.Plan.S.s3)
            .background(Theme.C.bg)
            .transition(.opacity)
            .animation(Theme.Plan.Motion.standard, value: model.phase)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Plan.S.s1) {
            Text(model.title)
                .viharaText(Theme.Plan.F.dayTitle)
                .foregroundStyle(Theme.C.text)
            Text(model.subtitle)
                .viharaText(Theme.Plan.F.meta)
                .foregroundStyle(Theme.C.textMuted)
        }
        .accessibilityElement(children: .combine)
    }

    private func failure(_ error: DomainError) -> some View {
        VStack(alignment: .leading, spacing: Theme.Plan.S.s3) {
            WarningLine(text: error.message)
            Button {
                model.retry()
            } label: {
                Text("Erneut versuchen")
                    .viharaText(Theme.Plan.F.meta)
                    .foregroundStyle(Theme.C.accentDeep)
                    .viharaInlineHitTarget()
            }
            .buttonStyle(.plain)
        }
    }

    /// Required by the AI-transparency rule (PRD 8): the traveller is told, once and
    /// without drama, that a machine wrote this and that it can be wrong.
    ///
    /// **This sentence may not claim live validation until F-03 exists.** It used to
    /// read "gegen Live-Daten geprüft", which was untrue — the hours and addresses
    /// are literals in `SampleItineraries`. That claim is the product's central
    /// promise and the meaning behind the word *bestätigt*; it has to be earned
    /// before it is printed. Restore the stronger wording in the same commit that
    /// turns on the validation gate, and not before.
    private var footnote: some View {
        Text("Dieser Plan wurde automatisch erstellt. Öffnungszeiten und Adressen sind noch nicht gegen Live-Daten geprüft — bitte kurz vor Ort bestätigen.")
            .viharaText(Theme.Plan.F.meta)
            .foregroundStyle(Theme.C.textFaint)
            .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview {
    let dependencies = AppDependencies.stubbed()
    let brief = TripBrief(destination: "Bologna",
                          startDate: .now,
                          nights: 3,
                          pace: .relaxed,
                          diet: .vegetarian)
    return NavigationStack {
        PlanView(model: PlanViewModel(brief: brief, generateTrip: dependencies.generateTrip))
    }
}
