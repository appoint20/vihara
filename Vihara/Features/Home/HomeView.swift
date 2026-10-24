import SwiftUI

/// The home surface. One screenful, top to bottom, and it does not scroll.
///
/// Greeting, route, dates, preferences, the two ways on — and then nothing. The rails
/// and mood chips that used to sit below the fold are gone, because a screen that
/// does not scroll has no below-the-fold to hide things in. Anything that will not
/// fit does not belong here.
///
/// The one exception is accessibility text sizes, where "fits" stops being true at
/// any layout: `ViewThatFits` tries the fixed arrangement first and falls back to a
/// scrolling one. A reader who asked for larger type gets larger type rather than a
/// truncated screen.
struct HomeView: View {
    @Environment(Router.self) private var router
    @Environment(Session.self) private var session
    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar

    @AppStorage("travellerName") private var travellerName = ""

    @State private var model: HomeViewModel
    @State private var inbox: CaptureInboxViewModel
    @State private var isInboxPresented = false
    @State private var savedTrips: SavedTripsViewModel
    @State private var selectedNav = 0
    /// The search text lives here, not in the model — see ``HomeViewModel/query``.
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    init(model: HomeViewModel, inbox: CaptureInboxViewModel, savedTrips: SavedTripsViewModel) {
        _model = State(wrappedValue: model)
        _inbox = State(wrappedValue: inbox)
        _savedTrips = State(wrappedValue: savedTrips)
    }

    var body: some View {
        Group {
            switch selectedNav {
            case 0: planSurface
            case 1: scrolling { SavedTripsView(model: savedTrips) }
            case 2: scrolling { SavedPlacesView(catalogue: model.catalogue) }
            default: scrolling { SettingsView() }
            }
        }
        .background(Theme.C.bg.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BottomNav(items: NavItem.all, selected: $selectedNav)
                .padding(.horizontal, Theme.S.screen)
                .padding(.bottom, Theme.S.navBottom)
                // The nav belongs to the device, not to the content: riding up on
                // the keyboard made it look like part of the form. It stays put and
                // the keyboard covers it, which is what every other iOS tab bar does.
                .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await model.load() }
        // The inbox is read on every appearance, not once: the traveller may have
        // shared three Reels while the app sat in the background.
        .task { await inbox.load() }
        .sheet(isPresented: $isInboxPresented) {
            CaptureInboxSheet(model: inbox) { suggestion in
                model.add(suggestion)
                isInboxPresented = false
            }
        }
        .sheet(isPresented: $model.isCalendarPresented) {
            CalendarSheet(initial: model.selection) { model.applyDateRange($0) }
        }
        .sheet(isPresented: $model.isSettingsPresented) {
            NavigationStack { scrolling { SettingsView() } }
        }
        .sheet(isPresented: $model.isInterviewPresented, onDismiss: {
            Task { await model.refreshDrafts() }
        }) {
            TripPlannerInterviewView(
                model: TripPlannerInterviewViewModel(catalogue: model.catalogue,
                                                     drafts: model.draftStore,
                                                     seed: model.interviewSeed,
                                                     resumingAt: model.resumeAtStep)
            )
        }
    }

