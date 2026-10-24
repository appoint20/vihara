import Foundation

/// F-02 — the plan as it arrives.
///
/// Days are appended as the stream validates them, so the screen has content long
/// before generation finishes. The traveller never waits on a full-screen spinner;
/// they watch a plan being written.
@MainActor
@Observable
final class PlanViewModel {
    enum Phase: Equatable {
        case generating
        case ready
        case failed(DomainError)
    }

    /// Where the days come from.
    ///
    /// The screen is the same either way — a plan being written and a plan being
    /// re-read are the same three blocks a day — so this is a difference in how the
    /// model fills, not in what the view draws.
    private enum Source {
        case generating(GenerateTrip)
        /// Already composed and on disk. Nothing to stream, nothing to retry.
        case stored
    }

    let brief: TripBrief
    private let source: Source
    private let rules: ItineraryRules

    /// Both optional, and the plan is complete without either.
    ///
    /// Not a convenience: a plan whose value depended on an offer would be "a
    /// collection of links" under App Store guideline 4.2.2, and offers come from a
    /// network an offline traveller does not have. `nil` is the supported state, and
    /// `planIsCompleteWithoutOffers` pins it.
    private let offerProvider: (any OfferProviding)?
    private let clickReporter: (any OfferClickReporting)?

    private(set) var days: [TripDay] = []
    private(set) var expectedDays = 0
    private(set) var phase: Phase = .generating
    private(set) var tripID: Identifier<Trip>?

    /// F-05/F-06 state. `revision` is not cosmetic: exports are idempotent per
    /// `(id, revision)`, so it has to survive every edit or a retried export hands
    /// back the plan as it was.
    private(set) var revision = 0
    private let createdAt: Date
    private let editor: PlanEditor
    private let trips: (any TripRepository)?
    private let rates: (any ExchangeRates)?
    /// F-08/F-09. All optional: a plan screen with no store and no exporter still
    /// renders a plan and still shares it as text.
    private let exporter: (any PlanExporting)?
    private let purchases: (any Purchasing)?
    private let wallets: (any WalletRepository)?
    /// Fixes offered after the last edit. Never applied on the traveller's behalf —
    /// silent reshuffling is the behaviour the product exists to avoid.
    private(set) var proposals: [ReflowProposal] = []
    /// Why the last edit did not happen, for the one frame it takes to say so.
    private(set) var lastRefusal: PlanEditRefusal?

    /// Resolved at render time and never written into the ``Trip``. An offer carries
    /// a price and a link, and both go stale — see ``BookableOffer``.
    private(set) var offersByItem: [Identifier<ItineraryItem>: [BookableOffer]] = [:]
    private(set) var offersByDay: [Identifier<TripDay>: [BookableOffer]] = [:]
    /// The offer whose partner page is open, if any.
    var presentedOffer: BookableOffer?

    private var generation: Task<Void, Never>?

    init(brief: TripBrief,
         generateTrip: GenerateTrip,
         offerProvider: (any OfferProviding)? = nil,
         clickReporter: (any OfferClickReporting)? = nil,
         trips: (any TripRepository)? = nil,
         rates: (any ExchangeRates)? = nil,
         exporter: (any PlanExporting)? = nil,
         purchases: (any Purchasing)? = nil,
         wallets: (any WalletRepository)? = nil) {
        self.brief = brief
        self.source = .generating(generateTrip)
        self.rules = ItineraryRules(brief: brief)
        self.editor = PlanEditor(brief: brief)
        self.expectedDays = brief.dayCount
        self.offerProvider = offerProvider
        self.clickReporter = clickReporter
        self.trips = trips
        self.rates = rates
        self.exporter = exporter
        self.purchases = purchases
        self.wallets = wallets
        self.createdAt = .now
    }

    /// Opens a plan the traveller already has.
    ///
    /// Reads as finished from the first frame: no skeleton, no stream, no second
    /// generation. Re-generating a saved plan would spend an allowance and could
    /// quietly return something different from what they saved.
    init(trip: Trip,
         offerProvider: (any OfferProviding)? = nil,
         clickReporter: (any OfferClickReporting)? = nil,
         trips: (any TripRepository)? = nil,
         rates: (any ExchangeRates)? = nil,
         exporter: (any PlanExporting)? = nil,
         purchases: (any Purchasing)? = nil,
         wallets: (any WalletRepository)? = nil) {
        self.brief = trip.brief
        self.source = .stored
        self.rules = ItineraryRules(brief: trip.brief)
        self.editor = PlanEditor(brief: trip.brief)
        self.days = trip.days
        self.expectedDays = trip.days.count
        self.phase = .ready
        self.tripID = trip.id
        self.revision = trip.revision
        self.createdAt = trip.createdAt
        self.offerProvider = offerProvider
        self.clickReporter = clickReporter
        self.trips = trips
        self.rates = rates
        self.exporter = exporter
        self.purchases = purchases
        self.wallets = wallets
    }

