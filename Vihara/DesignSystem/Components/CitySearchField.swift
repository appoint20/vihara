import SwiftUI

/// A dedicated search input field for city and destination querying.
///
/// Designed to sit in the center of the Discover surface under the destination cards,
/// honoring Vihara's editorial serif typography and dynamic color tokens.
struct CitySearchField: View {
    @Binding var text: String
    var placeholder: String = "Wohin möchtest du reisen?"
    var isFocused: FocusState<Bool>.Binding?
    var onCommit: (() -> Void)? = nil
    var onClear: (() -> Void)? = nil

    @FocusState private var internalFocus: Bool

    private var focusedBinding: FocusState<Bool>.Binding {
        isFocused ?? $internalFocus
    }

    var body: some View {
        HStack(spacing: Theme.S.s3) {
            Image(systemName: "magnifyingglass")
                .viharaText(Theme.F.glyph)
                .foregroundStyle(focusedBinding.wrappedValue ? Theme.C.accent : Theme.C.textFaint)

            TextField(placeholder, text: $text)
                .viharaText(Theme.F.body)
                .foregroundStyle(Theme.C.text)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
                .focused(focusedBinding)
                .onSubmit {
                    onCommit?()
                }

            if !text.isEmpty {
                Button {
                    text = ""
                    onClear?()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .viharaText(Theme.F.small)
                        .foregroundStyle(Theme.C.textFaint)
                        .frame(width: Theme.S.tapTarget, height: Theme.S.tapTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Suche löschen")
            }
        }
        .padding(.horizontal, Theme.S.s4)
        .padding(.vertical, Theme.S.s3)
        .background {
            RoundedRectangle(cornerRadius: Theme.R.card, style: .continuous)
                .fill(Theme.C.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.R.card, style: .continuous)
                        .strokeBorder(focusedBinding.wrappedValue ? Theme.C.accent : Theme.C.border,
                                      lineWidth: focusedBinding.wrappedValue ? 1.5 : Theme.Size.hairline)
                }
                .viharaShadow(Theme.Shadow.card)
        }
        .animation(.snappy(duration: 0.2), value: focusedBinding.wrappedValue)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var query = ""
        var body: some View {
            VStack(spacing: Theme.S.s5) {
                CitySearchField(text: $query)
                CitySearchField(text: .constant("Bologna"))
            }
            .padding(Theme.S.screen)
            .background(Theme.C.bg)
        }
    }
    return PreviewWrapper()
}
