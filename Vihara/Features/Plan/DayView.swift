import SwiftUI

/// One day: a title and three named blocks. No card, no rule, no map underneath —
/// separation is whitespace and type size alone (PRD 5.2).
struct DayView: View {
    let day: TripDay
    let warnings: [PlanWarning]
    /// Offers for one stop. Defaulted to none, because a day must read correctly
    /// without any — see ``PlanViewModel``.
    var offers: (ItineraryItem) -> [BookableOffer] = { _ in [] }
    /// Offers for getting here, shown with the arrival transfer.
    var transferOffers: [BookableOffer] = []
    var onOffer: (BookableOffer) -> Void = { _ in }
    var editing: PlanEditingContext = .disabled

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Plan.S.block) {
            Text(day.title)
                .viharaText(Theme.Plan.F.dayTitle)
                .foregroundStyle(Theme.C.text)
                .fixedSize(horizontal: false, vertical: true)

            if let transfer = day.arrivalTransfer {
                TransferView(transfer: transfer, offers: transferOffers, onOffer: onOffer)
            }

            ForEach(day.blocks) { block in
                BlockView(block: block,
                          warnings: warnings.filter { $0.slot == block.slot },
                          offers: offers,
                          onOffer: onOffer,
                          editing: editing,
                          day: day)
            }
        }
    }
}

/// A half-day. The label is the only chrome it gets.
struct BlockView: View {
    let block: DayBlock
    let warnings: [PlanWarning]
    var offers: (ItineraryItem) -> [BookableOffer] = { _ in [] }
    var onOffer: (BookableOffer) -> Void = { _ in }
    var editing: PlanEditingContext = .disabled
    /// The day this block belongs to — a move names a day as well as a slot.
    var day: TripDay?

    @State private var isTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Plan.S.s2) {
            Text(block.slot.label)
                .viharaText(Theme.Plan.F.blockLabel)
                // A block being dragged over says so by weight, not by a border:
                // the plan surface has no boxes to light up (PRD 5.2).
                .foregroundStyle(isTargeted ? Theme.C.accentDeep : Theme.C.textFaint)

            if block.isEmpty {
                Text("plan.block.free")
                    .viharaText(Theme.Plan.F.item)
                    .foregroundStyle(Theme.C.textFaint)
            } else {
                VStack(alignment: .leading, spacing: Theme.Plan.S.s2) {
                    ForEach(block.items) { item in
                        ItemRow(item: item,
                                warnings: warnings.filter { $0.itemID == item.id },
                                offers: offers(item),
                                onOffer: onOffer,
                                editing: editing,
                                day: day)
                    }
                }
            }

            // Warnings about the block rather than one item sit under the whole
            // block, set off by a gap so they do not read as belonging to the last
            // item in it.
            let blockWarnings = warnings.filter { $0.itemID == nil }
            if !blockWarnings.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Plan.S.s1) {
                    ForEach(blockWarnings) { warning in
                        WarningLine(text: warning.message)
                    }
                }
                .padding(.top, Theme.Plan.S.s1)
            }
        }
        // The whole block is the target, label and free-text included: a half-day
        // with nothing in it is exactly where a traveller wants to drop something,
        // and a target the size of one text row would be unhittable.
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .dropDestination(for: String.self) { ids, _ in
            guard editing.isEnabled, let day, let raw = ids.first else { return false }
            editing.apply(.move(item: Identifier(raw), toSlot: block.slot, onDay: day.id))
            return true
        } isTargeted: { targeted in
            isTargeted = editing.isEnabled && targeted
        }
    }
}

/// A *Baustein*.
struct ItemRow: View {
    let item: ItineraryItem
    let warnings: [PlanWarning]
    var offers: [BookableOffer] = []
    var onOffer: (BookableOffer) -> Void = { _ in }
    var editing: PlanEditingContext = .disabled
    var day: TripDay?

