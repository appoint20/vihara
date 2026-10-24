import Foundation

/// Hand-written plans for the Italy pilot.
///
/// These stand in for the composition service until it exists. They are real places
/// with real addresses and plausible hours on purpose: a stub full of "Restaurant 1"
/// hides exactly the layout problems — long Italian names, two-line addresses, diet
/// badges next to ticket warnings — that the plan screen has to survive.
enum SampleItineraries {

    /// One day of a plan, before it is anchored to a date.
    struct DayTemplate {
        let city: String
        let arrivalTransfer: Transfer?
        let morning: [ItineraryItem]
        let afternoon: [ItineraryItem]
        /// Evening meal candidates. The first one satisfying the stated diet wins,
        /// which is how the diet filter (F-04) shows up in the stub.
        let eveningMeals: [ItineraryItem]
        let eveningExtras: [ItineraryItem]
    }

    /// The templates for a destination, cycled if the trip runs longer than the set.
    ///
    /// Keyed on the destination's identity rather than on its name, and returning
    /// nothing for anywhere we have not curated. Both matter: the previous version
    /// re-folded the name here and fell through to `default: emiliaRomagna`, so
    /// picking Formentera produced a plan whose header said Formentera and whose days
    /// said Bologna. There is no default now — an uncurated destination yields an
    /// empty set, and ``StubTripGenerator`` turns that into
    /// ``DomainError/noValidatedCandidates(destination:)`` rather than into a plan
    /// for the wrong city.
    static func templates(for destination: Identifier<Destination>) -> [DayTemplate] {
        switch destination.rawValue {
        case "bologna", "modena", "ravenna": emiliaRomagna
        default: []
        }
    }

    /// Composes a day for a brief.
    ///
    /// Four rules, applied in this order, each of them an answer the traveller gave:
    ///
    /// 1. **The party filters candidates.** A place with an age limit nobody in the
    ///    party clears is gone before anything else runs — there is no point pacing a
    ///    day around a tower a seven-year-old cannot climb.
    /// 2. **A nap holds the afternoon.** Anything starting inside the window comes
    ///    out, rather than being quietly rescheduled on top of it.
    /// 3. **The diet picks the meal**, which is how F-04 shows up in the stub.
    /// 4. **The pace trims the blocks**, because a day breaking the composition rules
    ///    should never reach the traveller — the validation gate would reject it, and
    ///    so does this.
    static func blocks(from template: DayTemplate, brief: TripBrief) -> [DayBlock] {
        let party = brief.party

        let morning = party.admissible(template.morning)
        var afternoon = party.admissible(template.afternoon)
        if let nap = party.napWindow {
            afternoon = afternoon.filter { item in
                guard let startsAt = item.startsAt else { return true }
                return !nap.contains(startsAt)
            }
        }

        let mealCandidates = party.admissible(template.eveningMeals)
        var meal = mealCandidates.first { $0.place.dietSignal.satisfies(brief.diet) }
            ?? mealCandidates.first
        // Children eat earlier. The plan says so rather than booking a table nobody
        // in the party will enjoy sitting at.
        meal?.startsAt = party.eveningMealStart

        let evening = [meal].compactMap { $0 } + party.admissible(template.eveningExtras)

        return [
            DayBlock(slot: .morning, items: fit(morning, to: brief.maxItemsPerBlock)),
            DayBlock(slot: .afternoon, items: fit(afternoon, to: brief.maxItemsPerBlock)),
            DayBlock(slot: .evening, items: fit(evening, to: brief.maxItemsPerBlock)),
        ]
    }

    /// Every place a day could hold, for the region a brief names.
    ///
    /// The interview's "Was sich damit ändert" panel needs the candidates *before*
    /// the party filters them — the interesting half is what gets dropped.
    static func candidatePlaces(for destination: Identifier<Destination>) -> [Place] {
        templates(for: destination)
            .flatMap { $0.morning + $0.afternoon + $0.eveningMeals + $0.eveningExtras }
            .map(\.place)
            .reduce(into: [Place]()) { unique, place in
                if !unique.contains(where: { $0.providerPlaceID == place.providerPlaceID }) {
                    unique.append(place)
                }
            }
    }

