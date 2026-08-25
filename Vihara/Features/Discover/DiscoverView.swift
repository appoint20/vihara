import SwiftUI

/// Screen 2 — Discover Home surface with destination rails, centered city search,
/// and the Wanderlog-style Trip Planner interview intake section under the cards.
struct DiscoverView: View {
    @Environment(Router.self) private var router
    @State private var model: DiscoverViewModel
    @State private var savedTrips: SavedTripsViewModel
    @State private var selectedNav = 0
    @FocusState private var isSearchFocused: Bool

    /// Two items, because two screens exist.
    ///
    /// This was four — "Merkliste" and "Profil" had no feature behind them and no
    /// destination wired to them, so three of the four tabs did nothing. Inert
    /// primary navigation reads as a broken app and is a routine App Review
    /// rejection. The roadmap already asks whether Merkliste is a real feature; until
    /// somebody answers, the navigation shows what the app can actually do.
    private let navItems = ["Entdecken", "Meine Reisen"]

    init(model: DiscoverViewModel, savedTrips: SavedTripsViewModel) {
        _model = State(wrappedValue: model)
        _savedTrips = State(wrappedValue: savedTrips)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if selectedNav == 0 {
                    header
                    categoryTabs
                    destinationRail
                    sectionHead
                    compactRail
                    plannerSearchSection
                } else {
                    SavedTripsView(model: savedTrips)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, Theme.S.s8 + Theme.S.navBottom + Theme.S.tapTarget)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.C.bg.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BottomNav(items: navItems, selected: $selectedNav)
                .padding(.horizontal, Theme.S.screen)
                .padding(.bottom, Theme.S.navBottom)
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await model.load() }
        .sheet(isPresented: $model.isInterviewPresented) {
            TripPlannerInterviewView(
                model: TripPlannerInterviewViewModel(
                    catalogue: model.catalogue,
                    preselectedDestination: model.interviewTargetDestination,
                    initialCity: model.interviewTargetCity
                )
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: Theme.S.s1) {
                Text("Guten Morgen, Sanya")
                    .viharaText(Theme.F.small)
                    .foregroundStyle(Theme.C.textMuted)
                Text("Entdecken")
                    .viharaText(Theme.F.h2)
                    .foregroundStyle(Theme.C.text)
            }

            Spacer(minLength: Theme.S.s3)

            HStack(spacing: Theme.S.s1) {
                circleButton("Su", label: "Reise planen", showsDot: false) {
                    model.launchInterview()
                }
                circleButton("Ne", label: "Neuigkeiten", showsDot: true, action: nil)
            }
        }
        .padding(.horizontal, Theme.S.screen)
        .padding(.top, Theme.S.s2)
    }

    private func circleButton(_ glyph: String,
                              label: String,
                              showsDot: Bool,
                              action: (() -> Void)?) -> some View {
        Button {
            action?()
        } label: {
            Text(glyph)
                .viharaText(Theme.F.glyph)
                .foregroundStyle(Theme.C.text)
                .frame(width: Theme.Size.headerButton, height: Theme.Size.headerButton)
                .overlay {
                    Circle().strokeBorder(Theme.C.border, lineWidth: Theme.Size.hairline)
                }
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(Theme.C.price)
                        .frame(width: Theme.Size.headerDot, height: Theme.Size.headerDot)
                        .opacity(showsDot ? 1 : 0)
                }
                .viharaHitTarget()
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
        .accessibilityLabel(label)
    }

    // MARK: - Category tabs

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.S.s6) {
                ForEach(DestinationCategory.allCases) { category in
                    let isActive = category == model.selectedCategory
                    Button {
                        Task {
                            withAnimation(Theme.Motion.tab) {}
                            await model.select(category)
                        }
                    } label: {
                        VStack(spacing: Theme.S.s2) {
                            Text(category.label)
                                .viharaText(isActive ? Theme.F.tabActive : Theme.F.tabInactive)
                                .foregroundStyle(isActive ? Theme.C.text : Theme.C.textFaint)

                            RoundedRectangle(cornerRadius: Theme.R.pill, style: .continuous)
                                .fill(Theme.C.text)
                                .frame(width: Theme.Size.tabUnderline.width,
                                       height: Theme.Size.tabUnderline.height)
                                .opacity(isActive ? 1 : 0)
                        }
                        .viharaHitTarget()
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isActive ? [.isSelected] : [])
                }
            }
            .padding(.horizontal, Theme.S.screen)
        }
        .padding(.top, Theme.S.s5)
        .animation(Theme.Motion.tab, value: model.selectedCategory)
    }

    // MARK: - Rails

    @ViewBuilder
    private var destinationRail: some View {
        if model.featuredIsEmpty {
            Text("Für \(model.selectedCategory.label) haben wir noch keine geprüfte Region. Wir kuratieren gerade.")
                .viharaText(Theme.F.small)
                .foregroundStyle(Theme.C.textMuted)
                .fixedSize(horizontal: false, vertical: true)
                .frame(height: Theme.Size.destCard.height, alignment: .top)
                .padding(.horizontal, Theme.S.screen)
                .padding(.top, Theme.S.s5)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.S.rail) {
                    ForEach(model.featured) { destination in
                        Button {
                            model.launchInterview(destination: destination)
                        } label: {
                            DestinationCard(image: destination.imageSlug,
                                            title: destination.name,
                                            subtitle: destination.region,
                                            rating: destination.formattedRating)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Reise nach \(destination.name) planen")
                    }
                }
                .padding(.horizontal, Theme.S.screen)
            }
            .padding(.top, Theme.S.s5)
        }
    }

    private var sectionHead: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Beliebt gerade")
                .viharaText(Theme.F.h3)
                .foregroundStyle(Theme.C.text)

            Spacer(minLength: Theme.S.s3)

            Button {
                model.launchInterview()
            } label: {
                Text("Alle ansehen")
                    .viharaText(Theme.F.small)
                    .foregroundStyle(Theme.C.accentDeep)
                    .viharaInlineHitTarget()
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.S.screen)
        .padding(.top, Theme.S.sectionTop)
    }

    private var compactRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: Theme.S.rail) {
                ForEach(model.popular) { destination in
                    Button {
                        model.launchInterview(destination: destination)
                    } label: {
                        CompactCard(image: destination.imageSlug,
                                    title: destination.name,
                                    subtitle: destination.suggestedLengthLabel)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.S.screen)
            .padding(.vertical, Theme.S.s1)
        }
        .padding(.top, Theme.S.s4)
    }

    // MARK: - Center City Search & Trip Planner Interview Section

    private var plannerSearchSection: some View {
        VStack(alignment: .leading, spacing: Theme.S.s3) {
            HStack(alignment: .firstTextBaseline) {
                Text("Reiseziel suchen & planen")
                    .viharaText(Theme.F.h3)
                    .foregroundStyle(Theme.C.text)

                Spacer()

                Text("Wanderlog-Modus")
                    .viharaText(Theme.Plan.F.blockLabel)
                    .foregroundStyle(Theme.C.accentDeep)
            }
            .padding(.horizontal, Theme.S.screen)
            .padding(.top, Theme.S.sectionTop)

            // Centered Search Field
            VStack(spacing: Theme.S.s2) {
                CitySearchField(text: $model.searchQuery,
                                placeholder: "Stadt oder Region suchen (z.B. Bologna)",
                                isFocused: $isSearchFocused) {
                    Task { await model.updateSearch(query: model.searchQuery) }
                } onClear: {
                    model.clearSearch()
                }
                .onChange(of: model.searchQuery) { _, newValue in
                    Task { await model.updateSearch(query: newValue) }
                }

                // Autocomplete Dropdown List if searching
                if model.isSearching && !model.searchResults.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(model.searchResults) { dest in
                            Button {
                                isSearchFocused = false
                                model.launchInterview(destination: dest)
                            } label: {
                                HStack(spacing: Theme.S.s3) {
                                    Image(systemName: "mappin.and.ellipse")
                                        .foregroundStyle(Theme.C.accent)
                                        .frame(width: 20)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(dest.name)
                                            .viharaText(Theme.F.compactTitle)
                                            .foregroundStyle(Theme.C.text)

                                        Text(dest.region)
                                            .viharaText(Theme.Plan.F.meta)
                                            .foregroundStyle(Theme.C.textMuted)
                                    }

                                    Spacer()

                                    Text("Planen")
                                        .viharaText(Theme.Plan.F.meta)
                                        .foregroundStyle(Theme.C.accentDeep)
                                }
                                .padding(.horizontal, Theme.S.s3)
                                .padding(.vertical, Theme.S.s2 + 2)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if dest.id != model.searchResults.last?.id {
                                Divider()
                                    .padding(.leading, Theme.S.s7)
                            }
                        }
                    }
                    .background {
                        RoundedRectangle(cornerRadius: Theme.R.card, style: .continuous)
                            .fill(Theme.C.surface)
                            .overlay {
                                RoundedRectangle(cornerRadius: Theme.R.card, style: .continuous)
                                    .strokeBorder(Theme.C.border, lineWidth: Theme.Size.hairline)
                            }
                            .viharaShadow(Theme.Shadow.card)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Quick City Suggestion Chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.S.s2) {
                        ForEach(model.popular) { dest in
                            Button {
                                model.launchInterview(destination: dest)
                            } label: {
                                HStack(spacing: Theme.S.s1) {
                                    Image(systemName: "sparkles")
                                        .viharaText(Theme.Plan.F.meta)
                                        .foregroundStyle(Theme.C.accentDeep)

                                    Text(dest.name)
                                        .viharaText(Theme.Plan.F.meta)
                                        .foregroundStyle(Theme.C.text)
                                }
                                .padding(.horizontal, Theme.S.s3)
                                .padding(.vertical, Theme.S.s2)
                                .background {
                                    RoundedRectangle(cornerRadius: Theme.R.pill, style: .continuous)
                                        .fill(Theme.C.surface)
                                        .overlay {
                                            RoundedRectangle(cornerRadius: Theme.R.pill, style: .continuous)
                                                .strokeBorder(Theme.C.border, lineWidth: Theme.Size.hairline)
                                        }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.top, Theme.S.s1)

                // Interview Launch CTA Card
                Button {
                    model.launchInterview()
                } label: {
                    HStack(spacing: Theme.S.s3) {
                        VStack(alignment: .leading, spacing: Theme.S.s05) {
                            Text("✨ Geführten Trip-Planer starten")
                                .viharaText(Theme.F.compactTitle)
                                .foregroundStyle(Theme.C.text)

                            Text("In 4 schnellen Schritten Ziel, Dauer, Budget und Stil wählen.")
                                .viharaText(Theme.Plan.F.meta)
                                .foregroundStyle(Theme.C.textMuted)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .viharaText(Theme.F.glyph)
                            .foregroundStyle(Theme.C.accentDeep)
                    }
                    .padding(Theme.S.s4)
                    .background {
                        RoundedRectangle(cornerRadius: Theme.R.card, style: .continuous)
                            .fill(Theme.C.surface)
                            .overlay {
                                RoundedRectangle(cornerRadius: Theme.R.card, style: .continuous)
                                    .strokeBorder(Theme.C.accent.opacity(0.35), lineWidth: 1)
                            }
                            .viharaShadow(Theme.Shadow.card)
                    }
                }
                .buttonStyle(.plain)
                .padding(.top, Theme.S.s2)
            }
            .padding(.horizontal, Theme.S.screen)
        }
    }
}

#Preview {
    let dependencies = AppDependencies.stubbed()
    return NavigationStack {
        DiscoverView(model: DiscoverViewModel(catalogue: dependencies.destinations),
                     savedTrips: SavedTripsViewModel(trips: dependencies.trips))
    }
    .environment(Router())
}
