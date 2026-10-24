import SwiftUI
import UniformTypeIdentifiers

/// The plan as a shareable PDF (F-08).
///
/// A `Transferable` rather than a file the view model writes, so rendering happens
/// **when the share sheet asks for it** and not a moment earlier. The PDF of a
/// fourteen-day plan is not free to produce, and a traveller who opens the share
/// sheet and changes their mind should not have paid for it in dropped frames.
///
/// It also keeps ``PlanViewModel`` free of UIKit: the model decides *what* may be
/// exported, this decides how it becomes bytes.
struct ExportedPlan: Transferable {
    let document: PlanDocument

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .pdf) { plan in
            PlanPDFRenderer.data(for: plan.document)
        }
        .suggestedFileName { plan in
            // A file called "Dokument.pdf" in a downloads folder is a file nobody
            // finds again.
            "\(plan.document.fileNameStem).pdf"
        }
    }
}

extension PlanDocument {
    /// A filename-safe stem: "Bologna", or "Bologna (Vorschau)" for a preview.
    var fileNameStem: String {
        let base = watermark == nil ? title : "\(title) (\(watermark!))"
        return base.components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>"))
            .joined(separator: "-")
    }
}
