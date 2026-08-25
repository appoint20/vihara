import Foundation

/// The plan as plain text, for sharing.
///
/// The cheapest possible answer to "the plan screen has no primary action", and
/// deliberately so: it needs no paywall, no account, no server and no PDF renderer,
/// and it makes the plan portable today. F-08's watermarked PDF export replaces this
/// as the *primary* action later; this stays as the share sheet's plain-text
/// representation, which is what a traveller pasting a plan into a message actually
/// wants anyway.
///
/// Reuses the same labels the screen draws — ``TripDay/title``, ``DaySlot/label``,
/// ``DietSignal/badge`` — so a shared plan and the plan on screen can never describe
/// the same day differently.
enum PlanTextExport {

    /// - Parameters:
    ///   - brief: what the traveller asked for, rendered as the header line.
    ///   - days: the days validated so far. A partial plan shares as a partial plan.
    static func text(brief: TripBrief, days: [TripDay]) -> String {
        var lines: [String] = []

        lines.append(brief.destination.isEmpty ? "Dein Plan" : brief.destination)
        lines.append([brief.nightsLabel, brief.pace.label, brief.startDateLabel]
            .joined(separator: " · "))

        for day in days {
            lines.append("")
            lines.append(day.title)

            for block in day.blocks where !block.isEmpty {
                lines.append("")
                lines.append(block.slot.label.uppercased())
                for item in block.items {
                    lines.append(line(for: item))
                }
            }
        }

        lines.append("")
        lines.append(disclaimer)
        return lines.joined(separator: "\n")
    }

    /// "  9:15  Basilica di Santo Stefano — Via Santo Stefano 24 · Ticket nötig"
    private static func line(for item: ItineraryItem) -> String {
        var parts = ["• "]
        if let startsAt = item.startsAt {
            parts.append("\(startsAt.label)  ")
        }
        parts.append(item.place.name)

        var notes: [String] = [item.place.address]
        if let badge = item.place.dietSignal.badge {
            notes.append(badge.text)
        }
        if item.place.requiresTicket {
            notes.append("Ticket vorab nötig")
        }
        if let travel = item.travelFromPrevious {
            notes.append(travel.label)
        }
        parts.append(" — " + notes.joined(separator: " · "))
        return parts.joined()
    }

    /// The AI-transparency rule (PRD 8) travels with the plan.
    ///
    /// A plan pasted into a chat loses the screen it was drawn on, so the caveat has
    /// to be part of the text — otherwise the one place the disclaimer matters most,
    /// where somebody else is reading it secondhand, is the one place it is missing.
    /// Kept in step with ``PlanView``'s footnote.
    static let disclaimer = """
        Automatisch erstellt mit Vihara. Öffnungszeiten und Adressen sind noch nicht \
        gegen Live-Daten geprüft — bitte kurz vor Ort bestätigen.
        """
}
