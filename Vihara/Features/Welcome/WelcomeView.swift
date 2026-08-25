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

    /// The clip never touches the device edges — it sits inside a rounded container
    /// with a consistent margin all the way round, exactly as the still did.
    private var backdrop: some View {
        VideoBackground(resource: "welcome_loop", poster: "welcome_bg")
            .overlay { Theme.G.welcomeScrim }
            .clipShape(RoundedRectangle(cornerRadius: Theme.R.welcome, style: .continuous))
            .padding(Theme.S.welcomeInset)
            .ignoresSafeArea()
    }

    private var content: some View {
        VStack(spacing: 0) {
            Text("Vihara")
                .viharaText(Theme.F.brand)
                .foregroundStyle(.white.opacity(Theme.O.brandMark))

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

            PullUpControl(title: "Los", label: "Los — Reise entdecken") {
                router.push(.discover)
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
