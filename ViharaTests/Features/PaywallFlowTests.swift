import Testing
import Foundation
@testable import Vihara

@Suite("Exporting from the plan screen")
@MainActor
struct PlanExportFlowTests {

    private let tripID = Identifier<Trip>("trip-1")
    private let locale = Locale(identifier: "de")

    private func day() -> TripDay {
        TripDay(date: Fixture.date(2026, 4, 14), city: "Bologna", blocks: [
            DayBlock(slot: .morning, items: [Fixture.item("Torre", at: (9, 0))]),
            DayBlock(slot: .afternoon),
            DayBlock(slot: .evening, items: [Fixture.item("Osteria", kind: .meal)]),
        ])
    }

    private func model(server: InMemoryEntitlementServer,
                       purchases: (any Purchasing)? = nil,
                       days: Int = 2) -> PlanViewModel {
        let brief = Fixture.brief(destination: "Bologna", nights: days)
        let events: [TripGenerationEvent] =
            [.accepted(tripID: tripID, expectedDays: days)]
            + (0..<days).map { _ in TripGenerationEvent.dayReady(day()) }
            + [.completed]

        return PlanViewModel(
            brief: brief,
            generateTrip: GenerateTrip(generator: ScriptedTripGenerator(events: events),
                                       trips: InMemoryTripRepository(),
                                       wallets: server),
            exporter: server,
            purchases: purchases,
            wallets: server
        )
    }

    private func ready(_ model: PlanViewModel) async throws {
        model.startIfNeeded()
        try await eventually("the plan finishes") { model.phase == .ready }
    }

    /// PRD 4: a free account gets a watermarked preview *and* the paywall, not a
    /// locked door.
    @Test("A free account gets a preview and the paywall together")
    func freeAccountGetsBoth() async throws {
        let server = InMemoryEntitlementServer(wallet: .empty)
        let model = model(server: server, purchases: FakePurchases(server: server))
        try await ready(model)

        await model.export(locale: locale)

        let document = try #require(model.exportState.document)
        #expect(document.watermark != nil)
        #expect(document.days.count == 1)
        #expect(document.withheldDayTitles.count == 1)
        #expect(model.paywall == .needsPurchase)
    }

    @Test("Buying the unlock re-asks the server and the watermark goes")
    func purchaseUpgradesTheExport() async throws {
        let server = InMemoryEntitlementServer(wallet: .empty)
        let purchases = FakePurchases(server: server)
        let model = model(server: server, purchases: purchases)
        try await ready(model)

        await model.export(locale: locale)
        #expect(model.exportState.document?.watermark != nil)

        await model.purchase(.singleTripUnlock, locale: locale)

        let document = try #require(model.exportState.document)
        #expect(document.watermark == nil)
        #expect(document.days.count == 2)
        #expect(model.paywall == nil)
    }

    /// The client must not mark itself entitled. The only reason the watermark went
    /// is that the ledger was asked again and said so.
    @Test("A purchase that the ledger does not honour leaves the preview in place")
    func purchaseThatGrantsNothingChangesNothing() async throws {
        let server = InMemoryEntitlementServer(wallet: .empty)
        // Reports success to the UI but never moves the ledger — a receipt the
        // server rejected.
        let purchases = FakePurchases(server: nil)
        let model = model(server: server, purchases: purchases)
        try await ready(model)

        await model.export(locale: locale)
        await model.purchase(.singleTripUnlock, locale: locale)

        #expect(model.exportState.document?.watermark != nil)
        #expect(model.paywall == .needsPurchase)
    }

    @Test("A subscriber with credits exports in full and sees no paywall")
    func subscriberExportsInFull() async throws {
        let wallet = Wallet(freeTripsUsedThisYear: 0, freeTripsAllowance: 2,
                            subscription: .active, periodCreditsGranted: 3,
                            periodCreditsUsed: 0, purchasedCredits: 0,
                            unlockedTripIDs: [], periodRenewsOn: nil)
        let server = InMemoryEntitlementServer(wallet: wallet)
        let model = model(server: server)
        try await ready(model)

        await model.export(locale: locale)

        #expect(model.exportState.document?.watermark == nil)
        #expect(model.paywall == nil)
        #expect(try await server.currentWallet().periodCreditsRemaining == 2)
    }