    /// Keeps what the pace allows, and at most one headline sight per block.
    ///
    /// Takes the limit rather than the pace, so a traveller's own numbers reach
    /// composition the same way a bucket does.
    private static func fit(_ items: [ItineraryItem], to limit: Int) -> [ItineraryItem] {
        var kept: [ItineraryItem] = []
        for item in items where kept.count < limit {
            if item.isHeadline, kept.contains(where: \.isHeadline) { continue }
            kept.append(item)
        }
        // The first item of a block has nothing to walk from.
        if !kept.isEmpty { kept[0].travelFromPrevious = nil }
        return kept
    }

    // MARK: - Emilia-Romagna

    private static var emiliaRomagna: [DayTemplate] {
        [bolognaCentre, bolognaHills, modenaDayTrip, ravennaDayTrip]
    }

    private static var bolognaCentre: DayTemplate {
        DayTemplate(
            city: "Bologna",
            arrivalTransfer: nil,
            morning: [
                item(sanPetronio, .sight, at: (8, 30), for: 75, because: "sanPetronio"),
                item(quadrilatero, .activity, at: (10, 15), for: 60, from: .init(mode: .walk, minutes: 7), because: "quadrilatero"),
            ],
            afternoon: [
                item(asinelli, .sight, at: (15, 0), for: 60, because: "asinelli"),
            ],
            eveningMeals: [
                item(botanica, .meal, at: (19, 30), for: 90, because: "botanica"),
                item(daGianni, .meal, at: (19, 30), for: 90, because: "daGianni"),
                item(dellOrsa, .meal, at: (19, 30), for: 90, because: "dellOrsa"),
            ],
            eveningExtras: []
        )
    }

    private static var bolognaHills: DayTemplate {
        DayTemplate(
            city: "Bologna",
            arrivalTransfer: nil,
            morning: [
                item(sanLuca, .sight, at: (9, 0), for: 150, because: "sanLuca"),
            ],
            afternoon: [
                item(archiginnasio, .sight, at: (14, 30), for: 60, because: "archiginnasio"),
                item(mercatoErbe, .meal, at: (16, 0), for: 45, from: .init(mode: .walk, minutes: 9), because: "mercatoErbe"),
            ],
            eveningMeals: [
                item(dellOrsa, .meal, at: (20, 0), for: 90, because: "dellOrsa"),
                item(botanica, .meal, at: (20, 0), for: 90, because: "botanica"),
            ],
            eveningExtras: []
        )
    }

    private static var modenaDayTrip: DayTemplate {
        DayTemplate(
            city: "Modena",
            arrivalTransfer: bolognaToModena,
            morning: [
                item(modenaDuomo, .sight, at: (9, 45), for: 60, because: "modenaDuomo"),
                item(albinelli, .sight, at: (11, 0), for: 60, from: .init(mode: .walk, minutes: 5), because: "albinelli"),
            ],
            afternoon: [
                item(ferrariMuseum, .activity, at: (14, 30), for: 105, because: "ferrariMuseum"),
            ],
            eveningMeals: [
                item(aldina, .meal, at: (19, 0), for: 90, because: "aldina"),
            ],
            eveningExtras: []
        )
    }

    private static var ravennaDayTrip: DayTemplate {
        DayTemplate(
            city: "Ravenna",
            arrivalTransfer: bolognaToRavenna,
            morning: [
                item(sanVitale, .sight, at: (9, 30), for: 90, because: "sanVitale"),
                item(gallaPlacidia, .sight, at: (11, 15), for: 30, from: .init(mode: .walk, minutes: 2), because: "gallaPlacidia"),
            ],
            afternoon: [
                item(apollinareNuovo, .sight, at: (14, 30), for: 60, because: "apollinareNuovo"),
            ],
            eveningMeals: [
                item(caDeVen, .meal, at: (19, 30), for: 90, because: "caDeVen"),
            ],
            eveningExtras: []
        )
    }

