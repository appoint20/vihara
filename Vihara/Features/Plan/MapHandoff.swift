import Foundation

/// Building the URLs that hand a day off to a maps app.
///
/// Pure string work, kept out of the view so it can be tested — a malformed
/// directions URL fails silently by opening a search for gibberish, which is exactly
/// the kind of bug nobody notices until a traveller is standing on a corner.
enum MapHandoff {

    /// The whole day, as a multi-stop route.
    ///
    /// Google Maps first via its own scheme, because someone who chose Google Maps in
    /// Settings wants the app and not a browser tab. The `https` form is the fallback
    /// and works everywhere, including when Google Maps is not installed.
    static func googleMapsURLs(through coordinates: [Coordinate]) -> (app: URL?, web: URL) {
        let points = coordinates.map(Self.point)

        // Origin, destination, and everything between as waypoints — the shape both
        // the scheme and the web form expect.
        let origin = points.first ?? ""
        let destination = points.last ?? ""
        let waypoints = points.dropFirst().dropLast().joined(separator: "|")

        var app = URLComponents(string: "comgooglemaps://")
        app?.queryItems = queryItems(origin: origin, destination: destination, waypoints: waypoints)

        // The `dir` form takes its stops as path components, which is the documented
        // shape and survives being pasted into a browser.
        let path = points.joined(separator: "/")
        let web = URL(string: "https://www.google.com/maps/dir/\(path)")
            ?? URL(string: "https://www.google.com/maps")!

        return (app?.url, web)
    }

    /// Directions to a single stop, from wherever the traveller is standing.
    static func googleMapsURLs(to coordinate: Coordinate) -> (app: URL?, web: URL) {
        let destination = point(coordinate)

        var app = URLComponents(string: "comgooglemaps://")
        app?.queryItems = queryItems(origin: "", destination: destination, waypoints: "")

        let web = URL(string: "https://www.google.com/maps/dir/?api=1&destination=\(destination)")
            ?? URL(string: "https://www.google.com/maps")!

        return (app?.url, web)
    }

    /// Apple Maps, for travellers who chose it in Settings.
    static func appleMapsURL(to coordinate: Coordinate) -> URL {
        URL(string: "https://maps.apple.com/?daddr=\(point(coordinate))&dirflg=w")
            ?? URL(string: "https://maps.apple.com")!
    }

    static func appleMapsURL(through coordinates: [Coordinate]) -> URL {
        guard let last = coordinates.last else { return URL(string: "https://maps.apple.com")! }
        // Apple Maps takes one destination; the first stop becomes the origin so the
        // route at least starts in the right place.
        let origin = coordinates.first.map { "&saddr=\(point($0))" } ?? ""
        return URL(string: "https://maps.apple.com/?daddr=\(point(last))\(origin)&dirflg=w")
            ?? URL(string: "https://maps.apple.com")!
    }

    /// Walking, always. The plan is a walking plan — every distance in it is a
    /// walking distance, and handing off to driving directions would contradict the
    /// itinerary the traveller is holding.
    private static func queryItems(origin: String,
                                   destination: String,
                                   waypoints: String) -> [URLQueryItem] {
        var items = [URLQueryItem(name: "daddr", value: destination),
                     URLQueryItem(name: "directionsmode", value: "walking")]
        if !origin.isEmpty, origin != destination {
            items.insert(URLQueryItem(name: "saddr", value: origin), at: 0)
        }
        if !waypoints.isEmpty {
            items.append(URLQueryItem(name: "waypoints", value: waypoints))
        }
        return items
    }

    /// "44.4938,11.3467" — six decimal places, which is about a tenth of a metre and
    /// well past what any maps app resolves.
    static func point(_ coordinate: Coordinate) -> String {
        String(format: "%.6f,%.6f", coordinate.latitude, coordinate.longitude)
    }
}

extension TripDay {
    /// Every stop of the day, in order, for drawing a route through.
    var routeCoordinates: [Coordinate] {
        blocks.flatMap(\.items).map(\.place.coordinate)
    }

    /// Total walking minutes across the day, from the legs between stops.
    var walkingMinutes: Int {
        blocks.flatMap(\.items)
            .compactMap(\.travelFromPrevious)
            .filter { $0.mode == .walk }
            .reduce(0) { $0 + $1.minutes }
    }
}
