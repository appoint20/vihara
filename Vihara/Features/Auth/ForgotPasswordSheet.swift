import SwiftUI

/// Editorial modal sheet for password recovery ("Passwort vergessen").
struct ForgotPasswordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email: String = "sanya@vihara.app"
    @State private var isSent = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Theme.S.s5) {
                VStack(alignment: .leading, spacing: Theme.S.s2) {
                    Text("Passwort zurücksetzen")
                        .viharaText(Theme.F.h2)
                        .foregroundStyle(Theme.C.text)

                    Text("Geben Sie Ihre registrierte E-Mail-Adresse ein. Wir senden Ihnen umgehend einen Link zur Wiederherstellung.")
                        .viharaText(Theme.F.body)
                        .foregroundStyle(Theme.C.textMuted)
                }

                if isSent {
                    HStack(spacing: Theme.S.s3) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Theme.C.accent)
                            .viharaText(Theme.F.glyph)

                        Text("E-Mail versendet! Bitte überprüfen Sie Ihr Postfach.")
                            .viharaText(Theme.F.body)
                            .foregroundStyle(Theme.C.text)
                    }
                    .padding(Theme.S.s4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        RoundedRectangle(cornerRadius: Theme.R.compactCard, style: .continuous)
                            .fill(Theme.C.surface)
                            .overlay {
                                RoundedRectangle(cornerRadius: Theme.R.compactCard, style: .continuous)
                                    .strokeBorder(Theme.C.accent.opacity(0.4), lineWidth: Theme.Size.hairline)
                            }
                    }
                } else {
                    VStack(alignment: .leading, spacing: Theme.S.s2) {
                        Text("E-MAIL")
                            .viharaText(Theme.F.label)
                            .foregroundStyle(Theme.C.textFaint)

                        TextField("ihre.email@beispiel.de", text: $email)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .viharaText(Theme.F.body)
                            .padding(Theme.S.s4)
                            .background {
                                RoundedRectangle(cornerRadius: Theme.R.compactCard, style: .continuous)
                                    .fill(Theme.C.surface)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: Theme.R.compactCard, style: .continuous)
                                            .strokeBorder(Theme.C.border, lineWidth: Theme.Size.hairline)
                                    }
                            }
                    }

                    Button {
                        withAnimation(Theme.Plan.Motion.standard) {
                            isSent = true
                        }
                        Haptics.commit()
                    } label: {
                        Text("LINK SENDEN")
                            .viharaText(Theme.F.tabLabel)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: Theme.S.tapTarget)
                            .background {
                                RoundedRectangle(cornerRadius: Theme.R.pill, style: .continuous)
                                    .fill(Theme.C.text)
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Spacer()
            }
            .padding(.horizontal, Theme.S.screen)
            .padding(.top, Theme.S.s5)
            .background(Theme.C.bg.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") {
                        dismiss()
                    }
                    .viharaText(Theme.F.small)
                    .foregroundStyle(Theme.C.textMuted)
                }
            }
        }
    }
}

#Preview {
    ForgotPasswordSheet()
}