    /// Idempotent: re-entering the screen after a background does not restart a
    /// generation that is already running or already finished.
    func startIfNeeded() {
        guard case let .generating(generateTrip) = source, generation == nil else {
            // A stored plan has its days from the first frame, so its offers are
            // fetched here rather than as the stream arrives.
            if case .stored = source { loadOffers(for: days) }
            return
        }
        generation = Task { await run(generateTrip) }
    }

    func retry() {
        guard case .generating = source else { return }
        generation?.cancel()
        generation = nil
        days = []
        phase = .generating
        startIfNeeded()
    }

    func cancel() {
        generation?.cancel()
        generation = nil
    }

    private func run(_ generateTrip: GenerateTrip) async {
        do {
            for try await event in generateTrip(brief: brief) {
                switch event {
                case let .accepted(tripID, expectedDays):
                    self.tripID = tripID
                    self.expectedDays = expectedDays
                case let .dayReady(day):
                    days.append(day)
                    // Fired and not awaited: a slow offer service must not hold up
                    // the next day of the plan.
                    loadOffers(for: [day])
                case .completed:
                    phase = .ready
                }
            }
            // A stream that ends without `completed` — a dropped connection — leaves
            // whatever arrived on screen and offers a retry, rather than discarding a
            // partial plan the traveller can already read.
            if phase == .generating {
                phase = days.isEmpty ? .failed(.connectionFailed) : .ready
            }
        } catch let error as DomainError {
            phase = .failed(error)
        } catch {
            phase = .failed(.unexpectedResponse)
        }
    }

    // MARK: - Export and paywall (F-08, F-09)

    enum ExportState: Equatable {
        case idle
        case preparing
        /// Ready to hand to the share sheet. The PDF itself is rendered lazily by
        /// ``ExportedPlan``, not here.
        case ready(PlanDocument)
        case failed(String)
    }

    private(set) var exportState: ExportState = .idle
    /// Which paywall to raise, set when the server granted only a preview. `nil`
    /// means nothing to sell — either the export was full, or there is no store.
    var paywall: ExportOutlook?
    private(set) var prices: [PurchasableProduct: String] = [:]
    private(set) var isPurchasing = false
    /// Said once, after a purchase that did not immediately entitle anything.
    private(set) var purchaseNotice: String?

    var canExport: Bool { exporter != nil && !days.isEmpty && phase == .ready }

    /// Asks the server for a grant and builds the document it permits.
    ///
    /// The client does not decide how much goes in the file — ``ExportGrant`` does,
    /// and it comes from the server ([ADR-004](../../../docs/adr/004-server-authoritative-entitlements.md)).
    /// A free account is not refused here: it gets a watermarked preview *and* the
    /// paywall, rather than a locked door.
    func export(locale: Locale) async {
        guard let exporter, let trip = currentTrip else { return }
        guard !days.isEmpty else {
            exportState = .failed(localized("export.failed.empty", locale: locale))
            return
        }

        exportState = .preparing
        do {
            let grant = try await exporter.requestGrant(tripID: trip.id, revision: trip.revision)
            let document = PlanDocument.make(brief: brief, days: days, grant: grant, locale: locale)
            exportState = .ready(document)

            if grant.isWatermarked {
                paywall = await currentOutlook(for: trip.id)
                await loadPrices()
            } else {
                paywall = nil
            }
        } catch let failure as ExportFailure {
            exportState = .failed(failure.message(locale: locale))
            if case let .notEntitled(outlook) = failure {
                paywall = outlook
                await loadPrices()
            }
        } catch {
            exportState = .failed(localized("export.failed.generic", locale: locale))
        }
    }

    func dismissExport() {
        exportState = .idle
    }

    private func currentOutlook(for tripID: Identifier<Trip>) async -> ExportOutlook? {
        guard let wallets, let wallet = try? await wallets.currentWallet() else { return nil }
        return wallet.exportOutlook(for: tripID)
    }

    func loadPrices() async {
        guard let purchases else { return }
        prices = await purchases.prices()
    }

    /// Buys, then **re-asks the server**.
    ///
    /// It deliberately does not mark anything as entitled locally. StoreKit saying
    /// "verified" means Apple signed the transaction, not that this account may
    /// export — only the ledger decides that, so the answer comes from asking it
    /// again.
    func purchase(_ product: PurchasableProduct, locale: Locale) async {
        guard let purchases, !isPurchasing else { return }
        isPurchasing = true
        purchaseNotice = nil
        defer { isPurchasing = false }

        do {
            switch try await purchases.purchase(product, tripID: tripID) {
            case .purchased:
                paywall = nil
                await export(locale: locale)
            case .cancelled:
                break
            case .pending:
                // Ask-to-buy. Entitlement may arrive later or never, so nothing is
                // promised and the preview stays on screen.
                purchaseNotice = localized("paywall.pending", locale: locale)
            }
        } catch {
            purchaseNotice = localized("paywall.failed", locale: locale)
        }
    }

