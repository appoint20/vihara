import SwiftUI

/// A small horizontal card for the "Beliebt gerade" rail: square thumb, title, and a
/// muted line of supporting detail.
struct CompactCard: View {
    let image: String
    let title: String
    let subtitle: String

    @ScaledMetric(relativeTo: .subheadline) private var width: CGFloat = Theme.Size.compactCardWidth
    @ScaledMetric(relativeTo: .subheadline) private var thumb: CGFloat = Theme.Size.compactThumb

    var body: some View {
        HStack(spacing: Theme.S.s3) {
            AssetImage(name: image)
                .frame(width: thumb, height: thumb)
                .clipShape(RoundedRectangle(cornerRadius: Theme.R.compactThumb, style: .continuous))

            VStack(alignment: .leading, spacing: Theme.S.s05) {
                Text(title)
                    .viharaText(Theme.F.compactTitle)
                    .foregroundStyle(Theme.C.text)
                Text(subtitle)
                    .viharaText(Theme.F.small)
                    .foregroundStyle(Theme.C.textMuted)
            }

            Spacer(minLength: 0)
        }
        .padding(EdgeInsets(top: Theme.S.compact,
                            leading: Theme.S.compact,
                            bottom: Theme.S.compact,
                            trailing: Theme.S.compactTrailing))
        .frame(width: width, alignment: .leading)
        .background(
            Theme.C.surface,
            in: RoundedRectangle(cornerRadius: Theme.R.compactCard, style: .continuous)
        )
        .viharaShadow(Theme.Shadow.card)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    HStack(alignment: .top, spacing: Theme.S.rail) {
        CompactCard(image: "top_modena", title: "Modena", subtitle: "2 Tage")
        CompactCard(image: "top_ravenna", title: "Ravenna", subtitle: "2 Tage")
    }
    .padding(Theme.S.screen)
    .background(Theme.C.bg)
}
