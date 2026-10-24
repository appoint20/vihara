import Foundation

/// The plan, flattened into what a page needs (F-08).
///
/// A presentation model, not a domain one: it is built from the same labels the
/// screen draws — ``TripDay/title``, ``DaySlot/label``, ``DietSignal/badge`` — for the
/// same reason ``PlanTextExport`` does. A PDF and the screen that produced it must
/// never describe the same day differently, and the only way to guarantee that is to
/// share the formatting rather than re-implement it.
///
/// Pure values and no UIKit, so pagination and truncation are unit-testable without
/// rendering anything.
struct PlanDocument: Hashable, Sendable {
    let title: String
    let subtitle: String
    let days: [Day]
    /// Days the preview withheld, named so the page can say "and 2 more days" rather
    /// than simply stopping.
    let withheldDayTitles: [String]
    let disclaimer: String
    /// Repeated across every page when set. `nil` for a full export.
    let watermark: String?

    struct Day: Hashable, Sendable {
        let title: String
        let blocks: [Block]
    }

    struct Block: Hashable, Sendable {
        let label: String
        let entries: [Entry]
    }

    struct Entry: Hashable, Sendable {
        let time: String?
        let name: String
        /// Address, diet badge and travel time, joined — the same notes the text
        /// export writes.
        let detail: String
        /// Anything that costs money or turns somebody away, kept separate so the
        /// renderer can colour it.
        let caution: String?
    }

    var isEmpty: Bool { days.isEmpty }
}

extension PlanDocument {

    /// Builds the document a grant permits.
    ///
    /// The grant decides how much is included. A `.preview` carries one day in full
    /// and names the rest — see ``ExportGrant/preview(daysInFull:)`` for why a
    /// watermark alone is not a paywall.
    static func make(brief: TripBrief,
                     days: [TripDay],
                     grant: ExportGrant,
                     locale: Locale = .current) -> PlanDocument {
        let included: [TripDay]
        let withheld: [TripDay]

        switch grant {
        case .full:
            included = days
            withheld = []
        case let .preview(daysInFull):
            let count = max(0, min(daysInFull, days.count))
            included = Array(days.prefix(count))
            withheld = Array(days.dropFirst(count))
        }

        return PlanDocument(
            title: brief.destination.isEmpty
                ? localized("plan.untitled", locale: locale)
                : brief.destination,
            subtitle: [brief.nightsLabel(locale: locale),
                       brief.pace.label(locale: locale),
                       brief.startDateLabel(locale: locale)].joined(separator: " · "),
            days: included.map { day(from: $0, locale: locale) },
            withheldDayTitles: withheld.map(\.title),
            disclaimer: PlanTextExport.disclaimer(locale: locale),
            watermark: grant.isWatermarked
                ? localized("export.watermark", locale: locale)
                : nil
        )
    }

    private static func day(from day: TripDay, locale: Locale) -> Day {
        Day(title: day.title,
            blocks: day.blocks.filter { !$0.isEmpty }.map { block in
                Block(label: block.slot.label.uppercased(),
                      entries: block.items.map { entry(from: $0, locale: locale) })
            })
    }

    private static func entry(from item: ItineraryItem, locale: Locale) -> Entry {
        var notes = [item.place.address]
        if let badge = item.place.dietSignal.badge {
            notes.append(badge.text)
        }
        if let travel = item.travelFromPrevious {
            notes.append(travel.label)
        }

        var cautions: [String] = []
        if item.place.requiresTicket {
            cautions.append(localized("plan.stop.ticket", locale: locale))
        }
        if let minimumAge = item.place.minimumAge {
            cautions.append(localized("plan.stop.minimumAge", minimumAge, locale: locale))
        }
        if let admission = item.place.admission {
            cautions.append(localized("plan.stop.admission",
                                      admission.adultPrice.label(locale: locale),
                                      locale: locale))
        }

        return Entry(time: item.startsAt?.label,
                     name: item.place.name,
                     detail: notes.joined(separator: " · "),
                     caution: cautions.isEmpty ? nil : cautions.joined(separator: " · "))
    }
}
