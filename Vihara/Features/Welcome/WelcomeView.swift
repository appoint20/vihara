import SwiftUI

/// Screen 1 — a looping aerial clip inset from the device edges, with the wordmark at
/// the top and the headline, supporting copy and the pull-up control at the foot.
struct WelcomeView: View {
    @Environment(Router.self) private var router
    @ScaledMetric(relativeTo: .body) private var measure: CGFloat = Theme.Size.heroMeasure

    var body: some View {
        ZStack {
            Theme.C.bg
                .ignoresSafeArea()

            backdrop

            content
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    /// Full-screen edge-to-edge video backdrop with editorial gradient scrim.
    private var backdrop: some View {
        VideoBackground(resource: "welcome_loop", poster: "welcome_bg")
            .overlay { Theme.G.welcomeScrim }
            .ignoresSafeArea()
    }

    private var content: some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.S.s2) {
                Image("vihara_logo_white")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 22)
                    .opacity(Theme.O.brandMark)

                Text("Vihara")
                    .viharaText(Theme.F.brand)
                    .foregroundStyle(.white.opacity(Theme.O.brandMark))
            }
            .padding(.top, Theme.S.s3)

            Spacer(minLength: Theme.S.s6)

            VStack(spacing: Theme.S.s4) {
                Text("Finde deine schönste Reise")
                    .viharaText(Theme.F.h1)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Erzähl uns, worauf du Lust hast. Den Rest prüfen wir für dich — in Echtzeit.")
                    .viharaText(Theme.F.body)
                    .foregroundStyle(.white.opacity(Theme.O.heroBody))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: measure)
            }

            PullUpControl(title: "Los", label: "Los — Anmelden & Reise entdecken") {
                router.push(.auth)
            }
            .padding(.top, Theme.S.s7)
        }
        .padding(.horizontal, Theme.S.screen)
        .padding(.vertical, Theme.S.s6)
    }
}

#Preview {
    WelcomeView()
        .environment(Router())
}