    /// Ask-to-buy. Entitlement may arrive later or never, so nothing is promised.
    @Test("A pending purchase promises nothing and keeps the preview")
    func pendingPurchase() async throws {
        let server = InMemoryEntitlementServer(wallet: .empty)
        let model = model(server: server, purchases: FakePurchases(server: nil, outcome: .pending))
        try await ready(model)

        await model.export(locale: locale)
        await model.purchase(.singleTripUnlock, locale: locale)

        #expect(model.purchaseNotice != nil)
        #expect(model.exportState.document?.watermark != nil)
        #expect(model.paywall == .needsPurchase)
    }

    @Test("Cancelling says nothing and changes nothing")
    func cancelling() async throws {
        let server = InMemoryEntitlementServer(wallet: .empty)
        let model = model(server: server, purchases: FakePurchases(server: nil, outcome: .cancelled))
        try await ready(model)

        await model.export(locale: locale)
        await model.purchase(.singleTripUnlock, locale: locale)

        #expect(model.purchaseNotice == nil)
        #expect(model.paywall == .needsPurchase)
    }

    /// An edit bumps the revision, so the prepared file is for a plan that no longer
    /// exists — and would be charged again anyway.
    @Test("Editing the plan discards a prepared export")
    func editDiscardsAPreparedExport() async throws {
        let wallet = Wallet(freeTripsUsedThisYear: 0, freeTripsAllowance: 2,
                            subscription: .active, periodCreditsGranted: 5,
                            periodCreditsUsed: 0, purchasedCredits: 0,
                            unlockedTripIDs: [], periodRenewsOn: nil)
        let server = InMemoryEntitlementServer(wallet: wallet)
        let model = model(server: server)
        try await ready(model)

        await model.export(locale: locale)
        #expect(model.exportState.document != nil)

        let item = try #require(model.days.first?.blocks.first?.items.first)
        model.apply(.setPinned(item: item.id, true))

        #expect(model.exportState == .idle)
    }

    @Test("With no exporter wired, the screen simply cannot export")
    func noExporter() async throws {
        let server = InMemoryEntitlementServer(wallet: .empty)
        let brief = Fixture.brief(destination: "Bologna", nights: 1)
        let model = PlanViewModel(
            brief: brief,
            generateTrip: GenerateTrip(generator: ScriptedTripGenerator(events: [
                .accepted(tripID: tripID, expectedDays: 1), .dayReady(day()), .completed,
            ]), trips: InMemoryTripRepository(), wallets: server)
        )
        try await ready(model)

        #expect(!model.canExport)
        await model.export(locale: locale)
        #expect(model.exportState == .idle)
    }

    @Test("Prices come from the store, and a product without one is not offered")
    func pricesLoad() async throws {
        let server = InMemoryEntitlementServer(wallet: .empty)
        let purchases = FakePurchases(server: server,
                                      prices: [.singleTripUnlock: "4,99 €"])
        let model = model(server: server, purchases: purchases)
        try await ready(model)

        await model.export(locale: locale)

        #expect(model.prices == [.singleTripUnlock: "4,99 €"])
    }
}

private extension PlanViewModel.ExportState {
    var document: PlanDocument? {
        if case let .ready(document) = self { return document }
        return nil
    }
}

/// Reports whatever outcome it is told to. When given a server it also moves the
/// ledger, standing in for "the receipt reached the backend".
private struct FakePurchases: Purchasing {
    let server: InMemoryEntitlementServer?
    var outcome: PurchaseOutcome = .purchased
    var prices: [PurchasableProduct: String] = [
        .singleTripUnlock: "4,99 €",
        .subscription: "7,99 €",
        .creditBundle: "4,99 €",
    ]

    init(server: InMemoryEntitlementServer?,
         outcome: PurchaseOutcome = .purchased,
         prices: [PurchasableProduct: String]? = nil) {
        self.server = server
        self.outcome = outcome
        if let prices { self.prices = prices }
    }

    func prices() async -> [PurchasableProduct: String] { prices }

    func purchase(_ product: PurchasableProduct,
                  tripID: Identifier<Trip>?) async throws -> PurchaseOutcome {
        if outcome == .purchased {
            await server?.apply(product, tripID: tripID)
        }
        return outcome
    }

    func restore() async throws {}
}