    @Environment(\.locale) private var locale
    @Environment(\.openURL) private var openURL
    @AppStorage(NavigationApp.storageKey) private var navigationApp = NavigationApp.apple
    @State private var isReasonShown = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Plan.S.s1) {
            // Travel time is an aside between blocks, not a row of its own.
            if let leg = item.travelFromPrevious {
                Text(leg.label)
                    .viharaText(Theme.Plan.F.meta)
                    .foregroundStyle(Theme.C.textFaint)
                    .padding(.bottom, Theme.Plan.S.s1)
            }

            HStack(alignment: .firstTextBaseline, spacing: Theme.Plan.S.s3) {
                Text(item.place.name)
                    .viharaText(Theme.Plan.F.item)
                    .foregroundStyle(Theme.C.text)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                if let start = item.startsAt {
                    Text(start.label)
                        .viharaText(Theme.Plan.F.meta)
                        .foregroundStyle(Theme.C.textMuted)
                        .monospacedDigit()
                }
            }

            if !badges.isEmpty {
                Text(badges.joined(separator: " · "))
                    .viharaText(Theme.Plan.F.meta)
                    .foregroundStyle(Theme.C.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // "wahrscheinlich" must not look like "bestätigt": the weaker signal is
            // drawn in the warning colour so the difference survives a glance.
            if let badge = item.place.dietSignal.badge, !badge.isConfirmed {
                Text(badge.text)
                    .viharaText(Theme.Plan.F.meta)
                    .foregroundStyle(Theme.C.price)
            }

            // Costs and age limits are money and refusal, so they take the warning
            // colour — never the accent, which belongs to things the planner is
            // telling you it did.
            if !cautions.isEmpty {
                Text(cautions.joined(separator: " · "))
                    .viharaText(Theme.Plan.F.meta)
                    .foregroundStyle(Theme.C.price)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(warnings) { warning in
                WarningLine(text: warning.message)
            }

            links

            if !offers.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Plan.S.s1) {
                    ForEach(offers) { offer in
                        OfferLink(kindLabel: localized(offer.kind.labelKey, locale: locale),
                                  partnerName: offer.partner.displayName,
                                  priceLabel: offer.priceLabel,
                                  disclosureLabel: localized(AffiliateDisclosure.labelKey, locale: locale)) {
                            onOffer(offer)
                        }
                    }
                }
                .padding(.top, Theme.Plan.S.s1)
            }

            if isReasonShown, let reason = item.reason {
                VStack(alignment: .leading, spacing: Theme.Plan.S.s1) {
                    Text(localized(reason, locale: locale))
                        .viharaText(Theme.Plan.F.meta)
                        .foregroundStyle(Theme.C.accentDeep)
                        .fixedSize(horizontal: false, vertical: true)

                    // The evidence line is what earns "bestätigt". A claim with no
                    // check time says so rather than staying quiet about it.
                    Text(evidenceLine)
                        .viharaText(Theme.Plan.F.blockLabel)
                        .foregroundStyle(Theme.C.textFaint)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, Theme.Plan.S.s1)
                .transition(.opacity)
            }
        }
        .accessibilityElement(children: .contain)
        .modifier(EditableItem(item: item, day: day, editing: editing, locale: locale))
    }

    /// Two textual links, never buttons: the plan is allowed one filled control and
    /// it is not on this row.
    private var links: some View {
        HStack(spacing: Theme.Plan.S.s4) {
            Button {
                open()
            } label: {
                Text("plan.stop.route")
                    .viharaText(Theme.Plan.F.meta)
                    .foregroundStyle(Theme.C.accentDeep)
                    .viharaInlineHitTarget()
            }
            .buttonStyle(.plain)

            if item.reason != nil {
                Button {
                    withAnimation(Theme.Plan.Motion.standard) { isReasonShown.toggle() }
                } label: {
                    Text(isReasonShown ? "plan.stop.why.hide" : "plan.stop.why")
                        .viharaText(Theme.Plan.F.meta)
                        .foregroundStyle(Theme.C.accentDeep)
                        .viharaInlineHitTarget()
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)
        }
        .padding(.top, Theme.Plan.S.s1)
    }

    private func open() {
        let urls = RouteDestination.singleStop(item.place.coordinate).urls(for: navigationApp)
        if let app = urls.app {
            openURL(app) { accepted in
                if !accepted, let web = urls.web { openURL(web) }
            }
        } else if let web = urls.web {
            openURL(web)
        }
    }

    private var evidenceLine: String {
        guard case let .confirmed(_, source) = item.place.dietSignal,
              let checkedAt = item.place.checkedAt else {
            return localized("plan.stop.unchecked", locale: locale)
        }
        return localized("plan.stop.checked",
                         localized("source.\(source.rawValue)", locale: locale),
                         checkedAt.formatted(.relative(presentation: .named).locale(locale)),
                         locale: locale)
    }

    /// Everything that reads as neutral fact. Anything needing emphasis is drawn
    /// separately above.
    private var badges: [String] {
        var parts: [String] = []
        if let hours = item.place.openingHours, item.kind == .sight {
            parts.append(hours.label)
        }
        if let badge = item.place.dietSignal.badge, badge.isConfirmed {
            parts.append(badge.text)
        }
        // A pin is a hard constraint the traveller set. If reflow is going to work
        // around it, the plan has to show which stop it is working around.
        if item.isPinned {
            parts.append(localized("plan.stop.pinned", locale: locale))
        }
        return parts
    }

    /// Anything that costs money or turns somebody away.
    private var cautions: [String] {
        var parts: [String] = []
        if item.place.requiresTicket {
            parts.append(localized("plan.stop.ticket", locale: locale))
        }
        if let minimumAge = item.place.minimumAge {
            parts.append(localized("plan.stop.minimumAge", minimumAge, locale: locale))
        }
        if let admission = item.place.admission {
            parts.append(localized("plan.stop.admission",
                                   admission.adultPrice.label(locale: locale),
                                   locale: locale))
        }
        return parts
    }
}

