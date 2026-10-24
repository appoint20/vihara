import UIKit
import SwiftUI
import CoreText

/// Turns a ``PlanDocument`` into a PDF (F-08).
///
/// Vector text through CoreText rather than a rasterised screenshot of the screen: a
/// plan is read on a phone, printed at a hotel desk and searched in a mail client,
/// and all three want selectable text.
///
/// **Colours are resolved against light mode explicitly.** `Theme.C` carries both
/// appearances, and a PDF exported at night would otherwise be near-white text on a
/// white page — invisible on screen and worse on paper. A document has no appearance;
/// it has ink.
enum PlanPDFRenderer {

    /// A4, because the app is German-first and A4 is what comes out of the printer.
    static let pageSize = CGSize(width: 595.2, height: 841.8)
    static let margin: CGFloat = 56

    static func data(for document: PlanDocument) -> Data {
        let text = attributedText(for: document)
        let textRect = CGRect(x: margin,
                              y: margin,
                              width: pageSize.width - margin * 2,
                              height: pageSize.height - margin * 2 - footerHeight)

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize),
                                             format: format(for: document))
        let framesetter = CTFramesetterCreateWithAttributedString(text)

        return renderer.pdfData { context in
            var consumed = 0
            var pageNumber = 1

            repeat {
                context.beginPage()
                let cgContext = context.cgContext

                // CoreText draws bottom-up; UIKit's PDF context is top-down.
                cgContext.saveGState()
                cgContext.textMatrix = .identity
                cgContext.translateBy(x: 0, y: pageSize.height)
                cgContext.scaleBy(x: 1, y: -1)

                let path = CGPath(rect: CGRect(x: textRect.minX,
                                               y: pageSize.height - textRect.maxY,
                                               width: textRect.width,
                                               height: textRect.height),
                                  transform: nil)
                let frame = CTFramesetterCreateFrame(framesetter,
                                                     CFRange(location: consumed, length: 0),
                                                     path,
                                                     nil)
                CTFrameDraw(frame, cgContext)
                cgContext.restoreGState()

                let visible = CTFrameGetVisibleStringRange(frame)
                // A frame that fits nothing would loop forever — it happens when a
                // single paragraph is taller than the page.
                consumed += max(visible.length, 1)

                if let watermark = document.watermark {
                    draw(watermark: watermark, in: cgContext)
                }
                draw(footer: document, pageNumber: pageNumber, in: cgContext)
                pageNumber += 1
            } while consumed < text.length
        }
    }

    private static let footerHeight: CGFloat = 28

    private static func format(for document: PlanDocument) -> UIGraphicsPDFRendererFormat {
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: document.title,
            kCGPDFContextCreator as String: "Vihara",
            // Stated in the metadata as well as on the page: a preview that is
            // forwarded should still announce itself as one.
            kCGPDFContextSubject as String: document.watermark ?? document.subtitle,
        ]
        return format
    }

    // MARK: - Text

    private static func attributedText(for document: PlanDocument) -> NSAttributedString {
        let text = NSMutableAttributedString()

        text.append(paragraph(document.title, style: .title))
        text.append(paragraph(document.subtitle, style: .subtitle))

        for day in document.days {
            text.append(paragraph(day.title, style: .dayTitle))
            for block in day.blocks {
                text.append(paragraph(block.label, style: .blockLabel))
                for entry in block.entries {
                    let heading = [entry.time, entry.name].compactMap { $0 }.joined(separator: "   ")
                    text.append(paragraph(heading, style: .entry))
                    if !entry.detail.isEmpty {
                        text.append(paragraph(entry.detail, style: .detail))
                    }
                    if let caution = entry.caution {
                        text.append(paragraph(caution, style: .caution))
                    }
                }
            }
        }

        // The withheld days are named rather than silently dropped. A preview that
        // just stops reads as a broken file; one that says what is missing reads as
        // a preview.
        if !document.withheldDayTitles.isEmpty {
            text.append(paragraph(localized("export.preview.heading", locale: .current),
                                  style: .dayTitle))
            for title in document.withheldDayTitles {
                text.append(paragraph(title, style: .withheld))
            }
            text.append(paragraph(localized("export.preview.footer", locale: .current),
                                  style: .detail))
        }

        text.append(paragraph(document.disclaimer, style: .disclaimer))
        return text
    }

    private enum Style {
        case title, subtitle, dayTitle, blockLabel, entry, detail, caution, withheld, disclaimer
    }

    private static func paragraph(_ string: String, style: Style) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        let font: UIFont
        let colour: UIColor
        var tracking: CGFloat = 0

        switch style {
        case .title:
            font = .systemFont(ofSize: 28, weight: .semibold).serif
            colour = ink(Theme.C.text)
            paragraphStyle.paragraphSpacing = 2
        case .subtitle:
            font = .systemFont(ofSize: 11)
            colour = ink(Theme.C.textMuted)
            paragraphStyle.paragraphSpacing = 26
        case .dayTitle:
            font = .systemFont(ofSize: 17, weight: .semibold).serif
            colour = ink(Theme.C.text)
            paragraphStyle.paragraphSpacingBefore = 18
            paragraphStyle.paragraphSpacing = 8
        case .blockLabel:
            font = .systemFont(ofSize: 8.5, weight: .semibold)
            colour = ink(Theme.C.textFaint)
            tracking = 0.8
            paragraphStyle.paragraphSpacingBefore = 10
            paragraphStyle.paragraphSpacing = 4
        case .entry:
            font = .systemFont(ofSize: 11.5)
            colour = ink(Theme.C.text)
            paragraphStyle.paragraphSpacing = 1
        case .detail:
            font = .systemFont(ofSize: 9.5)
            colour = ink(Theme.C.textMuted)
            paragraphStyle.paragraphSpacing = 6
        case .caution:
            font = .systemFont(ofSize: 9.5)
            colour = ink(Theme.C.price)
            paragraphStyle.paragraphSpacing = 6
        case .withheld:
            font = .systemFont(ofSize: 11.5)
            colour = ink(Theme.C.textFaint)
            paragraphStyle.paragraphSpacing = 2
        case .disclaimer:
            font = .systemFont(ofSize: 8.5)
            colour = ink(Theme.C.textFaint)
            paragraphStyle.paragraphSpacingBefore = 24
        }
        paragraphStyle.lineHeightMultiple = 1.2

        return NSAttributedString(string: string + "\n", attributes: [
            .font: font,
            .foregroundColor: colour,
            .paragraphStyle: paragraphStyle,
            .kern: tracking,
        ])
    }

    /// A theme colour as ink: resolved light, because paper has no dark mode.
    private static func ink(_ colour: Color) -> UIColor {
        UIColor(colour).resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
    }

    // MARK: - Watermark and footer

    /// Repeated diagonally across the whole page, over the text rather than under it.
    ///
    /// Under the text it could be cropped away; a tiled overlay cannot be removed
    /// without removing the content with it. Low alpha so the plan stays readable —
    /// the point is to mark the file, not to ruin it.
    private static func draw(watermark: String, in context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 34, weight: .semibold),
            .foregroundColor: ink(Theme.C.accent).withAlphaComponent(0.12),
        ]
        let text = watermark as NSString
        let size = text.size(withAttributes: attributes)

        context.translateBy(x: pageSize.width / 2, y: pageSize.height / 2)
        context.rotate(by: -.pi / 6)

        let stepX = size.width + 70
        let stepY = size.height + 110
        let reach = max(pageSize.width, pageSize.height)

        var y = -reach
        while y < reach {
            var x = -reach
            while x < reach {
                text.draw(at: CGPoint(x: x, y: y), withAttributes: attributes)
                x += stepX
            }
            y += stepY
        }
    }

    private static func draw(footer document: PlanDocument,
                             pageNumber: Int,
                             in context: CGContext) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8.5),
            .foregroundColor: ink(Theme.C.textFaint),
        ]
        let line = "\(document.title) · \(pageNumber)" as NSString
        let size = line.size(withAttributes: attributes)
        line.draw(at: CGPoint(x: (pageSize.width - size.width) / 2,
                              y: pageSize.height - margin / 2 - size.height),
                  withAttributes: attributes)
    }
}

private extension UIFont {
    /// New York, matching ``Theme/F`` — which builds every serif step with
    /// `.system(design: .serif)` rather than naming the font file.
    var serif: UIFont {
        guard let descriptor = fontDescriptor.withDesign(.serif) else { return self }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