    // MARK: - Transfers

    private static var bolognaToModena: Transfer {
        Transfer(origin: "Bologna", destination: "Modena", options: [
            .init(mode: .regionalTrain, minutes: 25, priceBand: .between(4, 9),
                  note: "Keine Reservierung nötig", partner: .trainline),
            .init(mode: .highSpeedTrain, minutes: 18, priceBand: .between(13, 24),
                  note: "Zentrum zu Zentrum", partner: .trainline),
            .init(mode: .rentalCar, minutes: 50, priceBand: .between(45, 70),
                  note: "ZTL-Sperrzone im Zentrum", partner: .discoverCars),
        ])
    }

    private static var bolognaToRavenna: Transfer {
        Transfer(origin: "Bologna", destination: "Ravenna", options: [
            .init(mode: .regionalTrain, minutes: 72, priceBand: .from(8),
                  note: "Direktverbindung", partner: .trainline),
            .init(mode: .rentalCar, minutes: 65, priceBand: .between(45, 70),
                  note: "Parken außerhalb der Altstadt", partner: .discoverCars),
            .init(mode: .coach, minutes: 105, priceBand: .between(7, 14),
                  note: "Abfahrt außerhalb", partner: nil),
        ])
    }

    // MARK: - Places

    private static let sanPetronio = place(
        "Basilica di San Petronio", "Piazza Maggiore, 40124 Bologna",
        44.4929, 11.3426, opens: (8, 30), closes: (13, 0))

    private static let quadrilatero = place(
        "Quadrilatero-Markt", "Via Pescherie Vecchie, 40124 Bologna",
        44.4941, 11.3452, opens: (7, 0), closes: (14, 0))

    private static let asinelli = place(
        "Torre degli Asinelli", "Piazza di Porta Ravegnana, 40126 Bologna",
        44.4938, 11.3467, opens: (10, 0), closes: (19, 0), ticket: true,
        // 498 steps and a hard minimum age. This is the candidate a family loses.
        minimumAge: 12, admission: euros(5), stepFree: false)

    private static let archiginnasio = place(
        "Archiginnasio & Teatro Anatomico", "Piazza Galvani 1, 40124 Bologna",
        44.4919, 11.3437, opens: (10, 0), closes: (18, 0), ticket: true,
        admission: euros(3, freeUnder: 6))

    private static let sanLuca = place(
        "Santuario della Madonna di San Luca", "Via di San Luca 36, 40135 Bologna",
        44.4794, 11.2986, opens: (7, 0), closes: (18, 30))

    private static let mercatoErbe = place(
        "Mercato delle Erbe", "Via Ugo Bassi 25, 40121 Bologna",
        44.4959, 11.3406, opens: (7, 0), closes: (24, 0),
        diet: .likely(.vegetarian))

    private static let daGianni = place(
        "Trattoria da Gianni", "Via Clavature 18, 40124 Bologna",
        44.4933, 11.3446, opens: (12, 0), closes: (22, 30),
        // Downgraded from `.confirmed(.vegetarian, source: .venueMenu)`. "bestätigt"
        // may only ever come from a provider attribute or a venue's structured menu
        // (see ``DietSignal``), and nothing here has been read from either — these
        // are hand-written literals. Restore the confirmed signals in the commit that
        // turns on F-03, not before. The confirmed rendering stays reviewable in
        // `DayView`'s preview and pinned by `PlanDisplayTests`.
        diet: .likely(.vegetarian))

    private static let dellOrsa = place(
        "Osteria dell'Orsa", "Via Mentana 1, 40126 Bologna",
        44.4972, 11.3478, opens: (12, 0), closes: (24, 0),
        diet: .likely(.vegetarian))

    private static let botanica = place(
        "Botanica Lab Cucina", "Via Battibecco 4, 40123 Bologna",
        44.4944, 11.3404, opens: (12, 0), closes: (23, 0),
        // Downgraded for the same reason as `daGianni` above.
        diet: .likely(.vegan))

    private static let modenaDuomo = place(
        "Duomo di Modena", "Corso Duomo, 41121 Modena",
        44.6462, 10.9256, opens: (7, 0), closes: (19, 0))

