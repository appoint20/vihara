import SwiftUI

/// The one primary action a screen is allowed (PRD 5.1, rule 3).
///
/// Full width, near-black, 2pt radius, no shadow — shadows belong to modal layers
/// only. Everything else on the screen is secondary, which here means textual and
/// without a filled surface.
struct PrimaryAction: View {
    let title: String
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .viharaText(Theme.Plan.F.action)
                .foregroundStyle(Theme.C.bg)
                .frame(maxWidth: .infinity)
                .frame(minHeight: Theme.S.tapTarget + Theme.Plan.S.s1)
                .background(Theme.C.text,
                            in: RoundedRectangle(cornerRadius: Theme.Plan.R.surface,
                                                 style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.35)
    }
}

/// A textual back control. The system navigation bar is sans-serif, and the type rule
/// is "one serif family for content *and* chrome" — so the bar stays hidden and the
/// affordance is drawn here.
struct BackControl: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Plan.S.s1) {
                Image(systemName: "chevron.left")
                    .viharaText(Theme.Plan.F.meta)
                Text("control.back")
                    .viharaText(Theme.Plan.F.meta)
            }
            .foregroundStyle(Theme.C.textMuted)
            .viharaHitTarget()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("control.back"))
    }
}
