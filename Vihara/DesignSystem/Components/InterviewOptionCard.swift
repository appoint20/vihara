import SwiftUI

/// A choice in the interview, which becomes a control once it is chosen.
///
/// The card is the whole interaction, not a radio button with a panel underneath: the
/// options stay in place, and the selected one grows to hold whatever adjusts it.
/// Nothing jumps, and the traveller never loses the row they just tapped.
///
/// This is what makes the last card of every step — "Eigene Werte" — work. A preset
/// answers the question with a bucket; selecting the custom card opens the same card
/// into steppers, chips and sliders so the traveller can answer it exactly. Both are
/// the same control in two states, so choosing precision is not a different screen.
///
/// The `footnote` is the reason the expansion is worth having: it says what the
/// numbers currently produce ("Ergibt 12 Bausteine über 4 Tage"), so an adjustment
/// has a visible consequence rather than being a dial with no readout.
struct InterviewOptionCard<Expanded: View>: View {
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey? = nil
    var iconName: String? = nil
    let isSelected: Bool
    /// What this choice produces, already formatted and localized. Shown inside the
    /// expansion, accent-tinted — it is the planner showing its working, not a
    /// warning.
    var footnote: String? = nil
    let action: () -> Void
    @ViewBuilder var expanded: Expanded

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: action) {
                header
            }
            .buttonStyle(.plain)

            if isSelected, hasExpansion {
                VStack(alignment: .leading, spacing: Theme.S.s4) {
                    Divider().background(Theme.C.border)
                    expanded
                    if let footnote {
                        NotePanel {
                            Text(footnote)
                                .viharaText(Theme.Plan.F.meta)
                                .foregroundStyle(Theme.C.accentDeep)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.horizontal, Theme.S.s3)
                .padding(.bottom, Theme.S.s3)
                .transition(.opacity)
            }
        }
        .background {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(isSelected ? Theme.C.surface : Theme.C.surface.opacity(Theme.O.destInnerCard))
                .overlay {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(isSelected ? Theme.C.accent : Theme.C.border,
                                      lineWidth: isSelected ? Theme.Size.selectedBorder
                                                            : Theme.Size.hairline)
                }
        }
        .viharaShadow(isSelected ? Theme.Shadow.card : .none)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .animation(Theme.Plan.Motion.standard, value: isSelected)
    }

    private var header: some View {
        HStack(spacing: Theme.S.s3) {
            if let iconName {
                Image(systemName: iconName)
                    .viharaText(Theme.F.glyph)
                    .foregroundStyle(isSelected ? Theme.C.accentDeep : Theme.C.textMuted)
                    .frame(width: Theme.Size.optionIcon, height: Theme.Size.optionIcon)
            }

            VStack(alignment: .leading, spacing: Theme.S.s05) {
                Text(title)
                    .viharaText(Theme.F.compactTitle)
                    .foregroundStyle(Theme.C.text)

                if let subtitle {
                    Text(subtitle)
                        .viharaText(Theme.Plan.F.meta)
                        .foregroundStyle(isSelected ? Theme.C.accentDeep : Theme.C.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)

            Circle()
                .strokeBorder(isSelected ? Theme.C.accent : Theme.C.border,
                              lineWidth: isSelected ? Theme.S.s1 : Theme.Size.hairline)
                .frame(width: Theme.Size.radioDot, height: Theme.Size.radioDot)
        }
        .padding(Theme.S.s3)
        .frame(maxWidth: .infinity, minHeight: Theme.S.tapTarget, alignment: .leading)
        .contentShape(Rectangle())
    }

    /// An expanded card is taller and squarer-shouldered; `compactCard` reads tight
    /// once there are controls inside it.
    private var radius: CGFloat {
        isSelected && hasExpansion ? Theme.R.expandedCard : Theme.R.compactCard
    }

    private var hasExpansion: Bool { Expanded.self != EmptyView.self }
}

extension InterviewOptionCard where Expanded == EmptyView {
    /// A plain choice, with nothing to adjust.
    init(title: LocalizedStringKey,
         subtitle: LocalizedStringKey? = nil,
         iconName: String? = nil,
         isSelected: Bool,
         action: @escaping () -> Void) {
        self.init(title: title,
                  subtitle: subtitle,
                  iconName: iconName,
                  isSelected: isSelected,
                  footnote: nil,
                  action: action,
                  expanded: { EmptyView() })
    }
}

extension Theme.ShadowSpec {
    /// No shadow, spelled out so a call site can pick between two shadows rather than
    /// between a shadow and a conditional modifier.
    static let none = Theme.ShadowSpec(color: .clear, radius: 0, y: 0)
}

#Preview("Option cards · Deutsch") {
    @Previewable @State var selection = 1
    @Previewable @State var perBlock = 2
    @Previewable @State var walking = 25.0
    @Previewable @State var start = 9

    return ScrollView {
        VStack(spacing: Theme.S.s3) {
            InterviewOptionCard(title: "pace.relaxed",
                                subtitle: "pace.relaxed.detail",
                                iconName: "cup.and.saucer",
                                isSelected: selection == 0) { selection = 0 }

            InterviewOptionCard(title: "pace.balanced",
                                subtitle: "pace.balanced.detail",
                                iconName: "figure.walk",
                                isSelected: selection == 1) { selection = 1 }

            InterviewOptionCard(title: "interview.custom",
                                subtitle: "interview.custom.subtitle",
                                iconName: "slider.horizontal.3",
                                isSelected: selection == 2,
                                footnote: "Ergibt 12 Bausteine über 4 Tage, rund 25 Min. zu Fuß pro Halbtag.",
                                action: { selection = 2 }) {
                StepperControl(title: "interview.control.perBlock",
                               value: "\(perBlock)",
                               range: 1...3,
                               count: $perBlock)
                SegmentedChips(title: "interview.control.startTime",
                               options: [8, 9, 10, 11].map { .init(id: "\($0)", value: $0, label: "\($0):00") },
                               selection: $start)
                AccentSlider(title: "interview.control.walking",
                             value: "\(Int(walking)) Min.",
                             range: 10...60,
                             step: 5,
                             amount: $walking)
            }
        }
        .padding(Theme.S.screen)
    }
    .background(Theme.C.bg)
    .environment(\.locale, Locale(identifier: "de"))
}

#Preview("Option cards · English") {
    @Previewable @State var selection = 2
    @Previewable @State var perBlock = 3

    return ScrollView {
        VStack(spacing: Theme.S.s3) {
            InterviewOptionCard(title: "pace.packed",
                                subtitle: "pace.packed.detail",
                                iconName: "bolt",
                                isSelected: selection == 0) { selection = 0 }

            InterviewOptionCard(title: "interview.custom",
                                subtitle: "interview.custom.subtitle",
                                iconName: "slider.horizontal.3",
                                isSelected: selection == 2,
                                footnote: "Makes 18 building blocks across 4 days.",
                                action: { selection = 2 }) {
                StepperControl(title: "interview.control.perBlock",
                               value: "\(perBlock)",
                               range: 1...3,
                               count: $perBlock)
            }
        }
        .padding(Theme.S.screen)
    }
    .background(Theme.C.bg)
    .environment(\.locale, Locale(identifier: "en"))
}
