import SwiftUI

/// Picking a range by tapping days.
///
/// Three taps and no modes: the first sets the arrival, the second sets the
/// departure, the third starts again. Tapping *before* the arrival restarts rather
/// than producing a backwards range — someone who taps the 3rd and then the 1st has
/// changed their mind about arriving, not asked to travel into the past.
///
/// A value type with no view in it, so the rule is testable rather than something you
/// have to tap through a sheet to check.
struct DateRangeSelection: Equatable, Sendable {
    private(set) var start: Date?
    private(set) var end: Date?

    init(start: Date? = nil, end: Date? = nil) {
        self.start = start
        self.end = end
    }

    var isComplete: Bool { start != nil && end != nil }

    /// Nights away. A range of one day is a day trip and no nights.
    func nights(in calendar: Calendar) -> Int? {
        guard let start, let end else { return nil }
        return calendar.dateComponents([.day], from: start, to: end).day
    }

    mutating func tap(_ day: Date, calendar: Calendar) {
        let day = calendar.startOfDay(for: day)

        switch (start, end) {
        case (nil, _):
            start = day
            end = nil
        case let (.some(existing), nil):
            if day < existing {
                // Earlier than the arrival: they are re-choosing the arrival.
                start = day
            } else if calendar.isDate(day, inSameDayAs: existing) {
                // Tapping the arrival again clears it, which is the only way back to
                // an empty range without a button nobody would look for.
                start = nil
            } else {
                end = day
            }
        case (.some, .some):
            start = day
            end = nil
        }
    }

    /// Whether a day sits inside the chosen range, ends included.
    func contains(_ day: Date, calendar: Calendar) -> Bool {
        guard let start else { return false }
        let day = calendar.startOfDay(for: day)
        guard let end else { return calendar.isDate(day, inSameDayAs: start) }
        return day >= start && day <= end
    }

    /// How a given day should be drawn.
    func position(of day: Date, calendar: Calendar) -> DayCell.Position {
        guard let start else { return .plain }
        let day = calendar.startOfDay(for: day)

        guard let end else {
            return calendar.isDate(day, inSameDayAs: start) ? .only : .plain
        }
        if calendar.isDate(day, inSameDayAs: start) { return .start }
        if calendar.isDate(day, inSameDayAs: end) { return .end }
        return day > start && day < end ? .inside : .plain
    }

    /// Every day in the range, for a caller that needs to inspect them — a closure
    /// risk, a total, a count.
    func days(in calendar: Calendar) -> [Date] {
        guard let start, let end else { return start.map { [$0] } ?? [] }
        var days: [Date] = []
        var cursor = start
        while cursor <= end {
            days.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return days
    }
}

/// One day, in the strip or in the month grid.
///
/// Unselected is white on a hairline; inside the range is an accent tint; the two
/// ends are filled with the ink colour. The ends round only on their outer edge when
/// `joined` is set, so a run of days in the grid reads as one continuous bar rather
/// than as seven separate pills.
struct DayCell: View {
    let date: Date
    let position: Position
    var joined: Bool = false
    var isEnabled: Bool = true
    let action: () -> Void

    enum Position: Equatable {
        case plain
        case inside
        case start
        case end
        /// The only day chosen so far.
        case only
    }

    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale

    var body: some View {
        Button(action: action) {
            VStack(spacing: Theme.S.s05) {
                Text(weekday)
                    .viharaText(Theme.Plan.F.blockLabel)
                    .foregroundStyle(secondaryColour)
                Text(dayNumber)
                    .viharaText(Theme.F.dayNumber)
                    .foregroundStyle(primaryColour)
                    .monospacedDigit()
            }
            .frame(width: Theme.Size.dayCell, height: Theme.Size.dayCell)
            .background { background }
            .contentShape(Rectangle())
            .opacity(isEnabled ? 1 : 0.35)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(accessibleDate)
        .accessibilityAddTraits(position == .plain ? [] : [.isSelected])
    }

    @ViewBuilder
    private var background: some View {
        switch position {
        case .plain:
            RoundedRectangle(cornerRadius: Theme.R.dayCell, style: .continuous)
                .fill(Theme.C.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.R.dayCell, style: .continuous)
                        .strokeBorder(Theme.C.border, lineWidth: Theme.Size.hairline)
                }
        case .inside:
            // Square when joined, so consecutive days meet without a seam.
            RoundedRectangle(cornerRadius: joined ? 0 : Theme.R.dayCell, style: .continuous)
                .fill(Theme.C.accent.opacity(Theme.O.glassFill))
        case .start:
            edge(leading: true)
        case .end:
            edge(leading: false)
        case .only:
            RoundedRectangle(cornerRadius: Theme.R.dayCell, style: .continuous)
                .fill(Theme.C.text)
        }
    }

