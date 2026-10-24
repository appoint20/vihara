import SwiftUI
import AuthenticationServices

/// The gate. Nothing past the Welcome screen is reachable without coming through it.
///
/// Paper, and the app's own tokens — the Summer Sky island and its dark slate card
/// are gone. Teal appears only where something is interactive, magenta only where
/// something is wrong, and the type is the serif/sans pair every other screen uses.
///
/// The fields are one white list with dividers rather than four separate boxes: they
/// are one credential, and four outlined rectangles read as four unrelated questions.
/// The providers sit under a rule as two quiet tiles, so email stays the default way
/// in rather than competing with them.
///
/// There is no way back. The Welcome screen is a title card, not a destination.
struct AuthView: View {
    @Environment(Router.self) private var router
    @Environment(Session.self) private var session
    @Environment(\.locale) private var locale

    @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.deviceDefault

    @State private var model: SignInViewModel
    @State private var isForgotPasswordPresented = false
    /// Holds the Apple request for its lifetime — see ``AppleSignInController``.
    @State private var apple = AppleSignInController()
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case name, email, password, confirm }

    init(model: SignInViewModel) {
        _model = State(wrappedValue: model)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                topRow
                title
                modeSwitch
                credentialList
                helper
                errorLine
                submit
                providers
                terms
            }
            .padding(Theme.S.screen)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.C.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        // The swipe has to agree with the missing button, or the gate only holds for
        // people who do not swipe.
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $isForgotPasswordPresented) {
            ForgotPasswordSheet()
        }
    }

    // MARK: - Head

    private var topRow: some View {
        HStack {
            Text(verbatim: "Vihara")
                .viharaText(Theme.F.brand)
                .foregroundStyle(Theme.C.textMuted)

            Spacer()

            // The language switch belongs here as well as in Settings: this is the
            // first screen anybody sees, and the one place they cannot yet reach
            // Settings from.
            Button {
                withAnimation(Theme.Motion.tab) {
                    language = language == .german ? .english : .german
                }
            } label: {
                HStack(spacing: Theme.S.s1) {
                    Image(systemName: "globe")
                        .viharaText(Theme.F.rating)
                    Text(verbatim: language.rawValue.uppercased())
                        .viharaText(Theme.F.label)
                }
                .foregroundStyle(Theme.C.textMuted)
                .padding(.horizontal, Theme.S.s3)
                .frame(minHeight: Theme.S.tapTarget)
                .background {
                    Capsule(style: .continuous)
                        .strokeBorder(Theme.C.border, lineWidth: Theme.Size.hairline)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("settings.language"))
        }
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: Theme.S.s2) {
            Text(LocalizedStringKey(model.mode.titleKey))
                .viharaText(Theme.F.h2)
                .foregroundStyle(Theme.C.text)

            Text(LocalizedStringKey(model.mode == .signIn ? "auth.signIn.subtitle"
                                                          : "auth.register.subtitle"))
                .viharaText(Theme.F.body)
                .foregroundStyle(Theme.C.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, Theme.S.sectionTop)
        .padding(.bottom, Theme.S.s5)
    }

    /// A capsule with a white knob, not two grey tabs.
    ///
    /// One control that moves rather than two that compete — and the unselected side
    /// needs no colour of its own, which is what made the grey pair look like an
    /// error state.
    private var modeSwitch: some View {
        HStack(spacing: 0) {
            ForEach(SignInViewModel.Mode.allCases, id: \.self) { item in
                let isSelected = model.mode == item
                Button {
                    withAnimation(Theme.Motion.tab) { model.mode = item }
                } label: {
                    Text(LocalizedStringKey(item.tabKey))
                        .viharaText(isSelected ? Theme.F.tabActive : Theme.F.tabInactive)
                        .foregroundStyle(isSelected ? Theme.C.text : Theme.C.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.S.s2)
                        .background {
                            if isSelected {
                                Capsule(style: .continuous)
                                    .fill(Theme.C.surface)
                                    .viharaShadow(Theme.Shadow.card)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .padding(Theme.S.s05)
        .frame(minHeight: Theme.S.tapTarget)
        .background {
            Capsule(style: .continuous).fill(Theme.C.border.opacity(Theme.O.glassStroke))
        }
        .padding(.bottom, Theme.S.s5)
    }

    // MARK: - The credential

    /// One white list. Rows, dividers, no boxes.
    private var credentialList: some View {
        VStack(spacing: 0) {
            if model.mode == .register {
                row(label: "auth.field.name",
                    placeholder: "auth.field.name.placeholder",
                    text: $model.name,
                    focus: .name,
                    isSettled: model.isNameSettled)
                    .textContentType(.name)
                    .textInputAutocapitalization(.words)
                divider
            }

            row(label: "auth.field.email",
                placeholder: "auth.field.email.placeholder",
                text: $model.email,
                focus: .email,
                isSettled: model.isEmailSettled)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            divider

            row(label: "auth.field.password",
                placeholder: "auth.field.password.placeholder",
                text: $model.password,
                focus: .password,
                isSecure: true,
                trailing: .strength)
                .textContentType(model.mode == .register ? .newPassword : .password)

            if model.mode == .register {
                divider
                row(label: "auth.field.confirm",
                    placeholder: "auth.field.confirm.placeholder",
                    text: $model.confirmPassword,
                    focus: .confirm,
                    isSecure: true,
                    isSettled: model.isConfirmSettled,
                    isInvalid: model.showsPasswordMismatch)
                    .textContentType(.newPassword)
            }
        }
        .background {
            RoundedRectangle(cornerRadius: Theme.R.control, style: .continuous)
                .fill(Theme.C.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.R.control, style: .continuous)
                        .strokeBorder(Theme.C.border, lineWidth: Theme.Size.hairline)
                }
        }
        .animation(Theme.Plan.Motion.standard, value: model.mode)
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.C.border)
            .frame(height: Theme.Size.hairline)
            .padding(.leading, Theme.S.s4)
    }

    /// What sits at the end of a row.
    private enum RowTrailing { case tick, strength }

    /// A row: caption, value, and whatever the row has to say for itself.
    ///
    /// The placeholder is drawn rather than passed as a `prompt` — a
    /// `LocalizedStringKey` is parsed as markdown, and markdown autolinks a bare
    /// email address, so "max@mustermann.de" rendered as a blue mailto link and read
    /// as a filled-in value rather than a hint.
    @ViewBuilder
    private func row(label: LocalizedStringKey,
                     placeholder: String,
                     text: Binding<String>,
                     focus: Field,
                     isSecure: Bool = false,
                     isSettled: Bool = false,
                     isInvalid: Bool = false,
                     trailing: RowTrailing = .tick) -> some View {
        HStack(spacing: Theme.S.s3) {
            Text(label)
                .viharaText(Theme.F.fieldLabel)
                .foregroundStyle(focusedField == focus ? Theme.C.accentDeep : Theme.C.textFaint)
                .frame(width: Theme.Size.fieldLabel, alignment: .leading)

            ZStack(alignment: .leading) {
                if text.wrappedValue.isEmpty {
                    Text(localized(placeholder, locale: locale))
                        .viharaText(Theme.F.field)
                        .foregroundStyle(Theme.C.textFaint)
                        .allowsHitTesting(false)
                }

                Group {
                    if isSecure, !model.isPasswordVisible {
                        SecureField("", text: text)
                    } else {
                        TextField("", text: text)
                    }
                }
                .viharaText(Theme.F.field)
                .foregroundStyle(Theme.C.text)
                .tint(Theme.C.accent)
                .focused($focusedField, equals: focus)
            }

            rowAccessory(for: trailing,
                         isSettled: isSettled,
                         isInvalid: isInvalid)
        }
        .padding(.horizontal, Theme.S.s4)
        .frame(minHeight: Theme.S.tapTarget + Theme.S.s1)
        .background(alignment: .leading) {
            // A hairline of teal marks the row being typed in — cheaper than
            // outlining the whole row, and it does not make the list jump.
            if focusedField == focus {
                Rectangle()
                    .fill(Theme.C.accent)
                    .frame(width: Theme.Size.selectedBorder)
            }
        }
        .animation(Theme.Motion.tab, value: focusedField)
    }

    @ViewBuilder
    private func rowAccessory(for trailing: RowTrailing,
                              isSettled: Bool,
                              isInvalid: Bool) -> some View {
        switch trailing {
        case .strength:
            HStack(spacing: Theme.S.s3) {
                if model.mode == .register, !model.password.isEmpty {
                    strengthBars
                }
                Button {
                    model.isPasswordVisible.toggle()
                } label: {
                    Image(systemName: model.isPasswordVisible ? "eye.slash" : "eye")
                        .viharaText(Theme.F.glyph)
                        .foregroundStyle(Theme.C.textFaint)
                        .viharaInlineHitTarget()
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(model.isPasswordVisible ? "auth.password.hide"
                                                                 : "auth.password.show"))
            }

        case .tick:
            if isInvalid {
                Image(systemName: "exclamationmark.circle")
                    .viharaText(Theme.F.glyph)
                    .foregroundStyle(Theme.C.price)
            } else if isSettled {
                Image(systemName: "checkmark")
                    .viharaText(Theme.F.glyph)
                    .foregroundStyle(Theme.C.accent)
                    .transition(.opacity)
            }
        }
    }

    /// Three dashes that fill as the password gets stronger. Progress, not a policy.
    private var strengthBars: some View {
        HStack(spacing: Theme.S.s05) {
            ForEach(0..<3, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(index < model.passwordStrength ? Theme.C.accent : Theme.C.border)
                    .frame(width: Theme.Size.strengthBar, height: Theme.Size.hairline * 2)
            }
        }
        .animation(Theme.Motion.tab, value: model.passwordStrength)
        .accessibilityHidden(true)
    }

    // MARK: - Below the list

    private var helper: some View {
        HStack(alignment: .top) {
            if let helperKey = model.helperKey {
                Text(LocalizedStringKey(helperKey))
                    .viharaText(Theme.F.small)
                    .foregroundStyle(model.helperIsWarning ? Theme.C.price : Theme.C.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: Theme.S.s3)

            if model.mode == .signIn {
                Button {
                    isForgotPasswordPresented = true
                } label: {
                    Text("auth.forgotPassword")
                        .viharaText(Theme.F.small)
                        .foregroundStyle(Theme.C.accentDeep)
                        .viharaInlineHitTarget()
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, Theme.S.s2)
    }

    @ViewBuilder
    private var errorLine: some View {
        if let errorKey = model.errorKey {
            Text(LocalizedStringKey(errorKey))
                .viharaText(Theme.F.small)
                .foregroundStyle(Theme.C.price)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, Theme.S.s2)
        }
    }

    private var submit: some View {
        Button {
            Task { await model.submit() }
        } label: {
            HStack(spacing: Theme.S.s2) {
                Text(LocalizedStringKey(model.mode.submitKey))
                    .viharaText(Theme.Plan.F.action)
                Image(systemName: "arrow.right")
                    .viharaText(Theme.F.glyph)
            }
            .foregroundStyle(model.canSubmit ? Theme.C.surface : Theme.C.textFaint)
            .frame(maxWidth: .infinity)
            .frame(minHeight: Theme.S.tapTarget + Theme.Plan.S.s1)
            .background {
                RoundedRectangle(cornerRadius: Theme.R.control, style: .continuous)
                    .fill(model.canSubmit ? Theme.C.accent : Theme.C.disabledFill)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!model.canSubmit)
        .padding(.top, Theme.S.s5)
    }

    // MARK: - Providers

    private var providers: some View {
        VStack(spacing: Theme.S.s4) {
            HStack(spacing: Theme.S.s3) {
                rule
                Text("auth.or")
                    .viharaText(Theme.F.label)
                    .foregroundStyle(Theme.C.textFaint)
                rule
            }

            HStack(spacing: Theme.S.s3) {
                providerTile(symbol: "apple.logo",
                             title: "auth.apple.short",
                             isEnabled: model.isAppleConfigured) {
                    apple.requestCredential { handleApple($0) }
                }

                providerTile(symbol: "g.circle",
                             title: "auth.google.short",
                             isEnabled: model.isGoogleConfigured) {
                    Task { await model.signInWithGoogle(presenting: WebAuthContext()) }
                }
            }
        }
        .padding(.top, Theme.S.s5)
    }

    private var rule: some View {
        Rectangle().fill(Theme.C.border).frame(height: Theme.Size.hairline)
    }

    /// A quiet tile. Not a filled button — email is the default way in, and two
    /// filled provider buttons would out-shout it.
    private func providerTile(symbol: String,
                              title: LocalizedStringKey,
                              isEnabled: Bool,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: Theme.S.s1) {
                Image(systemName: symbol)
                    .viharaText(Theme.F.h3)
                Text(title)
                    .viharaText(Theme.F.providerTile)
            }
            .foregroundStyle(Theme.C.text)
            .frame(maxWidth: .infinity)
            .frame(minHeight: Theme.Size.providerTile)
            .background {
                RoundedRectangle(cornerRadius: Theme.R.control, style: .continuous)
                    .fill(Theme.C.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.R.control, style: .continuous)
                            .strokeBorder(Theme.C.border, lineWidth: Theme.Size.hairline)
                    }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || model.isWorking)
        .opacity(isEnabled ? 1 : Theme.O.disabled)
    }

    private func handleApple(_ result: Result<AppleCredential, any Error>) {
        switch result {
        case let .success(credential):
            Task { await model.signInWithApple(credential) }
        case let .failure(error):
            // Backing out of the system sheet is a decision, not a failure.
            if (error as? ASAuthorizationError)?.code == .canceled {
                model.cancelled()
            } else {
                model.failed(.providerNotConfigured(.apple))
            }
        }
    }

    /// The one piece of small print that belongs here: what signing in commits to.
    private var terms: some View {
        // Concatenated rather than stacked in an `HStack`: three separate views wrap
        // as three separate blocks, which broke the sentence mid-clause. `Text` + is
        // one paragraph that happens to change colour.
        (Text("auth.terms.prefix")
            + Text(verbatim: " ")
            + Text("auth.terms.link").foregroundColor(Theme.C.accentDeep)
            + Text(verbatim: " ")
            + Text("auth.terms.suffix"))
            .viharaText(Theme.F.small)
            .foregroundStyle(Theme.C.textFaint)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, Theme.S.s6)
    }
}

/// Hands the OAuth sheet a window to present from.
private final class WebAuthContext: NSObject,
                                    WebAuthenticationPresenting,
                                    PresentationAnchorProviding,
                                    ASWebAuthenticationPresentationContextProviding,
                                    @unchecked Sendable {
    var anchor: ASWebAuthenticationPresentationContextProviding { self }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
            ?? ASPresentationAnchor()
    }
}

#Preview("Anmelden · Deutsch") {
    AuthView(model: SignInViewModel(service: StubAuthenticationService(store: InMemoryCredentialStore()),
                                    onSignedIn: { _ in }))
        .environment(Router())
        .environment(Session(service: StubAuthenticationService(store: InMemoryCredentialStore())))
        .environment(\.locale, Locale(identifier: "de"))
}

#Preview("Register · English") {
    let model = SignInViewModel(service: StubAuthenticationService(store: InMemoryCredentialStore()),
                                onSignedIn: { _ in })
    model.mode = .register
    return AuthView(model: model)
        .environment(Router())
        .environment(Session(service: StubAuthenticationService(store: InMemoryCredentialStore())))
        .environment(\.locale, Locale(identifier: "en"))
}
