import SwiftUI

/// Everything the traveller can change, and an honest note about what the app is.
///
/// Reached from the gear on the home screen and from the fourth tab. Four settings
/// and no account: there is nothing to log into, nothing is uploaded, and the About
/// section says so plainly rather than leaving people to wonder where their plans
/// went.
struct SettingsView: View {
    @Environment(\.locale) private var locale

    @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.deviceDefault
    @AppStorage("travellerName") private var travellerName = ""
    @AppStorage(NavigationApp.storageKey) private var navigationApp = NavigationApp.apple
    @AppStorage(DistanceUnit.storageKey) private var units = DistanceUnit.metric

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.S.sectionTop) {
            header

            section("settings.language") {
                SegmentedChips(
                    title: nil,
                    options: AppLanguage.allCases.map {
                        .init(id: $0.rawValue,
                              value: $0,
                              label: localized("settings.language.\($0.rawValue)", locale: locale))
                    },
                    selection: $language
                )
            }

            section("settings.traveller", footer: "settings.traveller.footer") {
                TextField(text: $travellerName) { Text("settings.traveller.placeholder") }
                    .viharaText(Theme.F.sentence)
                    .foregroundStyle(Theme.C.text)
                    .tint(Theme.C.accent)
                    .textContentType(.givenName)
                    .padding(Theme.S.s3)
                    .frame(minHeight: Theme.S.tapTarget)
                    .background {
                        RoundedRectangle(cornerRadius: Theme.R.compactCard, style: .continuous)
                            .strokeBorder(Theme.C.border, lineWidth: Theme.Size.hairline)
                    }
                    .accessibilityLabel(Text("settings.traveller.name"))
            }

            section("settings.navigation", footer: "settings.navigation.footer") {
                SegmentedChips(
                    title: nil,
                    options: NavigationApp.allCases.map {
                        .init(id: $0.rawValue,
                              value: $0,
                              label: localized($0.localizationKey, locale: locale))
                    },
                    selection: $navigationApp
                )
            }

            section("settings.units") {
                SegmentedChips(
                    title: nil,
                    options: DistanceUnit.allCases.map {
                        .init(id: $0.rawValue,
                              value: $0,
                              label: localized($0.localizationKey, locale: locale))
                    },
                    selection: $units
                )
            }

            about
        }
        .padding(.horizontal, Theme.S.screen)
        .padding(.top, Theme.S.s2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.S.s1) {
            Text(verbatim: "Vihara")
                .viharaText(Theme.F.brand)
                .foregroundStyle(Theme.C.textMuted)
            Text("settings.title")
                .viharaText(Theme.F.h2)
                .foregroundStyle(Theme.C.text)
        }
    }

    private func section<Content: View>(_ title: LocalizedStringKey,
                                        footer: LocalizedStringKey? = nil,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.S.s3) {
            Text(title)
                .viharaText(Theme.Plan.F.blockLabel)
                .foregroundStyle(Theme.C.textFaint)

            content()

            if let footer {
                Text(footer)
                    .viharaText(Theme.Plan.F.meta)
                    .foregroundStyle(Theme.C.textFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Names the data sources, and says what the app is not.
    ///
    /// "No account, no login" belongs in the product's own words rather than only in
    /// a privacy manifest nobody reads — it is the reason there is no sign-in wall,
    /// and travellers are entitled to know where their plans live.
    private var about: some View {
        VStack(alignment: .leading, spacing: Theme.S.s3) {
            Text("settings.about")
                .viharaText(Theme.Plan.F.blockLabel)
                .foregroundStyle(Theme.C.textFaint)

            Text("settings.about.body")
                .viharaText(Theme.F.small)
                .foregroundStyle(Theme.C.textMuted)
                .fixedSize(horizontal: false, vertical: true)

            NotePanel {
                Text("settings.about.noAccount")
                    .viharaText(Theme.Plan.F.meta)
                    .foregroundStyle(Theme.C.accentDeep)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(localized("settings.version", Self.version, Self.build, locale: locale))
                .viharaText(Theme.Plan.F.blockLabel)
                .foregroundStyle(Theme.C.textFaint)
        }
    }

    private static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }
}

// MARK: - Preferences

/// Which app "Route" hands off to.
enum NavigationApp: String, CaseIterable, Identifiable, Sendable {
    case apple
    case google

    var id: String { rawValue }
    var localizationKey: String { "settings.navigation.\(rawValue)" }

    static let storageKey = "navigationApp"
}

/// Kilometres or miles. Walking distances are the only place it shows, which is
/// exactly where a German reader wants metres and an American one wants feet.
enum DistanceUnit: String, CaseIterable, Identifiable, Sendable {
    case metric
    case imperial

    var id: String { rawValue }
    var localizationKey: String { "settings.units.\(rawValue)" }

    static let storageKey = "distanceUnit"
}

#Preview("Einstellungen · Deutsch") {
    ScrollView { SettingsView() }
        .background(Theme.C.bg)
        .environment(\.locale, Locale(identifier: "de"))
}

#Preview("Settings · English") {
    ScrollView { SettingsView() }
        .background(Theme.C.bg)
        .environment(\.locale, Locale(identifier: "en"))
}