    /// A filled end. Rounds on its outer edge only when the run continues inward.
    private func edge(leading: Bool) -> some View {
        UnevenRoundedRectangle(
            topLeadingRadius: joined && !leading ? 0 : Theme.R.dayCell,
            bottomLeadingRadius: joined && !leading ? 0 : Theme.R.dayCell,
            bottomTrailingRadius: joined && leading ? 0 : Theme.R.dayCell,
            topTrailingRadius: joined && leading ? 0 : Theme.R.dayCell,
            style: .continuous
        )
        .fill(Theme.C.text)
    }

    private var isFilled: Bool { position == .start || position == .end || position == .only }
    private var primaryColour: Color { isFilled ? Theme.C.bg : Theme.C.text }
    private var secondaryColour: Color {
        isFilled ? Theme.C.bg.opacity(Theme.O.chevron) : Theme.C.textFaint
    }

    private var weekday: String {
        DayCellLabels.weekday(for: date, locale: locale)
    }

    private var dayNumber: String {
        DayCellLabels.dayNumber(for: date, calendar: calendar)
    }

    private var accessibleDate: String {
        DayCellLabels.accessible(for: date, locale: locale)
    }
}

/// Cached day labels.
///
/// `Date.formatted(_:)` builds a formatter each time it is called, and a strip is
/// fourteen cells asking for two strings apiece. Re-rendering the strip on every
/// keystroke meant twenty-eight formatter builds per character, which is most of what
/// made typing feel slow.
///
/// The values are pure functions of (date, locale), so caching them is safe until the
/// locale changes — which drops the cache.
enum DayCellLabels {
    private struct Key: Hashable {
        let day: Int
        let month: Int
        let year: Int
        let locale: String
        let kind: Kind

        enum Kind { case weekday, accessible }
    }

    private static let cache = LabelCache()

    static func weekday(for date: Date, locale: Locale) -> String {
        cached(date, locale, .weekday) {
            date.formatted(.dateTime.weekday(.narrow).locale(locale))
        }
    }

    static func accessible(for date: Date, locale: Locale) -> String {
        cached(date, locale, .accessible) {
            date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(locale))
        }
    }

    /// Not cached: integer-to-string is cheaper than a dictionary lookup.
    static func dayNumber(for date: Date, calendar: Calendar) -> String {
        String(calendar.component(.day, from: date))
    }

    private static func cached(_ date: Date,
                               _ locale: Locale,
                               _ kind: Key.Kind,
                               _ build: () -> String) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        let parts = calendar.dateComponents([.day, .month, .year], from: date)
        let key = Key(day: parts.day ?? 0,
                      month: parts.month ?? 0,
                      year: parts.year ?? 0,
                      locale: locale.identifier,
                      kind: kind)
        return cache.value(for: key, build: build)
    }

    private final class LabelCache: @unchecked Sendable {
        private var storage: [Key: String] = [:]
        private let lock = NSLock()

        func value(for key: Key, build: () -> String) -> String {
            lock.lock()
            if let hit = storage[key] {
                lock.unlock()
                return hit
            }
            lock.unlock()

            let built = build()

            lock.lock()
            // A strip holds a fortnight and a month sheet thirty-one days; a few
            // hundred entries covers every screen anyone will scroll through, and
            // dropping the lot is cheaper than tracking ages.
            if storage.count > 400 { storage.removeAll(keepingCapacity: true) }
            storage[key] = built
            lock.unlock()
            return built
        }
    }
}

/// The next seven days, or whichever week the chosen range sits in.
///
/// Horizontally scrollable rather than wrapped: a week is a line, and breaking it
/// across two rows costs the one thing the strip is for — seeing a run of days at a
/// glance.
struct CalendarStrip: View {
    let days: [Date]
    let selection: DateRangeSelection
    let onTap: (Date) -> Void

    @Environment(\.calendar) private var calendar

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.S.s2) {
                ForEach(days, id: \.timeIntervalSince1970) { day in
                    DayCell(date: day,
                            position: selection.position(of: day, calendar: calendar)) {
                        onTap(day)
                    }
                }
            }
            .padding(.horizontal, Theme.S.screen)
            .padding(.vertical, Theme.S.s1)
        }
        .scrollClipDisabled()
    }
}

#Preview("Calendar strip") {
    @Previewable @State var selection = DateRangeSelection()
    let calendar = Calendar.current
    let days = (0..<14).compactMap {
        calendar.date(byAdding: .day, value: $0, to: calendar.startOfDay(for: .now))
    }

    return VStack(alignment: .leading, spacing: Theme.S.s4) {
        CalendarStrip(days: days, selection: selection) { day in
            selection.tap(day, calendar: calendar)
        }
        Text(selection.isComplete ? "Range chosen" : "Tap an arrival, then a departure")
            .viharaText(Theme.F.small)
            .foregroundStyle(Theme.C.textMuted)
            .padding(.horizontal, Theme.S.screen)
    }
    .frame(maxHeight: .infinity, alignment: .center)
    .background(Theme.C.bg)
}
