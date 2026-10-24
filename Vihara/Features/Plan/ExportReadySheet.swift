import SwiftUI

/// What came out of the export (F-08).
///
/// Shown instead of throwing the share sheet straight at the traveller, because an
/// export has a *result* worth seeing: how many days are in the file, whether it
/// carries a watermark, and what it is called. A share sheet that appears unannounced
/// leaves all three unanswered.
struct ExportReadySheet: View {
    let document: PlanDocument

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Theme.Plan.S.s4) {
                Text(document.fileNameStem)
                    .viharaText(Theme.Plan.F.dayTitle)
                    .foregroundStyle(Theme.C.text)
                    .fixedSize(horizontal: false, vertical: true)

                Text(summary)
                    .viharaText(Theme.Plan.F.item)
                    .foregroundStyle(Theme.C.textMuted)
                    .fixedSize(horizontal: false, vertical: true)

                ShareLink(item: ExportedPlan(document: document),
                          preview: SharePreview(document.fileNameStem)) {
                    Text("export.share")
                        .viharaText(Theme.Plan.F.action)
                        .foregroundStyle(Theme.C.bg)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: Theme.S.tapTarget + Theme.Plan.S.s1)
                        .background(Theme.C.text,
                                    in: RoundedRectangle(cornerRadius: Theme.Plan.R.surface,
                                                         style: .continuous))
                }

                Spacer(minLength: 0)
            }
            .padding(Theme.Plan.S.screen)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.C.bg.ignoresSafeArea())
            .navigationTitle(Text("paywall.title"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.done") { dismiss() }
                }
            }
        }
    }

    private var summary: String {
        let dayCount = document.days.count
        return dayCount == 1
            ? String(format: NSLocalizedString("export.summary.one", comment: ""), dayCount)
            : String(format: NSLocalizedString("export.summary.many", comment: ""), dayCount)
    }
}
