import SwiftUI

/// A labelled `−` value `+` row.
///
/// The circles are 34pt drawn but 44pt tappable: the designed size is what the row
/// needs to sit comfortably beside a value, and the hit area is what a thumb needs.
/// Repeatedly nudging a number is the most common interaction in the interview, so it
/// is also the one least forgivable to make fiddly.
struct StepperControl: View {
    let title: LocalizedStringKey
    /// The current value, already formatted and localized.
    let value: String
    var range: ClosedRange<Int> = 0...99
    @Binding var count: Int

    var body: some View {
        HStack(spacing: Theme.S.s3) {
            Text(title)
                .viharaText(Theme.Plan.F.meta)
                .foregroundStyle(Theme.C.textMuted)

            Spacer(minLength: Theme.S.s2)

            Text(value)
                .viharaText(Theme.F.cardTitle)
                .foregroundStyle(Theme.C.text)
                .monospacedDigit()
                .animation(nil, value: count)

            HStack(spacing: Theme.S.s2) {
                circle("minus", label: "interview.decrease", enabled: count > range.lowerBound) {
                    count = max(range.lowerBound, count - 1)
                }
                circle("plus", label: "interview.increase", enabled: count < range.upperBound) {
                    count = min(range.upperBound, count + 1)
                }
            }
        }
        .frame(minHeight: Theme.S.tapTarget)
    }

    private func circle(_ symbol: String,
                        label: LocalizedStringKey,
                        enabled: Bool,
                        action: @escaping () -> Void) -> some View {
        Button {
            Haptics.pickUp()
            action()
        } label: {
            Image(systemName: symbol)
                .viharaText(Theme.F.stepperGlyph)
                .foregroundStyle(enabled ? Theme.C.accentDeep : Theme.C.textFaint)
                .frame(width: Theme.Size.stepper, height: Theme.Size.stepper)
                .background {
                    Circle().strokeBorder(enabled ? Theme.C.accent : Theme.C.border,
                                          lineWidth: Theme.Size.hairline)
                }
                .viharaHitTarget()
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}

/// A row of mutually exclusive chips — a start time, a unit, a navigation app.
///
/// Not a `Picker(.segmented)`: that control is sans-serif and cannot be told
/// otherwise, and the type rule covers chrome as well as content.
struct SegmentedChips<Value: Hashable>: View {
    let title: LocalizedStringKey?
    let options: [Option]
    @Binding var selection: Value

    struct Option: Identifiable {
        let id: String
        let value: Value
        /// Already localized and formatted — these are often times or numbers.
        let label: String

        init(id: String, value: Value, label: String) {
            self.id = id
            self.value = value
            self.label = label
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.S.s2) {
            if let title {
                Text(title)
                    .viharaText(Theme.Plan.F.meta)
                    .foregroundStyle(Theme.C.textMuted)
            }

            FlowLayout(spacing: Theme.S.s2, lineSpacing: Theme.S.s2) {
                ForEach(options) { option in
                    let isSelected = option.value == selection
                    Button {
                        Haptics.pickUp()
                        selection = option.value
                    } label: {
                        Text(option.label)
                            .viharaText(Theme.F.chip)
                            .monospacedDigit()
                            .foregroundStyle(isSelected ? Theme.C.surface : Theme.C.text)
                            .padding(.horizontal, Theme.S.s4)
                            .padding(.vertical, Theme.S.s2)
                            .frame(minHeight: Theme.S.tapTarget)
                            .background {
                                let shape = RoundedRectangle(cornerRadius: Theme.R.pill,
                                                             style: .continuous)
                                if isSelected {
                                    shape.fill(Theme.C.text)
                                } else {
                                    shape.strokeBorder(Theme.C.border,
                                                       lineWidth: Theme.Size.hairline)
                                }
                            }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                }
            }
        }
        .animation(Theme.Motion.tab, value: selection)
    }
}

/// A slider in the app's accent, with its current value spelled out above it.
///
/// The value is written in words rather than left to the thumb's position, because
/// "how far will you walk" is a question about minutes, and a thumb two-thirds along
/// a track does not answer it.
struct AccentSlider: View {
    let title: LocalizedStringKey
    /// The current value, already formatted and localized.
    let value: String
    let range: ClosedRange<Double>
    var step: Double = 1
    @Binding var amount: Double

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.S.s1) {
            HStack {
                Text(title)
                    .viharaText(Theme.Plan.F.meta)
                    .foregroundStyle(Theme.C.textMuted)
                Spacer(minLength: Theme.S.s2)
                Text(value)
                    .viharaText(Theme.F.cardTitle)
                    .foregroundStyle(Theme.C.text)
                    .monospacedDigit()
            }

            Slider(value: $amount, in: range, step: step) {
                Text(title)
            } onEditingChanged: { editing in
                if !editing { Haptics.release() }
            }
            .tint(Theme.C.accent)
            .frame(minHeight: Theme.S.tapTarget)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("Controls · Deutsch") {
    @Previewable @State var adults = 2
    @Previewable @State var start = 9
    @Previewable @State var walking = 25.0

    return VStack(alignment: .leading, spacing: Theme.S.s5) {
        StepperControl(title: "party.adults", value: "2", range: 1...9, count: $adults)
        SegmentedChips(title: "interview.control.startTime",
                       options: [8, 9, 10, 11].map { .init(id: "\($0)", value: $0, label: "\($0):00") },
                       selection: $start)
        AccentSlider(title: "interview.control.walking",
                     value: "25 Min.",
                     range: 10...60,
                     step: 5,
                     amount: $walking)
    }
    .padding(Theme.S.screen)
    .frame(maxHeight: .infinity, alignment: .top)
    .background(Theme.C.bg)
    .environment(\.locale, Locale(identifier: "de"))
}

#Preview("Controls · English") {
    @Previewable @State var children = 1
    @Previewable @State var walking = 40.0

    return VStack(alignment: .leading, spacing: Theme.S.s5) {
        StepperControl(title: "party.children", value: "1", range: 0...6, count: $children)
        AccentSlider(title: "interview.control.walking",
                     value: "40 min",
                     range: 10...60,
                     step: 5,
                     amount: $walking)
    }
    .padding(Theme.S.screen)
    .frame(maxHeight: .infinity, alignment: .top)
    .background(Theme.C.bg)
    .environment(\.locale, Locale(identifier: "en"))
}
