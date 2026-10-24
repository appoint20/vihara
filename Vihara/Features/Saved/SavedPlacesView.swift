import SwiftUI

/// The Merkliste — regions kept for later.
///
/// The fourth tab used to be a label with nothing behind it, which is a routine App
/// Review rejection and, more to the point, a lie to anyone who taps it. This is the
/// smallest thing that makes it true: a bookmark, a list, and a way to take something
/// off it again. Bookmarks live on the device, like everything else here.
struct SavedPlacesView: View {
    @Environment(\.locale) private var locale
    @AppStorage(SavedPlaces.storageKey) private var storedIDs = ""

    let catalogue: any DestinationCatalogue

    @State private var all: [Destination] = []

    private var saved: [Destination] {
        let ids = SavedPlaces.ids(from: storedIDs)
        return ids.compactMap { id in all.first { $0.id.rawValue == id } }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if saved.isEmpty {
                Text("saved.empty")
                    .viharaText(Theme.F.body)
                    .foregroundStyle(Theme.C.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Theme.S.screen)
                    .padding(.top, Theme.S.sectionTop)
            } else {
                VStack(spacing: Theme.S.s3) {
                    ForEach(saved) { destination in
                        row(for: destination)
                    }
                }
                .padding(.horizontal, Theme.S.screen)
                .padding(.top, Theme.S.s5)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task {
            all = (try? await catalogue.search(query: "")) ?? []
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.S.s1) {
            Text("saved.subtitle")
                .viharaText(Theme.F.small)
                .foregroundStyle(Theme.C.textMuted)
            Text("saved.title")
                .viharaText(Theme.F.h2)
                .foregroundStyle(Theme.C.text)
        }
        .padding(.horizontal, Theme.S.screen)
        .padding(.top, Theme.S.s2)
    }

    private func row(for destination: Destination) -> some View {
        HStack(spacing: Theme.S.s3) {
            AssetImage(name: destination.imageSlug)
                .frame(width: Theme.Size.compactThumb, height: Theme.Size.compactThumb)
                .clipShape(RoundedRectangle(cornerRadius: Theme.R.compactThumb, style: .continuous))

            VStack(alignment: .leading, spacing: Theme.S.s05) {
                Text(destination.name)
                    .viharaText(Theme.F.cardTitle)
                    .foregroundStyle(Theme.C.text)
                Text(destination.region)
                    .viharaText(Theme.Plan.F.meta)
                    .foregroundStyle(Theme.C.textMuted)
            }

            Spacer(minLength: Theme.S.s2)

            Button {
                storedIDs = SavedPlaces.toggling(destination.id.rawValue, in: storedIDs)
                Haptics.release()
            } label: {
                Image(systemName: "bookmark.fill")
                    .viharaText(Theme.F.glyph)
                    .foregroundStyle(Theme.C.accent)
                    .viharaHitTarget()
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(localized("saved.remove", destination.name, locale: locale)))
        }
        .padding(Theme.S.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: Theme.R.compactCard, style: .continuous)
                .fill(Theme.C.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.R.compactCard, style: .continuous)
                        .strokeBorder(Theme.C.border, lineWidth: Theme.Size.hairline)
                }
        }
    }
}

/// The bookmark list, stored as one string.
///
/// A comma-joined list of destination ids in `@AppStorage`, because `@AppStorage` has
/// no `Set` and the alternative — a repository, a DTO and a mapper — would be more
/// machinery than a list of five bookmarks deserves. If this ever needs to sync it
/// moves to ``TripRepository``'s neighbourhood and gets the full treatment.
enum SavedPlaces {
    static let storageKey = "savedDestinationIDs"

    static func ids(from raw: String) -> [String] {
        raw.split(separator: ",").map(String.init).filter { !$0.isEmpty }
    }

    static func contains(_ id: String, in raw: String) -> Bool {
        ids(from: raw).contains(id)
    }

    static func toggling(_ id: String, in raw: String) -> String {
        var current = ids(from: raw)
        if let index = current.firstIndex(of: id) {
            current.remove(at: index)
        } else {
            current.append(id)
        }
        return current.joined(separator: ",")
    }
}

#Preview("Merkliste · Deutsch") {
    ScrollView { SavedPlacesView(catalogue: PilotDestinationCatalogue()) }
        .background(Theme.C.bg)
        .environment(\.locale, Locale(identifier: "de"))
}

#Preview("Saved · English") {
    ScrollView { SavedPlacesView(catalogue: PilotDestinationCatalogue()) }
        .background(Theme.C.bg)
        .environment(\.locale, Locale(identifier: "en"))
}
