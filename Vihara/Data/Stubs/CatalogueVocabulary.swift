import Foundation

/// Builds the vocabulary ``ResolveCapture`` matches captions against.
///
/// Two sources, in priority order. The curated destinations come first and carry a
/// `destinationID`, so a caption mentioning Bologna resolves to somewhere we can
/// actually plan. The 285-city corpus follows, so a caption mentioning Lissabon still
/// resolves — to a city we can name and not yet plan, which is the honest answer and
/// the same distinction the search field makes.
enum CatalogueVocabulary {

    static func build(curated: [Destination] = PilotDestinationCatalogue.curated,
                      corpus: BundledCityCatalogue = .bundled) -> PlaceVocabulary {
        var entries: [PlaceVocabulary.Entry] = []
        var claimed: Set<String> = []

        for destination in curated {
            entries.append(PlaceVocabulary.Entry(name: destination.name,
                                                 destinationID: destination.id))
            claimed.insert(fold(destination.name))
        }

        for city in corpus.rows where !claimed.contains(fold(city.name)) {
            // The endonym and the English name matter as much as the German one:
            // captions are written by whoever filmed the video, and a Reel about
            // Florence says "Firenze" as often as "Florenz".
            entries.append(PlaceVocabulary.Entry(name: city.name,
                                                 terms: [city.localName] + city.aliases))
            claimed.insert(fold(city.name))
        }

        return PlaceVocabulary(entries: entries)
    }

    private static func fold(_ text: String) -> String {
        BundledCityCatalogue.fold(text)
    }
}
