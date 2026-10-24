import Foundation

/// One thing a brief needs to know.
///
/// Six, and exactly six: they are what the home screen counts ("4 von 6") and what
/// the interview has left to ask about. Budget is deliberately not here — it has a
/// defensible default and asking about it up front is how a planner turns into a
/// form.
enum BriefSlot: String, CaseIterable, Hashable, Sendable, Identifiable {
    case destination
    case dates
    case nights
    case pace
    case diet
    case party

    var id: String { rawValue }
}

/// A parse, and how much of it was actually read rather than assumed.
///
/// ``TripBrief`` alone cannot answer this: every field on it has a value, because a
/// brief with holes in it cannot generate. But "3 nights because you said so" and
/// "3 nights because we had to pick something" are different facts, and the whole
/// point of the recognition chips is showing the traveller which is which.
struct ParsedBrief: Hashable, Sendable {
    let brief: TripBrief
    /// The slots the sentence genuinely filled. Everything else on `brief` is a
    /// default standing in until the interview asks.
    let recognised: Set<BriefSlot>

    init(brief: TripBrief, recognised: Set<BriefSlot>) {
        self.brief = brief
        self.recognised = recognised
    }

    /// What the interview still has to ask.
    var outstanding: [BriefSlot] {
        BriefSlot.allCases.filter { !recognised.contains($0) }
    }

    var recognisedCount: Int { recognised.count }
    static var slotCount: Int { BriefSlot.allCases.count }

    /// Nothing typed yet.
    static func empty(_ brief: TripBrief) -> ParsedBrief {
        ParsedBrief(brief: brief, recognised: [])
    }
}