/// A conflict, stated plainly. Magenta, and never next to anything cyan.
struct WarningLine: View {
    let text: String

    var body: some View {
        Text(text)
            .viharaText(Theme.Plan.F.meta)
            .foregroundStyle(Theme.C.price)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// The comparison between two stops (F-07). Bands, not fares — enough to choose.
struct TransferView: View {
    let transfer: Transfer
    var offers: [BookableOffer] = []
    var onOffer: (BookableOffer) -> Void = { _ in }
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Plan.S.s2) {
            Text(localized("plan.transfer.from", transfer.origin, locale: locale))
                .viharaText(Theme.Plan.F.blockLabel)
                .foregroundStyle(Theme.C.textFaint)

            ForEach(transfer.options) { option in
                HStack(alignment: .firstTextBaseline, spacing: Theme.Plan.S.s2) {
                    Text(option.mode.label)
                        .viharaText(Theme.Plan.F.meta)
                        .foregroundStyle(Theme.C.text)
                    Text(option.durationLabel)
                        .viharaText(Theme.Plan.F.meta)
                        .foregroundStyle(Theme.C.textMuted)
                    Spacer(minLength: 0)
                    Text(option.priceBand.label)
                        .viharaText(Theme.Plan.F.meta)
                        .foregroundStyle(Theme.C.price)
                        .monospacedDigit()
                }
                .accessibilityElement(children: .combine)
            }

            if !offers.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Plan.S.s1) {
                    ForEach(offers) { offer in
                        OfferLink(kindLabel: localized(offer.kind.labelKey, locale: locale),
                                  partnerName: offer.partner.displayName,
                                  priceLabel: offer.priceLabel,
                                  disclosureLabel: localized(AffiliateDisclosure.labelKey, locale: locale)) {
                            onOffer(offer)
                        }
                    }
                }
                .padding(.top, Theme.Plan.S.s1)
            }
        }
    }
}

#Preview {
    let brief = TripBrief(destination: "Bologna", startDate: .now, nights: 3, diet: .vegetarian)
    let template = SampleItineraries.templates(for: Identifier("bologna"))[0]
    let day = TripDay(date: .now,
                      city: "Bologna",
                      blocks: SampleItineraries.blocks(from: template, brief: brief))
    return ScrollView {
        DayView(day: day, warnings: ItineraryRules(brief: brief).warnings(for: day))
            .padding(Theme.Plan.S.screen)
    }
    .background(Theme.C.bg)
}