    /// Required by App Store review for any non-consumable, and the only way a
    /// reinstall gets its unlocks back.
    func restorePurchases(locale: Locale) async {
        guard let purchases, !isPurchasing else { return }
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            try await purchases.restore()
            await export(locale: locale)
        } catch {
            purchaseNotice = localized("paywall.failed", locale: locale)
        }
    }

    // MARK: - Budget and packing (F-11, F-12)

    /// Composed from the plan on demand rather than stored: the plan is the single
    /// source, so an edit cannot leave a budget behind that disagrees with it.
    var budget: BudgetEstimate {
        convertedBudget ?? TripBudget(brief: brief).estimate(for: days)
    }

    var packing: [PackingSection] {
        PackingList(brief: brief).sections(for: days)
    }

    private(set) var budgetCurrency: Money.Currency = .eur
    private var convertedBudget: BudgetEstimate?

    /// Shows the budget in another currency — the thing Wanderlog cannot do at all.
    ///
    /// An unknown rate leaves the budget in euros rather than converting part of it:
    /// a breakdown with some rows converted and some not adds up to nothing.
    func setBudgetCurrency(_ currency: Money.Currency) async {
        budgetCurrency = currency
        guard currency != .eur else {
            convertedBudget = nil
            return
        }
        guard let rates, let rate = await rates.rate(from: .eur, to: currency) else {
            budgetCurrency = .eur
            convertedBudget = nil
            return
        }
        convertedBudget = TripBudget(brief: brief).estimate(for: days).converted(to: currency,
                                                                                rate: rate)
    }

    // MARK: - Editing

    /// The plan as a value, for the editor to work on.
    ///
    /// `nil` until the stream reports a trip id: an edit to a plan the server has not
    /// accepted yet has nowhere to be saved, and would be lost on the next frame.
    var currentTrip: Trip? {
        guard let tripID else { return nil }
        return Trip(id: tripID, brief: brief, days: days, revision: revision, createdAt: createdAt)
    }

    /// Whether the plan can be edited at all. False while it is still arriving —
    /// moving a stop between blocks that are still being written is an edit against a
    /// plan that no longer exists by the time it lands.
    var isEditable: Bool {
        phase == .ready && currentTrip != nil
    }

    /// Applies an edit, names what it broke, and saves.
    ///
    /// Both the drag gesture and the "Verschieben nach…" menu call this and nothing
    /// else, which is what keeps the accessible path from drifting away from the
    /// gesture as the feature grows.
    func apply(_ edit: PlanEdit) {
        guard let trip = currentTrip else { return }

        let result = editor.apply(edit, to: trip)
        guard result.didChange else {
            lastRefusal = result.refusal
            return
        }

        lastRefusal = nil
        days = result.trip.days
        // The converted budget and any prepared export were built from the days as
        // they were. The revision moved, so the export would be billed again anyway.
        convertedBudget = nil
        exportState = .idle
        revision = result.trip.revision
        proposals = result.proposals

        // Offers belong to places, and an edit can remove one. Dropping its offers
        // keeps a ticket link from outliving the stop it was for.
        let liveItemIDs = Set(result.trip.days.flatMap { $0.blocks.flatMap(\.items) }.map(\.id))
        offersByItem = offersByItem.filter { liveItemIDs.contains($0.key) }

        persist(result.trip)
    }

    /// Accepting a proposal runs the ordinary edit path, so an accepted fix is
    /// indistinguishable from a hand-made one.
    func accept(_ proposal: ReflowProposal) {
        apply(proposal.edit)
    }

    func dismiss(_ proposal: ReflowProposal) {
        proposals.removeAll { $0.id == proposal.id }
    }

    /// Which half-days this item could move to, for the accessible menu.
    ///
    /// Computed from the same ``ItineraryRules/canAccept(_:into:)`` that decides
    /// whether a drop target lights up, so the menu never offers a move that the
    /// drag would refuse.
    func moveTargets(for item: ItineraryItem, on day: TripDay) -> [DaySlot] {
        DaySlot.allCases.filter { slot in
            guard let block = day[slot] else { return false }
            if block.items.contains(where: { $0.id == item.id }) { return false }
            return rules.canAccept(item, into: block)
        }
    }

    func clearRefusal() {
        lastRefusal = nil
    }

    private func persist(_ trip: Trip) {
        guard let trips else { return }
        Task { try? await trips.save(trip) }
    }

    // MARK: - Offers

    /// Fetches offers for the places in these days, concurrently, and drops every
    /// failure on the floor.
    ///
    /// Silence is the correct failure mode. An offer that does not arrive leaves a
    /// plan that reads exactly as it should; an error message about a missing
    /// advertisement would be the app complaining that it could not show the
    /// traveller an ad.
    private func loadOffers(for days: [TripDay]) {
        guard let offerProvider else { return }

        Task { [weak self] in
            for day in days {
                // Only ask where an offer is plausible. This is a relevance filter,
                // not a partner choice — which partner answers, and whether any does,
                // stays the service's decision (ADR-006).
                // The slot is carried rather than flattened away: it is half of what
                // makes a sub-id identify a *surface*, which is the only reason the
                // ranking in docs/MONETISATION.md §2 can ever stop being a guess.
                let candidates = day.blocks.flatMap { block in
                    block.items
                        .filter { $0.place.requiresTicket || $0.kind == .sight || $0.kind == .activity }
                        .map { (item: $0, slot: block.slot) }
                }

                await withTaskGroup(of: (Identifier<ItineraryItem>, [BookableOffer]).self) { group in
                    for (item, slot) in candidates {
                        group.addTask { [tripID] in
                            let request = OfferRequest.place(
                                providerPlaceID: item.place.providerPlaceID,
                                name: item.place.name,
                                city: day.city,
                                requiresTicket: item.place.requiresTicket,
                                on: day.date
                            )
                            let context = OfferContext(tripID: tripID, slot: slot)
                            let offers = (try? await offerProvider.offers(for: request,
                                                                          context: context)) ?? []
                            return (item.id, offers)
                        }
                    }
                    for await (itemID, offers) in group where !offers.isEmpty {
                        await self?.store(offers, forItem: itemID)
                    }
                }

                if let transfer = day.arrivalTransfer {
                    let request = OfferRequest.transfer(origin: transfer.origin,
                                                        destination: transfer.destination)
                    let context = OfferContext(tripID: tripID, slot: nil)
                    let offers = (try? await offerProvider.offers(for: request,
                                                                  context: context)) ?? []
                    if !offers.isEmpty {
                        await self?.store(offers, forDay: day.id)
                    }
                }
            }
        }
    }

    private func store(_ offers: [BookableOffer], forItem id: Identifier<ItineraryItem>) {
        offersByItem[id] = offers
    }

    private func store(_ offers: [BookableOffer], forDay id: Identifier<TripDay>) {
        offersByDay[id] = offers
    }

    func offers(for item: ItineraryItem) -> [BookableOffer] {
        offersByItem[item.id] ?? []
    }

    func offers(forDay day: TripDay) -> [BookableOffer] {
        offersByDay[day.id] ?? []
    }

    /// Hands the traveller to the partner, and tells the service it happened.
    ///
    /// The click report is **not awaited**. Attribution bookkeeping is ours; the wait
    /// for the partner's page is theirs, and a traveller who taps a ticket link should
    /// see Safari open, not a spinner over our analytics.
    func open(_ offer: BookableOffer) {
        // `SFSafariViewController` traps on a scheme it cannot load, and the URL
        // arrived opaque from a service. Checking it here keeps a service bug from
        // becoming a crash in front of the traveller — and reports no click for a
        // hand-off that never happened.
        guard let scheme = offer.url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else { return }

        presentedOffer = offer
        guard let clickReporter else { return }
        Task { await clickReporter.reportClick(on: offer) }
    }

    // MARK: - Presentation

    /// Conflicts in a day, computed locally. No round trip is needed to tell the
    /// traveller that a museum shuts before their visit ends (F-06).
    func warnings(for day: TripDay) -> [PlanWarning] {
        rules.warnings(for: day)
    }

    /// Exactly one skeleton, for the day being composed right now — never a queue of
    /// grey rectangles standing in for the whole trip (PRD 5.1, rule 7).
    var showsSkeleton: Bool {
        phase == .generating && days.count < expectedDays
    }

    var title: String {
        brief.destination.isEmpty ? "Dein Plan" : brief.destination
    }

    /// "4 Nächte · Entspannt · Vegetarisch"
    ///
    /// Takes the locale rather than reading one, because a view model has no
    /// environment and the traveller's language is a choice in Settings, not the
    /// device's.
    func subtitle(locale: Locale) -> String {
        var parts = [brief.nightsLabel(locale: locale), brief.pace.label(locale: locale)]
        if brief.diet.requiresSignal { parts.append(brief.diet.label(locale: locale)) }
        return parts.joined(separator: " · ")
    }

    /// What the share sheet hands on. Built from the days actually on screen, so a
    /// plan shared is always the plan the traveller is looking at.
    func shareText(locale: Locale) -> String {
        PlanTextExport.text(brief: brief, days: days, locale: locale)
    }
}
