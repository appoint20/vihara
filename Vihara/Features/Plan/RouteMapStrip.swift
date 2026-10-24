import SwiftUI
import MapKit

/// The day's route, once, above the first day.
///
/// PRD 5.2 says no map *behind* the plan, and this is not that: it is a 170pt strip
/// that answers one question — "how far apart is all this?" — and then gets out of
/// the way. A full-screen map would make the plan a cockpit; a strip makes the walk
/// legible without competing with the list underneath it.
///
/// Plan tokens throughout: 2pt radius, 20pt inset, no shadow.
struct RouteMapStrip: View {
    let day: TripDay
    @Environment(\.locale) private var locale
    @Environment(\.openURL) private var openURL
    @AppStorage(NavigationApp.storageKey) private var navigationApp = NavigationApp.apple
    @AppStorage(DistanceUnit.storageKey) private var units = DistanceUnit.metric

    private var stops: [ItineraryItem] { day.blocks.flatMap(\.items) }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Plan.S.s2) {
            map
            footer
        }
    }

    // MARK: - Map

    private var map: some View {
        Map(initialPosition: .region(region), interactionModes: []) {
            // The line first, so the numbered pins sit on top of it.
            MapPolyline(coordinates: stops.map(\.place.coordinate).map(Self.location))
                .stroke(Theme.C.accent, style: StrokeStyle(lineWidth: Theme.Size.selectedBorder,
                                                           lineCap: .round,
                                                           lineJoin: .round))

            ForEach(Array(stops.enumerated()), id: \.element.id) { index, item in
                Annotation(item.place.name,
                           coordinate: Self.location(item.place.coordinate)) {
                    pin(number: index + 1)
                }
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .frame(height: Theme.Size.mapStrip)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Plan.R.surface, style: .continuous))
        .allowsHitTesting(false)
        .accessibilityElement()
        .accessibilityLabel(Text("plan.map.label"))
    }

    /// Numbered, because the plan is ordered and an unnumbered pin cannot say which
    /// stop it is.
    private func pin(number: Int) -> some View {
        Text("\(number)")
            .viharaText(Theme.Plan.F.blockLabel)
            .foregroundStyle(Theme.C.bg)
            .monospacedDigit()
            .frame(width: Theme.Size.mapPin, height: Theme.Size.mapPin)
            .background {
                Circle()
                    .fill(Theme.C.text)
                    .overlay { Circle().strokeBorder(Theme.C.bg, lineWidth: Theme.Size.hairline) }
            }
    }

    /// A region holding every stop, with room around the edges so no pin sits on the
    /// border.
    private var region: MKCoordinateRegion {
        let coordinates = stops.map(\.place.coordinate)
        guard let first = coordinates.first else {
            return MKCoordinateRegion(center: Self.location(Coordinate(latitude: 44.4938,
                                                                       longitude: 11.3467)),
                                      span: MKCoordinateSpan(latitudeDelta: 0.05,
                                                             longitudeDelta: 0.05))
        }

        let latitudes = coordinates.map(\.latitude)
        let longitudes = coordinates.map(\.longitude)
        let minLat = latitudes.min() ?? first.latitude
        let maxLat = latitudes.max() ?? first.latitude
        let minLon = longitudes.min() ?? first.longitude
        let maxLon = longitudes.max() ?? first.longitude

        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2,
                                            longitude: (minLon + maxLon) / 2)
        // A floor on the span, so a day whose stops are all on one piazza does not
        // zoom to street furniture.
        let span = MKCoordinateSpan(latitudeDelta: max((maxLat - minLat) * 1.6, 0.012),
                                    longitudeDelta: max((maxLon - minLon) * 1.6, 0.012))
        return MKCoordinateRegion(center: center, span: span)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Plan.S.s3) {
            Text(localized("plan.map.walking", walkingLabel, locale: locale))
                .viharaText(Theme.Plan.F.meta)
                .foregroundStyle(Theme.C.textMuted)

            Spacer(minLength: Theme.Plan.S.s2)

            Button {
                open(RouteDestination.wholeDay(day))
            } label: {
                Text("plan.map.openInMaps")
                    .viharaText(Theme.Plan.F.meta)
                    .foregroundStyle(Theme.C.accentDeep)
                    .padding(.horizontal, Theme.Plan.S.s3)
                    .padding(.vertical, Theme.Plan.S.s1)
                    .frame(minHeight: Theme.S.tapTarget)
                    .background {
                        RoundedRectangle(cornerRadius: Theme.R.pill, style: .continuous)
                            .strokeBorder(Theme.C.border, lineWidth: Theme.Size.hairline)
                    }
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    /// Minutes, or kilometres for a day long enough that minutes stop meaning
    /// anything. Roughly 80 m a minute at a strolling pace.
    private var walkingLabel: String {
        let minutes = day.walkingMinutes
        guard units == .imperial else {
            return "\(minutes) min"
        }
        let miles = Double(minutes) * 80 / 1609.34
        return miles.formatted(.number.precision(.fractionLength(1)).locale(locale)) + " mi"
    }

    private func open(_ destination: RouteDestination) {
        let urls = destination.urls(for: navigationApp)
        if let app = urls.app {
            // The scheme opens the app when it is installed; the completion tells us
            // when it is not, and the https form always works.
            openURL(app) { accepted in
                if !accepted, let web = urls.web { openURL(web) }
            }
        } else if let web = urls.web {
            openURL(web)
        }
    }
}

/// Where a hand-off is going: the whole day, or one stop.
enum RouteDestination {
    case wholeDay(TripDay)
    case singleStop(Coordinate)

    func urls(for app: NavigationApp) -> (app: URL?, web: URL?) {
        switch (self, app) {
        case let (.wholeDay(day), .google):
            let urls = MapHandoff.googleMapsURLs(through: day.routeCoordinates)
            return (urls.app, urls.web)
        case let (.singleStop(coordinate), .google):
            let urls = MapHandoff.googleMapsURLs(to: coordinate)
            return (urls.app, urls.web)
        case let (.wholeDay(day), .apple):
            return (nil, MapHandoff.appleMapsURL(through: day.routeCoordinates))
        case let (.singleStop(coordinate), .apple):
            return (nil, MapHandoff.appleMapsURL(to: coordinate))
        }
    }
}

extension RouteMapStrip {
    static func location(_ coordinate: Coordinate) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}
