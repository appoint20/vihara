import Foundation

/// Intake (F-01): one sentence in, a correctable brief out.
///
/// The traveller is never shown an empty form. Whatever the sentence did not say is
/// filled with a stated default and shown as a chip they can change — five steps at
/// most, and usually none (PRD 3.1).
@MainActor
@Observable
final class IntakeViewModel {
    private let parser: any TripBriefParsing
    let catalogue: any DestinationCatalogue
    private let calendar: Calendar

    var sentence: String = ""
    private(set) var brief: TripBrief
    private(set) var isInterpreting = false
    /// Set when the sentence named somewhere we do not cover yet. An honest "not
    /// yet", never a plan we cannot stand behind (PRD 10.2).
    private(set) var unrecognisedDestination: String?
    /// Chips only appear once there is something to correct.
    private(set) var hasBrief: Bool

    /// The destinations the destination chip cycles through. The pilot catalogue is
    /// small enough that cycling beats a search field; a real picker lands with the
    /// second region.
    private(set) var selectableDestinations: [Destination] = []

    init(parser: any TripBriefParsing,
         catalogue: any DestinationCatalogue,
         destination: Destination? = nil,
         calendar: Calendar = .current,
         today: Date = .now) {
        self.parser = parser
        self.catalogue = catalogue
        self.calendar = calendar

        let start = calendar.date(byAdding: .day, value: 21, to: calendar.startOfDay(for: today))
            ?? today
        self.brief = TripBrief(destination: destination?.name ?? "",
                               startDate: start,
                               nights: destination?.suggestedNights ?? 3)
        self.hasBrief = destination != nil
    }

    func loadDestinations() async {
        // The catalogue has no "everything" query by design, so the chip's options are
        // the union of the browsable categories.
        var seen: [Destination] = []
        for category in DestinationCategory.allCases {
            let found = (try? await catalogue.destinations(in: category)) ?? []
            for destination in found where !seen.contains(destination) {
                seen.append(destination)
            }
        }
        selectableDestinations = seen
    }

    /// Parses the sentence. Never throws at the traveller: a sentence we cannot place
    /// leaves the chips as they are and names what was not understood.
    func interpret() async {
        let text = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isInterpreting = true
        defer { isInterpreting = false }

        guard let parsed = try? await parser.parse(text, relativeTo: .now) else { return }
        if parsed.destination.isEmpty {
            unrecognisedDestination = text
            // Everything else the sentence said is still worth keeping.
            var kept = parsed
            kept.destination = brief.destination
            brief = kept
        } else {
            unrecognisedDestination = nil
            brief = parsed
        }
        hasBrief = true
    }

    // MARK: - Chip edits

    func cycleDestination() {
        guard !selectableDestinations.isEmpty else { return }
        let index = selectableDestinations.firstIndex { $0.name == brief.destination }
        let next = selectableDestinations[((index ?? -1) + 1) % selectableDestinations.count]
        brief.destination = next.name
        unrecognisedDestination = nil
        hasBrief = true
    }

    func cyclePace()   { brief.pace = Self.next(after: brief.pace) }
    func cycleBudget() { brief.budget = Self.next(after: brief.budget) }
    func cycleDiet()   { brief.diet = Self.next(after: brief.diet) }
    func cycleStyle()  { brief.travelStyle = Self.next(after: brief.travelStyle) }

    /// Clamped rather than validated: a stepper that refuses a tap is worse than one
    /// that stops. Two weeks is the longest plan the composition budget covers.
    func adjustNights(by delta: Int) {
        brief.nights = min(14, max(1, brief.nights + delta))
    }

    func setStartDate(_ date: Date) {
        brief.startDate = calendar.startOfDay(for: date)
    }

    /// No plan before tomorrow: a trip starting today cannot be revalidated 24 h
    /// ahead of departure (PRD 6.5), so the plan would ship unchecked.
    var earliestStartDate: Date {
        calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now)) ?? .now
    }

    var canGenerate: Bool { brief.isGeneratable }

    private static func next<Value: CaseIterable & Equatable>(after value: Value) -> Value
    where Value.AllCases: RandomAccessCollection, Value.AllCases.Index == Int {
        let all = Value.allCases
        let index = all.firstIndex(of: value) ?? all.startIndex
        return all[(index + 1) % all.count]
    }
}
