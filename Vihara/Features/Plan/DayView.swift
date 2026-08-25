import SwiftUI

/// One day: a title and three named blocks. No card, no rule, no map underneath —
/// separation is whitespace and type size alone (PRD 5.2).
struct DayView: View {
    let day: TripDay
    let warnings: [PlanWarning]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Plan.S.block) {
            Text(day.title)
                .viharaText(Theme.Plan.F.dayTitle)
                .foregroundStyle(Theme.C.text)
                .fixedSize(horizontal: false, vertical: true)

            if let transfer = day.arrivalTransfer {
                TransferView(transfer: transfer)
            }

            ForEach(day.blocks) { block in
                BlockView(block: block, warnings: warnings.filter { $0.slot == block.slot })
            }
        }
    }
}

/// A half-day. The label is the only chrome it gets.
struct BlockView: View {
    let block: DayBlock
    let warnings: [PlanWarning]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Plan.S.s2) {
            Text(block.slot.label)
                .viharaText(Theme.Plan.F.blockLabel)
                .foregroundStyle(Theme.C.textFaint)

            if block.isEmpty {
                Text("Frei")
                    .viharaText(Theme.Plan.F.item)
                    .foregroundStyle(Theme.C.textFaint)
            } else {
                VStack(alignment: .leading, spacing: Theme.Plan.S.s2) {
                    ForEach(block.items) { item in
                        ItemRow(item: item, warnings: warnings.filter { $0.itemID == item.id })
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
    }
}

/// A *Baustein*.
struct ItemRow: View {
    let item: ItineraryItem
    let warnings: [PlanWarning]

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

            ForEach(warnings) { warning in
                WarningLine(text: warning.message)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// Everything that reads as neutral fact. Anything needing emphasis is drawn
    /// separately above.
    private var badges: [String] {
        var parts: [String] = []
        if let hours = item.place.openingHours, item.kind == .sight {
            parts.append(hours.label)
        }
        if item.place.requiresTicket {
            parts.append("Ticket nötig")
        }
        if let badge = item.place.dietSignal.badge, badge.isConfirmed {
            parts.append(badge.text)
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

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Plan.S.s2) {
            Text("Anreise aus \(transfer.origin)")
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
        }
    }
}

#Preview {
    let brief = TripBrief(destination: "Bologna", startDate: .now, nights: 3, diet: .vegetarian)
    let template = SampleItineraries.templates(for: Identifier("bologna"))[0]
    let day = TripDay(date: .now,
                      city: "Bologna",
                      blocks: SampleItineraries.blocks(from: template,
                                                       diet: .vegetarian,
                                                       pace: brief.pace))
    return ScrollView {
        DayView(day: day, warnings: ItineraryRules(brief: brief).warnings(for: day))
            .padding(Theme.Plan.S.screen)
    }
    .background(Theme.C.bg)
}
