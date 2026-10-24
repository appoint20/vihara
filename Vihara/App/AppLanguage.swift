import SwiftUI

/// The language the traveller chose, independent of the device.
///
/// Vihara is a German-first product with an English reading. Someone travelling with
/// a German phone may want the plan in English to show a waiter, and someone with an
/// English phone may prefer German — so the choice belongs in the app, not to the
/// system. It lives in `@AppStorage("appLanguage")` and is applied once, in
/// ``RootView``, as the environment locale.
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case german = "de"
    case english = "en"

    var id: String { rawValue }

    var locale: Locale { Locale(identifier: rawValue) }

    /// Named in its own language, always. A German speaker looking for German should
    /// not have to recognise the word "German".
    var endonym: LocalizedStringKey {
        switch self {
        case .german:  "settings.language.de"
        case .english: "settings.language.en"
        }
    }

    /// What the app opens as before anyone chooses: the device's preference when we
    /// speak it, German otherwise.
    static var deviceDefault: AppLanguage {
        let preferred = Locale.preferredLanguages.first.map(Locale.init(identifier:))
        return preferred?.language.languageCode?.identifier == "en" ? .english : .german
    }

    /// The `@AppStorage` key, in one place so a typo cannot silently split the
    /// setting from the thing that reads it.
    static let storageKey = "appLanguage"
}

// MARK: - Strings with parameters

/// Resolves a localized string that takes arguments.
///
/// SwiftUI's `Text(LocalizedStringKey)` builds its key from the *whole* literal,
/// interpolation included — so `Text("home.stops.nights \(n)")` would look for a key
/// called `"home.stops.nights %lld"`. Our keys are stable names rather than sentences,
/// which is what lets copy change without a key changing, so arguments are applied
/// here instead of by the literal.
///
/// Parameterless strings stay `Text("tab.plan")` and resolve through the environment
/// locale as usual; this exists only for the ones that interpolate.
func localized(_ key: String, _ arguments: any CVarArg..., locale: Locale) -> String {
    let format = NSLocalizedString(key, bundle: .vihara(for: locale), comment: "")
    return arguments.isEmpty ? format : String(format: format, locale: locale, arguments: arguments)
}

extension Bundle {
    /// The `.lproj` bundle for a locale, falling back to the main bundle.
    ///
    /// Cached, because this resolves on every label of every row and `path(forResource:)`
    /// touches the filesystem.
    static func vihara(for locale: Locale) -> Bundle {
        let code = locale.language.languageCode?.identifier ?? "de"
        if let cached = localizedBundles.withLock({ $0[code] }) { return cached }

        let resolved = Bundle.main.path(forResource: code, ofType: "lproj")
            .flatMap(Bundle.init(path:)) ?? .main
        localizedBundles.withLock { $0[code] = resolved }
        return resolved
    }

    private static let localizedBundles = Mutex<[String: Bundle]>([:])
}

/// A minimal mutual-exclusion box.
///
/// Foundation's `Mutex` is iOS 18; the deployment target is 17, and pulling in a
/// dependency for one dictionary would be worse than nine lines.
private final class Mutex<Value>: @unchecked Sendable {
    private var value: Value
    private let lock = NSLock()

    init(_ value: Value) { self.value = value }

    func withLock<Result>(_ body: (inout Value) -> Result) -> Result {
        lock.lock()
        defer { lock.unlock() }
        return body(&value)
    }
}
