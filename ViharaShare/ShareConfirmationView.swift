import SwiftUI

/// What the traveller sees after sharing.
///
/// Deliberately a confirmation and not an editor. The share sheet is a half-second
/// interaction in the middle of scrolling; an extension that asks which city this
/// Reel was about is an extension that gets cancelled. The decisions happen in the
/// app, where there is room for them.
///
/// It does not use `Theme`: the design system lives in the app target and an app
/// extension links its own binary. Bringing it across would mean compiling the whole
/// design system into a process that draws one sentence.
struct ShareConfirmationView: View {
    let outcome: ShareViewController.Outcome
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Text(headline)
                .font(.system(.title3, design: .serif).weight(.semibold))
                .multilineTextAlignment(.center)

            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            Button(action: onDone) {
                Text("Fertig")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
        // Dismissing itself would be faster, but a confirmation nobody reads is a
        // confirmation that cannot report a failure — and the App Group failure is
        // exactly the one worth reading.
        .task {
            guard case .saved = outcome else { return }
            try? await Task.sleep(for: .seconds(1.2))
            onDone()
        }
    }

    private var headline: String {
        switch outcome {
        case .saved:         "Gemerkt"
        case .nothingToSave: "Nichts zum Merken"
        case .unavailable:   "Konnte nicht gespeichert werden"
        }
    }

    private var detail: String {
        switch outcome {
        case let .saved(capture):
            switch capture.source {
            case .tiktok:    "Wir suchen die Orte heraus, sobald du Vihara öffnest."
            case .instagram: "Wir suchen die Orte heraus, sobald du Vihara öffnest."
            case .youtube:   "Wir suchen die Orte heraus, sobald du Vihara öffnest."
            case .unknown:   "Wir sehen uns das an, sobald du Vihara öffnest."
            }
        case .nothingToSave:
            "In diesem Beitrag war weder ein Link noch Text."
        case .unavailable:
            "Vihara und die Teilen-Erweiterung teilen sich keinen App-Group-Container. Das ist eine Einstellung im Entwicklerprofil, kein Fehler des Beitrags."
        }
    }
}