    private static let albinelli = place(
        "Mercato Albinelli", "Via Luigi Albinelli 13, 41121 Modena",
        44.6447, 10.9269, opens: (6, 30), closes: (14, 30),
        diet: .likely(.vegetarian))

    private static let ferrariMuseum = place(
        "Museo Enzo Ferrari", "Via Paolo Ferrari 85, 41121 Modena",
        44.6487, 10.9169, opens: (9, 30), closes: (19, 0), ticket: true,
        admission: euros(22, freeUnder: 6), stepFree: true)

    private static let aldina = place(
        "Trattoria Aldina", "Via Luigi Albinelli 40, 41121 Modena",
        44.6444, 10.9270, opens: (12, 0), closes: (22, 0),
        diet: .likely(.vegetarian))

    private static let sanVitale = place(
        "Basilica di San Vitale", "Via San Vitale 17, 48121 Ravenna",
        44.4208, 12.1959, opens: (9, 0), closes: (19, 0), ticket: true,
        admission: euros(12.50, freeUnder: 11), stepFree: true)

    private static let gallaPlacidia = place(
        "Mausoleo di Galla Placidia", "Via San Vitale 17, 48121 Ravenna",
        44.4212, 12.1961, opens: (9, 0), closes: (19, 0), ticket: true)

    private static let apollinareNuovo = place(
        "Basilica di Sant'Apollinare Nuovo", "Via di Roma 53, 48121 Ravenna",
        44.4165, 12.2027, opens: (9, 0), closes: (19, 0), ticket: true)

    private static let caDeVen = place(
        "Ca' de Vèn", "Via Corrado Ricci 24, 48121 Ravenna",
        44.4172, 12.2000, opens: (11, 30), closes: (22, 30),
        diet: .likely(.vegetarian))

    // MARK: - Builders

    private static func place(_ name: String,
                              _ address: String,
                              _ latitude: Double,
                              _ longitude: Double,
                              opens: (Int, Int)? = nil,
                              closes: (Int, Int)? = nil,
                              diet: DietSignal = .notApplicable,
                              ticket: Bool = false,
                              minimumAge: Int? = nil,
                              admission: Admission? = nil,
                              stepFree: Bool? = nil) -> Place {
        var hours: OpeningWindow?
        if let opens, let closes {
            hours = OpeningWindow(opensAt: MinuteOfDay(hour: opens.0, minute: opens.1),
                                  closesAt: MinuteOfDay(hour: closes.0, minute: closes.1))
        }
        return Place(providerPlaceID: "stub:\(name)",
                     name: name,
                     address: address,
                     coordinate: Coordinate(latitude: latitude, longitude: longitude),
                     openingHours: hours,
                     dietSignal: diet,
                     requiresTicket: ticket,
                     minimumAge: minimumAge,
                     admission: admission,
                     isStepFree: stepFree)
    }

    /// Prices and age limits are stub values alongside the rest of this file. They
    /// are plausible rather than checked, and the plan says as much — see
    /// ``PlanView``'s footnote. The age limit on the Asinelli is the one number here
    /// that genuinely matters, because it is what removes the tower from a family's
    /// plan.
    private static func euros(_ amount: Decimal, freeUnder: Int? = nil) -> Admission {
        Admission(adultPrice: Money(amount), freeUnderAge: freeUnder)
    }

    /// The reason key is derived from the place's own name, so a stop cannot end up
    /// wearing another stop's justification. In production the composing model writes
    /// free text into the same field.
    private static func item(_ place: Place,
                             _ kind: ItineraryItem.Kind,
                             at time: (Int, Int),
                             for minutes: Int,
                             from leg: TravelLeg? = nil,
                             because reason: String) -> ItineraryItem {
        ItineraryItem(place: place,
                      kind: kind,
                      startsAt: MinuteOfDay(hour: time.0, minute: time.1),
                      durationMinutes: minutes,
                      travelFromPrevious: leg,
                      reason: "reason.\(reason)")
    }
}
