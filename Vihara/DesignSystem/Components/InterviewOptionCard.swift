import SwiftUI

/// An interactive selection card for the trip planner interview flow.
///
/// Used for picking travel style, pacing, budget band, and dietary requirements
/// in the Wanderlog-style interview steps.
struct InterviewOptionCard: View {
    let title: String
    var subtitle: String? = nil
    var iconName: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.S.s3) {
                if let iconName {
                    Image(systemName: iconName)
                        .viharaText(Theme.F.glyph)
                        .foregroundStyle(isSelected ? Theme.C.accentDeep : Theme.C.textMuted)
                        .frame(width: 28, height: 28)
                }

                VStack(alignment: .leading, spacing: Theme.S.s05) {
                    Text(title)
                        .viharaText(Theme.F.compactTitle)
                        .foregroundStyle(isSelected ? Theme.C.text : Theme.C.text)

                    if let subtitle {
                        Text(subtitle)
                            .viharaText(Theme.Plan.F.meta)
                            .foregroundStyle(isSelected ? Theme.C.accentDeep : Theme.C.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 0)

                Circle()
                    .strokeBorder(isSelected ? Theme.C.accent : Theme.C.border, lineWidth: isSelected ? 4 : 1)
                    .frame(width: 18, height: 18)
            }
            .padding(Theme.S.s3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Theme.R.compactCard, style: .continuous)
                    .fill(isSelected ? Theme.C.surface : Theme.C.surface.opacity(0.7))
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.R.compactCard, style: .continuous)
                            .strokeBorder(isSelected ? Theme.C.accent : Theme.C.border,
                                          lineWidth: isSelected ? 1.5 : Theme.Size.hairline)
                    }
                    .viharaShadow(isSelected ? Theme.Shadow.card : Theme.ShadowSpec(color: .clear, radius: 0, y: 0))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .animation(Theme.Plan.Motion.standard, value: isSelected)
    }
}

#Preview {
    VStack(spacing: Theme.S.s3) {
        InterviewOptionCard(title: "Städtereise",
                            subtitle: "Kultur, Cafés und urbane Entdeckungen",
                            iconName: "building.2",
                            isSelected: true) {}
        InterviewOptionCard(title: "Rundreise",
                            subtitle: "Mehrere Orte und weite Landschaften",
                            iconName: "map",
                            isSelected: false) {}
    }
    .padding(Theme.S.screen)
    .background(Theme.C.bg)
}
