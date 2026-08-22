import SwiftUI

/// Screen 2 — a fixed vertical layout on the paper ground. The page itself does not
/// scroll; only the two horizontal rails do.
struct DiscoverView: View {
    @State private var selectedCategory = 0
    @State private var selectedNav = 0

    private let categories = ["Kulinarik", "Küste", "Berge", "Städte", "Natur"]
    private let navItems = ["Entdecken", "Meine Reisen", "Merkliste", "Profil"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            categoryTabs
            destinationRail
            sectionHead
            compactRail
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.C.bg.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BottomNav(items: navItems, selected: $selectedNav)
                .padding(.horizontal, Theme.S.screen)
                .padding(.bottom, Theme.S.navBottom)
        }
        .toolbar(.hidden, for: .navigationBar)
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
                circleButton("Su", label: "Suche", showsDot: false)
                circleButton("Ne", label: "Neuigkeiten", showsDot: true)
            }
        }
        .padding(.horizontal, Theme.S.screen)
        .padding(.top, Theme.S.s2)
    }

    private func circleButton(_ glyph: String, label: String, showsDot: Bool) -> some View {
        Button {
            // Prototype: no destination behind these yet.
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
        .accessibilityLabel(label)
    }

    // MARK: - Category tabs

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.S.s6) {
                ForEach(categories.indices, id: \.self) { index in
                    let isActive = index == selectedCategory
                    Button {
                        withAnimation(Theme.Motion.tab) { selectedCategory = index }
                    } label: {
                        VStack(spacing: Theme.S.s2) {
                            Text(categories[index])
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
    }

    // MARK: - Rails

    private var destinationRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.S.rail) {
                DestinationCard(image: "dest_bologna",
                                title: "Bologna",
                                subtitle: "Emilia-Romagna, Italien",
                                rating: "4,8")
                DestinationCard(image: "dest_sansebastian",
                                title: "San Sebastián",
                                subtitle: "Baskenland, Spanien",
                                rating: "4,7")
            }
            .padding(.horizontal, Theme.S.screen)
        }
        .padding(.top, Theme.S.s5)
    }

    private var sectionHead: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Beliebt gerade")
                .viharaText(Theme.F.h3)
                .foregroundStyle(Theme.C.text)

            Spacer(minLength: Theme.S.s3)

            Button {
                // Prototype: no destination behind this yet.
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
                CompactCard(image: "top_modena", title: "Modena", subtitle: "2 Tage")
                CompactCard(image: "top_ravenna", title: "Ravenna", subtitle: "2 Tage")
            }
            .padding(.horizontal, Theme.S.screen)
            // Room for the card shadow, which the scroll view would otherwise clip.
            .padding(.vertical, Theme.S.s1)
        }
        .padding(.top, Theme.S.s4)
    }
}

#Preview {
    NavigationStack {
        DiscoverView()
    }
}
