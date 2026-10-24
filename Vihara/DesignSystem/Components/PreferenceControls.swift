import SwiftUI

/// A number you type.
///
/// A count is not an enumeration. Cycling a chip to reach "3 children" costs three
/// taps and gives no way back, and it cannot express a number nobody anticipated —
/// so this is a field with a keypad, and the steppers beside it are the shortcut
/// rather than the only way in.
struct NumberField: View {
    let caption: LocalizedStringKey
    /// Shown when nothing has been typed. The value it suggests is not applied —
    /// an unanswered question stays unanswered.
    let placeholder: String
    let range: ClosedRange<Int>
    @Binding var text: String

    @FocusState private var isFocused: Bool

    private var value: Int? { Int(text.trimmingCharacters(in: .whitespaces)) }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.S.s1) {
            Text(caption)
                .viharaText(Theme.F.fieldLabel)
                .foregroundStyle(isFocused ? Theme.C.accentDeep : Theme.C.textFaint)

            HStack(spacing: Theme.S.s2) {
                ZStack(alignment: .leading) {
                    if text.isEmpty {
                        Text(placeholder)
                            .viharaText(Theme.F.field)
                            .foregroundStyle(Theme.C.textFaint)
                            .allowsHitTesting(false)
                    }
                    TextField("", text: $text)
                        .viharaText(Theme.F.field)
                        .foregroundStyle(Theme.C.text)
                        .tint(Theme.C.accent)
                        .keyboardType(.numberPad)
                        .monospacedDigit()
                        .focused($isFocused)
                        // Clamp when the keypad goes away rather than while typing:
                        // rewriting the field under the finger makes "12" impossible
                        // to type when the ceiling is 9.
                        .onChange(of: isFocused) { _, focused in
                            if !focused { clamp() }
                        }
                }

                Spacer(minLength: 0)

                step(symbol: "minus", enabled: (value ?? range.lowerBound) > range.lowerBound) {
                    set((value ?? range.lowerBound) - 1)
                }
                step(symbol: "plus", enabled: (value ?? range.lowerBound - 1) < range.upperBound) {
                    set(value.map { $0 + 1 } ?? range.lowerBound)
                }
            }
        }
        .padding(.horizontal, Theme.S.s3)
        .padding(.vertical, Theme.S.s2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: Theme.R.control, style: .continuous)
                .fill(Theme.C.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.R.control, style: .continuous)
                        .strokeBorder(isFocused ? Theme.C.accent : Theme.C.border,
                                      lineWidth: isFocused ? Theme.Size.selectedBorder
                                                           : Theme.Size.hairline)
                }
        }
        .animation(Theme.Motion.tab, value: isFocused)
    }

    private func step(symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.pickUp()
            action()
        } label: {
            Image(systemName: symbol)
                .viharaText(Theme.F.rating)
                .foregroundStyle(enabled ? Theme.C.accentDeep : Theme.C.textFaint)
                .frame(width: Theme.Size.miniStepper, height: Theme.Size.miniStepper)
                .background { Circle().strokeBorder(Theme.C.border, lineWidth: Theme.Size.hairline) }
                .viharaInlineHitTarget()
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func set(_ candidate: Int) {
        text = String(min(range.upperBound, max(range.lowerBound, candidate)))
    }

    private func clamp() {
        guard !text.isEmpty else { return }
        guard let value else { text = ""; return }
        set(value)
    }
}

/// A choice you pick, not one you cycle to.
///
/// A menu costs one tap to open and one to answer, whatever the answer is. Cycling
/// cost as many taps as the value's position in a list nobody could see, which is
/// fine for two options and wrong for anything more.
struct MenuChip<Value: Hashable>: View {
    let caption: LocalizedStringKey
    /// Already localized — these are labels, not keys, because most come from the
    /// domain's own display extensions.
    let options: [Option]
    /// Shown while the question is unanswered.
    let unsetLabel: String
    @Binding var selection: Value?

    struct Option: Identifiable {
        let id: String
        let value: Value
        let label: String

        init(id: String, value: Value, label: String) {
            self.id = id
            self.value = value
            self.label = label
        }
    }

    private var isUnset: Bool { selection == nil }

    var body: some View {
        Menu {
            ForEach(options) { option in
                Button {
                    selection = option.value
                    Haptics.pickUp()
                } label: {
                    if option.value == selection {
                        Label { Text(option.label) } icon: { Image(systemName: "checkmark") }
                    } else {
                        Text(option.label)
                    }
                }
            }

            if !isUnset {
                Divider()
                // A question can be un-answered again. Cycling offered this only by
                // going all the way round.
                Button(role: .destructive) {
                    selection = nil
                } label: {
                    Text(unsetLabel)
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: Theme.S.s05) {
                Text(caption)
                    .viharaText(Theme.F.fieldLabel)
                    .foregroundStyle(Theme.C.textFaint)

                HStack(spacing: Theme.S.s1) {
                    Text(selection.flatMap { value in
                        options.first { $0.value == value }?.label
                    } ?? unsetLabel)
                        .viharaText(Theme.F.chip)
                        .foregroundStyle(isUnset ? Theme.C.textFaint : Theme.C.text)
                    Image(systemName: "chevron.down")
                        .viharaText(Theme.Plan.F.blockLabel)
                        .foregroundStyle(Theme.C.textFaint)
                }
            }
            .padding(.horizontal, Theme.S.s3)
            .padding(.vertical, Theme.S.s2)
            .frame(minHeight: Theme.S.tapTarget, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Theme.R.control, style: .continuous)
                    .fill(Theme.C.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.R.control, style: .continuous)
                            .strokeBorder(isUnset ? Theme.C.accent : Theme.C.border,
                                          lineWidth: Theme.Size.hairline)
                    }
            }
            .contentShape(Rectangle())
        }
        .menuOrder(.fixed)
        .accessibilityLabel(caption)
    }
}

#Preview("Preference controls") {
    @Previewable @State var adults = "2"
    @Previewable @State var children = ""
    @Previewable @State var pick: String? = nil

    // A local enum stands in for a domain value: the design system draws these
    // controls and must not know what they are choosing between.
    let options: [MenuChip<String>.Option] = [
        .init(id: "relaxed", value: "relaxed", label: "Entspannt"),
        .init(id: "balanced", value: "balanced", label: "Ausgewogen"),
        .init(id: "packed", value: "packed", label: "Viel sehen"),
    ]

    return VStack(alignment: .leading, spacing: Theme.S.s3) {
        HStack(spacing: Theme.S.s3) {
            NumberField(caption: "party.adults", placeholder: "2", range: 1...9, text: $adults)
            NumberField(caption: "party.children", placeholder: "0", range: 0...6, text: $children)
        }

        MenuChip(caption: "slot.pace",
                 options: options,
                 unsetLabel: "Noch offen",
                 selection: $pick)
    }
    .padding(Theme.S.screen)
    .frame(maxHeight: .infinity, alignment: .top)
    .background(Theme.C.bg)
    .environment(\.locale, Locale(identifier: "de"))
}
