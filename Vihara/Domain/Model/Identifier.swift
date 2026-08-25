import Foundation

/// A type-safe identifier.
///
/// `Identifier<Trip>` and `Identifier<Place>` are different types, so a place id can
/// never be passed where a trip id is expected — a class of bug that stringly-typed
/// ids invite and that the export/entitlement paths (which key on `trip_id`) cannot
/// afford.
struct Identifier<Subject>: Hashable, Sendable, CustomStringConvertible {
    let rawValue: String

    init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    static func generate() -> Self {
        Self(UUID().uuidString)
    }

    var description: String { rawValue }
}
