import SwiftUI

/// F-02 — the plan.
///
/// A vertical list of days and nothing else: no dashboard, no map behind it, no
/// counters. Days appear as they validate, so this screen is readable seconds after
/// it opens rather than after the whole trip is composed.
struct PlanView: View {
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss
    @State private var model: PlanViewModel
    @State private var isBudgetShown = false
    @State private var isPackingShown = false

    init(model: PlanViewModel) {
        _model = State(wrappedValue: model)
    }

    /// Built here rather than in the view model: the closures are view concerns and
    /// the model stays free of SwiftUI.
    /// What the one sheet is currently showing.
    ///
    /// Order is priority, and it is deliberate: a hand-off the traveller just tapped
    /// outranks a paywall, and a paywall outranks the finished file — raising the
    /// "here is your PDF" sheet over an unanswered paywall would claim they bought
    /// something.
    private enum PlanSheet: Identifiable {
        case booking(BookableOffer)
        case paywall(ExportOutlook)
        case exportReady(PlanDocument)
        case budget
        case packing

        var id: String {
            switch self {
            case let .booking(offer):  "booking-\(offer.id.rawValue)"
            case .paywall:             "paywall"
            case .exportReady:         "export"
            case .budget:              "budget"
            case .packing:             "packing"
            }
        }
    }

    private var activeSheet: PlanSheet? {
        if let offer = model.presentedOffer { return .booking(offer) }
        if let outlook = model.paywall { return .paywall(outlook) }
        if let document = preparedDocument { return .exportReady(document) }
        if isBudgetShown { return .budget }
        if isPackingShown { return .packing }
        return nil
    }

    /// Clears whichever source put the sheet up. Dismissing is one gesture, so it
    /// has to reach whichever piece of state is responsible.
    private func dismissSheets() {
        if model.presentedOffer != nil { model.presentedOffer = nil; return }
        if model.paywall != nil { model.paywall = nil; return }
        if preparedDocument != nil { model.dismissExport(); return }
        isBudgetShown = false
        isPackingShown = false
    }

    /// The document the last export produced, if it is ready.
    private var preparedDocument: PlanDocument? {
        if case let .ready(document) = model.exportState { return document }
        return nil
    }

    private var editingContext: PlanEditingContext {
        PlanEditingContext(isEnabled: model.isEditable,
                           moveTargets: { model.moveTargets(for: $0, on: $1) },
                           apply: { model.apply($0) })
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Theme.Plan.S.day) {
                header

                ForEach(Array(model.days.enumerated()), id: \.element.id) { index, day in
                    // The route map sits above the first day only. Once per plan, not
                    // once per day: repeating it would turn the list into a stack of
                    // maps with itineraries wedged between them.
                    if index == 0, !day.routeCoordinates.isEmpty {
                        RouteMapStrip(day: day)
                    }
                    DayView(day: day,
                            warnings: model.warnings(for: day),
                            offers: { model.offers(for: $0) },
                            transferOffers: model.offers(forDay: day),
                            onOffer: { model.open($0) },
                            editing: editingContext)

                    // Proposals sit under the day they are about, not in a banner at
                    // the top: a suggestion about Tuesday shown above Monday is a
                    // suggestion the traveller has to go looking for.
                    ForEach(model.proposals.filter { $0.dayID == day.id }) { proposal in
                        ReflowProposalRow(proposal: proposal,
                                          onAccept: { model.accept(proposal) },
                                          onDismiss: { model.dismiss(proposal) })
                    }
                }

                if case let .failed(message) = model.exportState {
                    WarningLine(text: message)
                        .onTapGesture { model.dismissExport() }
                }

                if let refusal = model.lastRefusal {
                    WarningLine(text: refusal.message)
                        .onTapGesture { model.clearRefusal() }
                }

                if model.showsSkeleton {
                    DaySkeletonView(dayNumber: model.days.count + 1)
                }

                if case let .failed(error) = model.phase {
                    failure(error)
                }

                if model.phase == .ready {
                    // One tap away from the plan, not permanently beside it.
                    extras
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
        // One sheet, not five. SwiftUI honours a single `.sheet` per view, so the
        // stack this screen had grown meant the budget, the packing list and the
        // booking hand-off silently never presented. An explicit destination also
        // makes the priority a decision rather than an accident of ordering.
        .sheet(item: Binding(get: { activeSheet }, set: { if $0 == nil { dismissSheets() } })) { sheet in
            switch sheet {
            case let .booking(offer):
                SafariView(url: offer.url)
                    .ignoresSafeArea()
            case let .paywall(outlook):
                PaywallSheet(outlook: outlook,
                             preview: preparedDocument,
                             prices: model.prices,
                             isPurchasing: model.isPurchasing,
                             notice: model.purchaseNotice,
                             onPurchase: { product in
                                 Task { await model.purchase(product, locale: locale) }
                             },
                             onRestore: {
                                 Task { await model.restorePurchases(locale: locale) }
                             })
            case let .exportReady(document):
                ExportReadySheet(document: document)
            case .budget:
                BudgetSheet(estimate: model.budget,
                            currency: model.budgetCurrency,
                            onCurrency: { currency in
                                Task { await model.setBudgetCurrency(currency) }
                            })
            case .packing:
                PackingSheet(sections: model.packing)
            }
        }
        .animation(Theme.Plan.Motion.standard, value: model.revision)
        .task { model.startIfNeeded() }
        .onDisappear { model.cancel() }
    }

    /// The screen's one primary action (PRD 5.1, rule 3).
    ///
    /// The PDF export, as F-08 intends. It appears only once generation finishes —
    /// offering to export half a plan invites the traveller to spend a credit on a
    /// trip that is still being written, and the revision would change under them.
    ///
    /// Plain-text sharing did not go away; it moved beside the budget and the
    /// packing list. It is still free, still needs no account, and is still what
    /// somebody pasting a plan into a message actually wants.
    @ViewBuilder
    private var shareAction: some View {
        if model.phase == .ready {
            Button {
                Task { await model.export(locale: locale) }
            } label: {
                Text(model.exportState == .preparing ? "export.preparing" : "export.action")
                    .viharaText(Theme.Plan.F.action)
                    .foregroundStyle(Theme.C.bg)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: Theme.S.tapTarget + Theme.Plan.S.s1)
                    .background(Theme.C.text,
                                in: RoundedRectangle(cornerRadius: Theme.Plan.R.surface,
                                                     style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!model.canExport || model.exportState == .preparing)
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
            Text(model.subtitle(locale: locale))
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
                Text("plan.retry")
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
    /// The two derived views of the plan. Text links, because the plan surface
    /// allows one filled control and it is the export action.
    private var extras: some View {
        HStack(spacing: Theme.Plan.S.s4) {
            Button { isBudgetShown = true } label: {
                Text("budget.open")
                    .viharaText(Theme.Plan.F.meta)
                    .foregroundStyle(Theme.C.accentDeep)
                    .viharaInlineHitTarget()
            }
            .buttonStyle(.plain)

            Button { isPackingShown = true } label: {
                Text("packing.open")
                    .viharaText(Theme.Plan.F.meta)
                    .foregroundStyle(Theme.C.accentDeep)
                    .viharaInlineHitTarget()
            }
            .buttonStyle(.plain)

            ShareLink(item: model.shareText(locale: locale)) {
                Text("export.share.text")
                    .viharaText(Theme.Plan.F.meta)
                    .foregroundStyle(Theme.C.accentDeep)
                    .viharaInlineHitTarget()
            }

            Spacer(minLength: 0)
        }
    }

    private var footnote: some View {
        Text("plan.footnote")
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
