import SwiftUI

/// Screen 1 — a full-bleed photograph inset from the device edges, with the
/// wordmark at the top and the headline, supporting copy and `Los` at the foot.
struct WelcomeView: View {
    @ScaledMetric(relativeTo: .title3) private var capsuleWidth: CGFloat = Theme.Size.welcomeCapsule.width
    @ScaledMetric(relativeTo: .title3) private var capsuleHeight: CGFloat = Theme.Size.welcomeCapsule.height
    @ScaledMetric(relativeTo: .title3) private var circle: CGFloat = Theme.Size.losCircle
    @ScaledMetric(relativeTo: .body) private var measure: CGFloat = Theme.Size.heroMeasure

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.C.bg
                    .ignoresSafeArea()

                photo

                content
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    /// The photograph never touches the device edges — it sits inside a rounded
    /// container with a consistent margin all the way round.
    private var photo: some View {
        AssetImage(name: "welcome_bg")
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

            startCapsule
                .padding(.top, Theme.S.s7)
        }
        .padding(.horizontal, Theme.S.screen)
        .padding(.vertical, Theme.S.s6)
    }

    private var startCapsule: some View {
        VStack(spacing: 0) {
            Image(systemName: "chevron.up")
                .viharaText(Theme.F.chevron)
                .foregroundStyle(.white.opacity(Theme.O.chevron))
                .accessibilityHidden(true)

            Spacer(minLength: Theme.S.s2)

            NavigationLink {
                DiscoverView()
            } label: {
                Text("Los")
                    .viharaText(Theme.F.cta)
                    .foregroundStyle(Theme.C.text)
                    .frame(width: circle, height: circle)
                    .background(Theme.C.surface, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, Theme.S.s3)
        .frame(width: capsuleWidth, height: capsuleHeight)
        .background {
            let shape = RoundedRectangle(cornerRadius: Theme.R.pill, style: .continuous)
            shape
                .fill(.ultraThinMaterial)
                .overlay { shape.fill(.white.opacity(Theme.O.glassFill)) }
                .overlay {
                    shape.strokeBorder(.white.opacity(Theme.O.glassStroke),
                                       lineWidth: Theme.Size.hairline)
                }
        }
    }
}

#Preview {
    WelcomeView()
}
