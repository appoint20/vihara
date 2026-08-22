import SwiftUI

/// A full-bleed photo card for the destination rail: scrim, rating pill, and an
/// inset caption card at the foot.
struct DestinationCard: View {
    let image: String
    let title: String
    let subtitle: String
    let rating: String

    // The card grows with Dynamic Type so the caption never clips; the rail simply
    // scrolls further.
    @ScaledMetric(relativeTo: .body) private var width: CGFloat = Theme.Size.destCard.width
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = Theme.Size.destCard.height

    var body: some View {
        AssetImage(name: image)
            .frame(width: width, height: height)
            .overlay { Theme.G.destinationScrim }
            .overlay(alignment: .topTrailing) { ratingPill }
            .overlay(alignment: .bottom) { caption }
            .clipShape(RoundedRectangle(cornerRadius: Theme.R.photoCard, style: .continuous))
            .accessibilityElement(children: .combine)
    }

    private var ratingPill: some View {
        Text("\(rating) ★")
            .viharaText(Theme.F.rating)
            .foregroundStyle(Theme.C.text)
            .padding(.horizontal, Theme.S.s2)
            .padding(.vertical, Theme.S.s1)
            .background(Theme.C.surface.opacity(Theme.O.ratingPill), in: Capsule())
            .padding(Theme.S.s3)
    }

    private var caption: some View {
        VStack(alignment: .leading, spacing: Theme.S.s05) {
            Text(title)
                .viharaText(Theme.F.cardTitle)
                .foregroundStyle(Theme.C.text)
            Text(subtitle)
                .viharaText(Theme.F.small)
                .foregroundStyle(Theme.C.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Theme.S.s3)
        .padding(.horizontal, Theme.S.cardCaptionH)
        .background(
            Theme.C.surface.opacity(Theme.O.destInnerCard),
            in: RoundedRectangle(cornerRadius: Theme.R.destInner, style: .continuous)
        )
        .padding(Theme.S.s3)
    }
}

#Preview {
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
    .padding(Theme.S.screen)
    .background(Theme.C.bg)
}
