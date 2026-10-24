import SwiftUI

/// The whole month, for when the strip is not enough.
///
/// The strip answers "this weekend or next"; this answers "the second week of
/// September". Same selection model as the strip — first tap arrives, second departs,
/// third starts over — so moving between the two never means learning a second set of
/// rules.
struct CalendarSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale

    @State private var selection: DateRangeSelection
    @State private var month: Date

    let onApply: (DateRangeSelection) -> Void

    init(initial: DateRangeSelection, onApply: @escaping (DateRangeSelection) -> Void) {
        _selection = State(initialValue: initial)
        _month = State(initialValue: initial.start ?? .now)
        self.onApply = onApply
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            weekdayHeaders
            grid
            Spacer(minLength: Theme.S.s4)
            footer
        }
        .padding(.horizontal, Theme.S.screen)
        .padding(.top, Theme.S.s5)
        .padding(.bottom, Theme.S.s5)
        .background(Theme.C.bg.ignoresSafeArea())
        .presentationDragIndicator(.visible)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("calendar.title")
                .viharaText(Theme.F.h3)
                .foregroundStyle(Theme.C.text)

            Spacer(minLength: Theme.S.s3)

            monthStep(symbol: "chevron.left", label: "calendar.previousMonth", by: -1)
            Text(monthLabel)
                .viharaText(Theme.F.cardTitle)
                .foregroundStyle(Theme.C.text)
                .frame(minWidth: Theme.Size.destCard.width / 2)
            monthStep(symbol: "chevron.right", label: "calendar.nextMonth", by: 1)
        }
        .padding(.bottom, Theme.S.s4)
    }

    private func monthStep(symbol: String, label: LocalizedStringKey, by delta: Int) -> some View {
        Button {
            withAnimation(Theme.Plan.Motion.standard) {
                month = calendar.date(byAdding: .month, value: delta, to: month) ?? month
            }
        } label: {
            Image(systemName: symbol)
                .viharaText(Theme.F.chevron)
                .foregroundStyle(Theme.C.accentDeep)
                .viharaHitTarget()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }

    private var monthLabel: String {
        month.formatted(.dateTime.month(.wide).year().locale(locale))
    }

    // MARK: - Grid

    private var weekdayHeaders: some View {
        LazyVGrid(columns: columns, spacing: Theme.S.s2) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .viharaText(Theme.F.label)
                    .foregroundStyle(Theme.C.textFaint)
            }
        }
        .padding(.bottom, Theme.S.s2)
    }

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: Theme.S.s2) {
            // Leading blanks so the first of the month lands under the right weekday.
            ForEach(0..<leadingBlanks, id: \.self) { _ in
                Color.clear.frame(height: Theme.Size.dayCell)
            }

            ForEach(daysInMonth, id: \.timeIntervalSince1970) { day in
                DayCell(date: day,
                        position: selection.position(of: day, calendar: calendar),
                        // Joined, so a run of chosen days reads as one bar rather
                        // than as a line of separate pills.
                        joined: true,
                        isEnabled: day >= today) {
                    withAnimation(Theme.Motion.tab) {
                        selection.tap(day, calendar: calendar)
                    }
                    Haptics.pickUp()
                }
            }
        }
        .animation(Theme.Motion.tab, value: month)
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: Theme.S.s2), count: 7)
    }

    /// Narrow weekday names, rotated to the locale's first weekday — Monday in German,
    /// Sunday in en-US. Getting this wrong shifts every date in the grid by a day.
    private var weekdaySymbols: [String] {
        var symbols = calendar.veryShortStandaloneWeekdaySymbols
        let offset = calendar.firstWeekday - 1
        symbols.rotate(by: offset)
        return symbols
    }

    private var firstOfMonth: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: month)) ?? month
    }

    private var leadingBlanks: Int {
        let weekday = calendar.component(.weekday, from: firstOfMonth)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    private var daysInMonth: [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: firstOfMonth) else { return [] }
        return range.compactMap {
            calendar.date(byAdding: .day, value: $0 - 1, to: firstOfMonth)
        }
    }

    private var today: Date { calendar.startOfDay(for: .now) }

    // MARK: - Footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: Theme.S.s4) {
            NotePanel {
                Text(note)
                    .viharaText(Theme.Plan.F.meta)
                    .foregroundStyle(Theme.C.accentDeep)
                    .fixedSize(horizontal: false, vertical: true)

                // The closure risk is a real composition problem in the pilot region,
                // so it is stated here, before the range is applied — not discovered
                // on the plan screen as a warning.
                if let monday = HomeDisplay.mondayInRange(selection, calendar: calendar) {
                    Text(localized("calendar.note.closure",
                                   monday.formatted(.dateTime.day().month(.wide).locale(locale)),
                                   locale: locale))
                        .viharaText(Theme.Plan.F.meta)
                        .foregroundStyle(Theme.C.price)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            PrimaryAction(title: localized("calendar.apply", locale: locale),
                          isEnabled: selection.start != nil) {
                onApply(selection)
                dismiss()
            }
        }
    }

    private var note: String {
        guard let range = HomeDisplay.range(selection, locale: locale, calendar: calendar) else {
            return localized("calendar.hint", locale: locale)
        }
        guard let nights = selection.nights(in: calendar) else {
            return localized("calendar.note.start", range, locale: locale)
        }
        return localized("calendar.note.range",
                         range,
                         HomeDisplay.nights(nights, locale: locale),
                         locale: locale)
    }
}

private extension Array {
    /// Rotates left by `offset`, wrapping. Used to start the weekday row on the
    /// locale's first day.
    mutating func rotate(by offset: Int) {
        guard !isEmpty, offset % count != 0 else { return }
        let split = ((offset % count) + count) % count
        self = Array(self[split...] + self[..<split])
    }
}

#Preview("Kalender · Deutsch") {
    CalendarSheet(initial: DateRangeSelection()) { _ in }
        .environment(\.locale, Locale(identifier: "de"))
        .environment(\.calendar, {
            var calendar = Calendar(identifier: .gregorian)
            calendar.locale = Locale(identifier: "de")
            calendar.firstWeekday = 2
            return calendar
        }())
}

#Preview("Calendar · English") {
    CalendarSheet(initial: DateRangeSelection()) { _ in }
        .environment(\.locale, Locale(identifier: "en"))
        .environment(\.calendar, {
            var calendar = Calendar(identifier: .gregorian)
            calendar.locale = Locale(identifier: "en_US")
            calendar.firstWeekday = 1
            return calendar
        }())
}
