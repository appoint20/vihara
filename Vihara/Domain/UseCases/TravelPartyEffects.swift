import Foundation

/// What answering the travel-party question actually changed.
///
/// The interview shows this back as a "Was sich damit ändert" panel, and the panel is
/// the point of the step. A question whose consequences cannot be named is a question
/// that should not be asked — so the consequences are computed here, from the same
/// values composition uses, rather than written as reassuring copy in a view.
enum TravelPartyEffect: Hashable, Sendable, Identifiable {
    /// A candidate the party cannot all enter.
    case stopDropped(place: String, minimumAge: Int, childAge: Int)
    /// An afternoon window kept clear for a nap.
    case afternoonHeldForNap(OpeningWindow)
    /// Dinner pulled earlier because children are along.
    case dinnerMovedEarlier(to: MinuteOfDay)
    /// Children who get in for nothing at a priced stop.
    case childrenEnterFree(count: Int, place: String)
    /// What the party pays at a priced stop.
    case admission(place: String, total: Money, heads: Int)
    /// Only step-free routes are offered.
    case stepFreeOnly
    /// Nothing with a standing queue.
    case noLongStanding

    var id: Self { self }
}

/// Works out what a party does to a set of candidates.
///
/// Pure and synchronous: it takes the places a day *could* hold and reports what the
/// party changes about them. Both the interview panel and the composition step read
/// from this, so the promise the panel makes and the plan the traveller gets cannot
/// drift apart.
struct TravelPartyEffects: Sendable {
    let party: TravelParty

    init(party: TravelParty) {
        self.party = party
    }

    /// The candidates this party may actually visit.
    func admissible(from candidates: [Place]) -> [Place] {
        candidates.filter(party.admits)
    }

    /// Everything the party changes, in the order it is worth reading.
    ///
    /// - Parameter candidates: the places a plan would otherwise consider. Pass the
    ///   region's whole candidate set; the dropped ones are the interesting half.
    func effects(against candidates: [Place]) -> [TravelPartyEffect] {
        var found: [TravelPartyEffect] = []

        // Dropped stops first: a plan losing a headline sight is the consequence the
        // traveller most needs to see before they commit to it.
        for place in candidates {
            if let childAge = party.childBlocked(by: place), let minimumAge = place.minimumAge {
                found.append(.stopDropped(place: place.name,
                                          minimumAge: minimumAge,
                                          childAge: childAge))
            }
        }

        if let window = party.napWindow {
            found.append(.afternoonHeldForNap(window))
        }

        if party.hasChildren {
            found.append(.dinnerMovedEarlier(to: party.eveningMealStart))
        }

        for place in party.admits(allOf: candidates) {
            let free = party.childrenAdmittedFree(at: place)
            if free > 0 {
                found.append(.childrenEnterFree(count: free, place: place.name))
            }
            if let total = party.admissionCost(for: place) {
                found.append(.admission(place: place.name, total: total, heads: party.size))
            }
        }

        if party.accommodations.contains(where: \.requiresStepFreeAccess) {
            found.append(.stepFreeOnly)
        }
        if party.accommodations.contains(.noLongStanding) {
            found.append(.noLongStanding)
        }

        return found
    }

    /// The headline consequences, capped so the panel stays a panel.
    ///
    /// Dropped stops always survive the cap: they are the only effect that removes
    /// something the traveller might have been counting on.
    func summary(against candidates: [Place], limit: Int = 4) -> [TravelPartyEffect] {
        let all = effects(against: candidates)
        let dropped = all.filter { if case .stopDropped = $0 { return true } else { return false } }
        let rest = all.filter { if case .stopDropped = $0 { return false } else { return true } }
        return Array((dropped + rest).prefix(max(dropped.count, limit)))
    }
}

private extension TravelParty {
    /// The subset everyone may enter — spelled out here so `effects(against:)` reads
    /// as prose rather than as a filter inside a loop.
    func admits(allOf candidates: [Place]) -> [Place] {
        candidates.filter(admits)
    }
}