    /// The other tabs are lists and settings — those scroll, as lists do.
    private func scrolling<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ScrollView {
            content()
                .padding(.bottom, Theme.S.s8 + Theme.S.navBottom + Theme.S.tapTarget)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - The plan surface

    /// Does not scroll when it fits, scrolls when it cannot.
    ///
    /// This was a `ViewThatFits`, which built and measured *two* copies of the whole
    /// surface on every keystroke — the search field, the calendar strip, the chips,
    /// all of it, twice, per character. That is what made typing lag.
    ///
    /// `scrollBounceBehavior(.basedOnSize)` gets the same behaviour from one copy:
    /// the content is laid out once, and the scroll view only actually scrolls when
    /// it overflows — which at default text sizes it does not.
    private var planSurface: some View {
        ScrollView {
            surface
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.interactively)
    }

    private var surface: some View {
        VStack(alignment: .leading, spacing: Theme.S.s5) {
            wordmarkRow
            greeting
            sharedPosts
            routeSection
            dateSection
            preferenceSection
            waysOn
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.S.screen)
        .padding(.top, Theme.S.s2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Only drawn when something was shared in.
    ///
    /// A permanent "0 geteilte Beiträge" row would be exactly the inert chrome the
    /// design rules refuse — the bottom nav shows two items for the same reason.
    @ViewBuilder
    private var sharedPosts: some View {
        if inbox.hasCaptures {
            Button {
                isInboxPresented = true
            } label: {
                HStack(spacing: Theme.S.s2) {
                    Text(localized("inbox.waiting", inbox.count, locale: locale))
                        .viharaText(Theme.F.body)
                        .foregroundStyle(Theme.C.accentDeep)
                    Spacer(minLength: 0)
                }
                .viharaInlineHitTarget()
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 1 · Wordmark

    private var wordmarkRow: some View {
        HStack(spacing: Theme.S.s2) {
            Image("vihara_logo")
                .resizable()
                .scaledToFit()
                .frame(height: Theme.Size.tabIcon)

            Text(verbatim: "Vihara")
                .viharaText(Theme.F.brand)
                .foregroundStyle(Theme.C.text)

            Spacer(minLength: Theme.S.s3)

            Button {
                model.isSettingsPresented = true
            } label: {
                Image(systemName: "gearshape")
                    .viharaText(Theme.F.glyph)
                    .foregroundStyle(Theme.C.text)
                    .frame(width: Theme.Size.headerButton, height: Theme.Size.headerButton)
                    .overlay { Circle().strokeBorder(Theme.C.border, lineWidth: Theme.Size.hairline) }
                    .viharaHitTarget()
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("home.settings.open"))
        }
    }

    // MARK: - 2 · Greeting

    /// The name comes from the signed-in account, and is overridden by anything the
    /// traveller typed into Settings — somebody who corrected their name meant it.
    private var greeting: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.S.s2) {
            Image(systemName: "sparkles")
                .viharaText(Theme.F.glyph)
                .foregroundStyle(Theme.C.accent)

            Text(HomeDisplay.greeting(name: session.greetingName(overriddenBy: travellerName),
                                      at: .now,
                                      calendar: calendar,
                                      locale: locale))
                .viharaText(Theme.F.greeting)
                .foregroundStyle(Theme.C.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - 3 · Deine Route

    private var routeSection: some View {
        VStack(alignment: .leading, spacing: Theme.S.s2) {
            Text("home.stops.title")
                .viharaText(Theme.Plan.F.blockLabel)
                .foregroundStyle(Theme.C.textFaint)

            CitySearchField(text: $searchText,
                            placeholder: localized("home.search.placeholder", locale: locale),
                            isFocused: $isSearchFocused) {
            } onClear: {
                searchText = ""
                model.search(for: "")
            }
            .onChange(of: searchText) { _, text in
                model.search(for: text)
            }

            // Results replace the chips while searching rather than pushing them
            // down: the screen does not scroll, so nothing may grow without
            // something else giving way.
            if isSearchFocused, !searchText.isEmpty {
                searchResults
            } else {
                routeChips
            }
        }
    }

    @ViewBuilder
    private var searchResults: some View {
        VStack(alignment: .leading, spacing: 0) {
            if model.isSearching {
                Text("home.search.searching")
                    .viharaText(Theme.Plan.F.meta)
                    .foregroundStyle(Theme.C.textFaint)
                    .padding(.vertical, Theme.S.s2)
            } else if model.searchFailed {
                Text("home.search.failed")
                    .viharaText(Theme.Plan.F.meta)
                    .foregroundStyle(Theme.C.price)
                    .padding(.vertical, Theme.S.s2)
            } else if model.suggestions.isEmpty {
                Text("home.search.none")
                    .viharaText(Theme.Plan.F.meta)
                    .foregroundStyle(Theme.C.textFaint)
                    .padding(.vertical, Theme.S.s2)
            } else {
                ForEach(model.suggestions.prefix(Self.maxSuggestions)) { suggestion in
                    Button {
                        withAnimation(Theme.Plan.Motion.standard) { model.add(suggestion) }
                        searchText = ""
                        isSearchFocused = false
                        Haptics.commit()
                    } label: {
                        suggestionRow(suggestion)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Four is what fits without the screen needing to scroll, and more than four
    /// autocomplete rows is a list nobody reads to the bottom of anyway.
    private static let maxSuggestions = 4

    private func suggestionRow(_ suggestion: PlaceSuggestion) -> some View {
        HStack(spacing: Theme.S.s3) {
            Image(systemName: suggestion.isPlannable ? "checkmark.seal" : "mappin.and.ellipse")
                .viharaText(Theme.Plan.F.meta)
                .foregroundStyle(suggestion.isPlannable ? Theme.C.accent : Theme.C.textFaint)
                .frame(width: Theme.Size.inlineIcon)

            VStack(alignment: .leading, spacing: 0) {
                Text(suggestion.name)
                    .viharaText(Theme.F.chip)
                    .foregroundStyle(Theme.C.text)
                if !suggestion.region.isEmpty {
                    Text(suggestion.region)
                        .viharaText(Theme.Plan.F.blockLabel)
                        .foregroundStyle(Theme.C.textFaint)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: Theme.S.s2)

            // Says which suggestions we can actually plan, rather than letting a
            // traveller find out three taps later.
            if !suggestion.isPlannable {
                Text("home.search.notYet")
                    .viharaText(Theme.Plan.F.blockLabel)
                    .foregroundStyle(Theme.C.textFaint)
            }
        }
        .padding(.vertical, Theme.S.s2)
        .frame(minHeight: Theme.S.tapTarget, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var routeChips: some View {
        VStack(alignment: .leading, spacing: Theme.S.s2) {
            FlowLayout(spacing: Theme.S.s2, lineSpacing: Theme.S.s2) {
                ForEach(model.stops) { stop in
                    TokenChip(title: stop.name,
                              detail: HomeDisplay.stopNights(stop.nights, locale: locale),
                              removeLabel: localized("home.stops.remove", stop.name, locale: locale)) {
                        withAnimation(Theme.Plan.Motion.standard) { model.remove(stop) }
                    }
                    .draggable(stop.id) {
                        TokenChip(title: stop.name, detail: "", removeLabel: "") {}
                    }
                    .dropDestination(for: String.self) { items, _ in
                        move(items.first, before: stop)
                    }
                }
            }

            Text(model.hasUnplannableStop ? "home.stops.unplannable" : "home.stops.caption")
                .viharaText(Theme.Plan.F.meta)
                .foregroundStyle(model.hasUnplannableStop ? Theme.C.price : Theme.C.textFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Drag reorder. The payload is the stop's id, unique within a route.
    private func move(_ draggedID: String?, before target: HomeViewModel.Stop) -> Bool {
        guard let draggedID,
              let from = model.stops.firstIndex(where: { $0.id == draggedID }),
              let to = model.stops.firstIndex(where: { $0.id == target.id }),
              from != to
        else { return false }

        withAnimation(Theme.Plan.Motion.standard) {
            model.move(from: IndexSet(integer: from), to: to > from ? to + 1 : to)
        }
        Haptics.commit()
        return true
    }

    // MARK: - 4 · Dates

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: Theme.S.s2) {
            HStack(alignment: .firstTextBaseline) {
                Button {
                    model.isCalendarPresented = true
                } label: {
                    HStack(spacing: Theme.S.s1) {
                        Text(monthLabel)
                            .viharaText(Theme.F.h3)
                            .foregroundStyle(Theme.C.text)
                        Image(systemName: "chevron.down")
                            .viharaText(Theme.F.chevron)
                            .foregroundStyle(Theme.C.textMuted)
                    }
                    .viharaInlineHitTarget()
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("home.calendar.open"))

                Spacer(minLength: Theme.S.s3)

                Button {
                    model.isCalendarPresented = true
                } label: {
                    Text("home.calendar.whole")
                        .viharaText(Theme.F.small)
                        .foregroundStyle(Theme.C.accentDeep)
                        .viharaInlineHitTarget()
                }
                .buttonStyle(.plain)
            }

            // The strip is the one thing here that scrolls, and it scrolls sideways:
            // a week is a line, and breaking it across rows loses the run of days.
            CalendarStrip(days: model.stripDays, selection: model.selection) { day in
                withAnimation(Theme.Motion.tab) { model.tapDay(day) }
            }
            .padding(.horizontal, -Theme.S.screen)

            Text(dateCaption)
                .viharaText(Theme.Plan.F.meta)
                .foregroundStyle(Theme.C.textFaint)
        }
    }

    private var monthLabel: String {
        (model.selection.start ?? .now).formatted(.dateTime.month(.wide).year().locale(locale))
    }

    private var dateCaption: String {
        guard let range = HomeDisplay.range(model.selection, locale: locale, calendar: calendar) else {
            return localized("home.calendar.caption.empty", locale: locale)
        }
        let nights = model.selection.nights(in: calendar) ?? model.totalNights
        return localized("home.calendar.caption", range,
                         HomeDisplay.nights(nights, locale: locale), locale: locale)
    }

    // MARK: - 5 · Preferences

    /// Two counts you type and three choices you pick.
    ///
    /// Nothing cycles here any more. A count is not an enumeration — reaching "3
    /// children" by tapping a chip three times is wrong in a way that gets worse the
    /// larger the number — and even for the three enumerations, a menu costs one tap
    /// to open and one to answer whatever the answer is.
    private var preferenceSection: some View {
        VStack(alignment: .leading, spacing: Theme.S.s2) {
            Text("home.preferences.title")
                .viharaText(Theme.Plan.F.blockLabel)
                .foregroundStyle(Theme.C.textFaint)

            HStack(spacing: Theme.S.s3) {
                NumberField(caption: "party.adults",
                            placeholder: localized("home.party.adults.placeholder", locale: locale),
                            range: 1...9,
                            text: $model.preferences.adultsText)

                NumberField(caption: "party.children",
                            placeholder: localized("home.party.children.placeholder", locale: locale),
                            range: 0...6,
                            text: $model.preferences.childrenText)
            }

            FlowLayout(spacing: Theme.S.s2, lineSpacing: Theme.S.s2) {
                MenuChip(caption: "slot.pace",
                         options: TripBrief.Pace.allCases.map {
                             .init(id: $0.rawValue, value: $0, label: $0.label(locale: locale))
                         },
                         unsetLabel: unsetLabel,
                         selection: $model.preferences.pace)

                MenuChip(caption: "slot.diet",
                         options: TripBrief.DietRequirement.allCases.map {
                             .init(id: $0.rawValue, value: $0, label: $0.label(locale: locale))
                         },
                         unsetLabel: unsetLabel,
                         selection: $model.preferences.diet)

                MenuChip(caption: "slot.budget",
                         options: TripBrief.BudgetBand.allCases.map {
                             .init(id: $0.rawValue, value: $0, label: $0.label(locale: locale))
                         },
                         unsetLabel: unsetLabel,
                         selection: $model.preferences.budget)
            }
            .animation(Theme.Motion.tab, value: model.preferences)
        }
    }

    private var unsetLabel: String {
        localized("home.preferences.unset", locale: locale)
    }

    // MARK: - 6 · The two ways on

    private var waysOn: some View {
        VStack(alignment: .leading, spacing: Theme.S.s2) {
            PrimaryAction(title: model.outstandingQuestions == 0
                            ? localized("home.cta.continue.done", locale: locale)
                            : localized("home.cta.continue", model.outstandingQuestions, locale: locale)) {
                model.startInterview()
            }

            Button {
                router.push(.plan(brief: model.quickBrief))
            } label: {
                Text("home.cta.quick")
                    .viharaText(Theme.Plan.F.action)
                    .foregroundStyle(Theme.C.text)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: Theme.S.tapTarget + Theme.Plan.S.s1)
                    .background {
                        RoundedRectangle(cornerRadius: Theme.R.pill, style: .continuous)
                            .strokeBorder(Theme.C.border, lineWidth: Theme.Size.hairline)
                    }
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!model.canGenerate)
            .opacity(model.canGenerate ? 1 : 0.35)
        }
    }
}

#Preview("Home · Deutsch") {
    let dependencies = AppDependencies.stubbed()
    return NavigationStack {
        HomeView(model: HomeViewModel(catalogue: dependencies.destinations,
                                      placeSearch: dependencies.placeSearch,
                                      drafts: dependencies.interviewDrafts),
                 inbox: CaptureInboxViewModel(inbox: dependencies.sharedInbox,
                                              captions: dependencies.captions,
                                              vocabulary: dependencies.vocabulary,
                                              placeSearch: dependencies.placeSearch),
                 savedTrips: SavedTripsViewModel(trips: dependencies.trips))
    }
    .environment(Router())
    .environment(Session(service: dependencies.authentication))
    .environment(\.locale, Locale(identifier: "de"))
}

#Preview("Home · English") {
    let dependencies = AppDependencies.stubbed()
    return NavigationStack {
        HomeView(model: HomeViewModel(catalogue: dependencies.destinations,
                                      placeSearch: dependencies.placeSearch,
                                      drafts: dependencies.interviewDrafts),
                 inbox: CaptureInboxViewModel(inbox: dependencies.sharedInbox,
                                              captions: dependencies.captions,
                                              vocabulary: dependencies.vocabulary,
                                              placeSearch: dependencies.placeSearch),
                 savedTrips: SavedTripsViewModel(trips: dependencies.trips))
    }
    .environment(Router())
    .environment(Session(service: dependencies.authentication))
    .environment(\.locale, Locale(identifier: "en"))
}
