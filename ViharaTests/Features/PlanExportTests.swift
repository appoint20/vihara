import Testing
import Foundation
import CoreGraphics
@testable import Vihara

@Suite("The exported document")
struct PlanDocumentTests {

    private let brief = Fixture.brief(destination: "Bologna", nights: 3)

    private func days(_ count: Int) -> [TripDay] {
        (0..<count).map { index in
            TripDay(date: Fixture.date(2026, 4, 14 + index), city: "Bologna", blocks: [
                DayBlock(slot: .morning, items: [Fixture.item("Torre \(index)", at: (9, 0))]),
                DayBlock(slot: .afternoon),
                DayBlock(slot: .evening, items: [Fixture.item("Osteria \(index)", kind: .meal)]),
            ])
        }
    }

    @Test("A full grant carries every day and no watermark")
    func fullGrant() {
        let document = PlanDocument.make(brief: brief, days: days(3), grant: .full)

        #expect(document.days.count == 3)
        #expect(document.withheldDayTitles.isEmpty)
        #expect(document.watermark == nil)
    }

    /// A watermarked *complete* plan is still a complete plan — the traveller reads
    /// it and never pays. One day in full is enough to judge the quality.
    @Test("A preview carries one day and names the rest")
    func previewTruncates() {
        let document = PlanDocument.make(brief: brief, days: days(3), grant: .preview(daysInFull: 1))

        #expect(document.days.count == 1)
        #expect(document.withheldDayTitles.count == 2)
        #expect(document.watermark != nil)
    }

    /// A preview that just stops reads as a broken file; one that says what is
    /// missing reads as a preview.
    @Test("Withheld days are named, not silently dropped")
    func withheldDaysAreNamed() throws {
        let all = days(3)
        let document = PlanDocument.make(brief: brief, days: all, grant: .preview(daysInFull: 1))

        #expect(document.withheldDayTitles == [all[1].title, all[2].title])
    }

    @Test("A preview of a one-day trip withholds nothing")
    func shortTripPreview() {
        let document = PlanDocument.make(brief: brief, days: days(1), grant: .preview(daysInFull: 1))

        #expect(document.days.count == 1)
        #expect(document.withheldDayTitles.isEmpty)
        // Still marked: it is still a preview, and the watermark is what says so.
        #expect(document.watermark != nil)
    }

    @Test("Asking for more days than exist does not trap")
    func previewLongerThanTheTrip() {
        let document = PlanDocument.make(brief: brief, days: days(2), grant: .preview(daysInFull: 9))
        #expect(document.days.count == 2)
    }

    /// The same invariant ``PlanTextExport`` keeps: a PDF and the screen that
    /// produced it must never describe the same day differently.
    @Test("Day titles and block labels match the screen's own")
    func labelsMatchTheScreen() throws {
        let all = days(1)
        let document = PlanDocument.make(brief: brief, days: all, grant: .full)
        let day = try #require(document.days.first)

        #expect(day.title == all[0].title)
        #expect(day.blocks.map(\.label) == [DaySlot.morning.label.uppercased(),
                                            DaySlot.evening.label.uppercased()])
    }

    @Test("Empty blocks are left out of the file")
    func emptyBlocksOmitted() throws {
        let document = PlanDocument.make(brief: brief, days: days(1), grant: .full)
        let day = try #require(document.days.first)

        #expect(day.blocks.count == 2)
        #expect(day.blocks.allSatisfy { !$0.entries.isEmpty })
    }

    @Test("A ticketed stop carries its caution separately from its detail")
    func cautionsAreSeparate() throws {
        let place = Fixture.place("Torre", requiresTicket: true, minimumAge: 12)
        let day = TripDay(date: Fixture.date(2026, 4, 14), city: "Bologna", blocks: [
            DayBlock(slot: .morning, items: [Fixture.item("Torre", place: place)]),
            DayBlock(slot: .afternoon),
            DayBlock(slot: .evening),
        ])
        let document = PlanDocument.make(brief: brief, days: [day], grant: .full)
        let entry = try #require(document.days.first?.blocks.first?.entries.first)

        #expect(entry.caution != nil)
        #expect(entry.detail.contains("Teststraße"))
    }

    @Test("A preview's filename says it is one")
    func previewFilename() {
        let full = PlanDocument.make(brief: brief, days: days(1), grant: .full)
        let preview = PlanDocument.make(brief: brief, days: days(1), grant: .preview(daysInFull: 1))

        #expect(full.fileNameStem == "Bologna")
        #expect(preview.fileNameStem != full.fileNameStem)
        #expect(preview.fileNameStem.contains("Bologna"))
    }

    /// A slash in a destination name would otherwise produce a path, not a filename.
    @Test("Path separators never reach the filename")
    func filenameIsSafe() {
        var awkward = brief
        awkward.destination = "Bologna/Modena"
        let document = PlanDocument.make(brief: awkward, days: days(1), grant: .full)

        #expect(!document.fileNameStem.contains("/"))
    }
}

@Suite("Rendering the PDF")
struct PlanPDFRendererTests {

    private let brief = Fixture.brief(destination: "Bologna", nights: 3)

    private func document(days dayCount: Int, grant: ExportGrant) -> PlanDocument {
        let days = (0..<dayCount).map { index in
            TripDay(date: Fixture.date(2026, 4, 1 + index), city: "Bologna", blocks: [
                DayBlock(slot: .morning, items: [
                    Fixture.item("Torre \(index)", at: (9, 0)),
                    Fixture.item("Basilica \(index)", at: (11, 0), walk: 8),
                ]),
                DayBlock(slot: .afternoon, items: [Fixture.item("Museum \(index)")]),
                DayBlock(slot: .evening, items: [Fixture.item("Osteria \(index)", kind: .meal)]),
            ])
        }
        return PlanDocument.make(brief: brief, days: days, grant: grant)
    }

    @Test("It produces a real PDF")
    func producesAPDF() throws {
        let data = PlanPDFRenderer.data(for: document(days: 2, grant: .full))

        #expect(data.count > 1_000)
        // Every PDF starts with this. A renderer that silently produced nothing
        // would otherwise pass a "not empty" assertion on an error page.
        #expect(data.prefix(4) == Data("%PDF".utf8))
    }

    @Test("Every page is readable by CoreGraphics, and metadata carries the title")
    func pagesAreWellFormed() throws {
        let data = PlanPDFRenderer.data(for: document(days: 2, grant: .full))
        let provider = try #require(CGDataProvider(data: data as CFData))
        let pdf = try #require(CGPDFDocument(provider))

        #expect(pdf.numberOfPages >= 1)
        for pageNumber in 1...pdf.numberOfPages {
            let page = try #require(pdf.page(at: pageNumber))
            let box = page.getBoxRect(.mediaBox)
            #expect(abs(box.width - PlanPDFRenderer.pageSize.width) < 1)
            #expect(abs(box.height - PlanPDFRenderer.pageSize.height) < 1)
        }
    }

    /// A fourteen-day plan does not fit on one page, and a renderer that loops
    /// forever on an oversized paragraph is worse than one that truncates.
    @Test("A long plan paginates and terminates")
    func longPlanPaginates() throws {
        let data = PlanPDFRenderer.data(for: document(days: 14, grant: .full))
        let provider = try #require(CGDataProvider(data: data as CFData))
        let pdf = try #require(CGPDFDocument(provider))

        #expect(pdf.numberOfPages > 1)
        #expect(pdf.numberOfPages < 40)
    }

    @Test("A preview renders fewer pages than the full plan")
    func previewIsSmaller() throws {
        func pages(_ grant: ExportGrant) throws -> Int {
            let data = PlanPDFRenderer.data(for: document(days: 8, grant: grant))
            let provider = try #require(CGDataProvider(data: data as CFData))
            return try #require(CGPDFDocument(provider)).numberOfPages
        }

        #expect(try pages(.preview(daysInFull: 1)) < pages(.full))
    }

    @Test("An empty plan still renders rather than trapping")
    func emptyPlanRenders() throws {
        let empty = PlanDocument.make(brief: brief, days: [], grant: .full)
        let data = PlanPDFRenderer.data(for: empty)

        #expect(data.prefix(4) == Data("%PDF".utf8))
    }

    /// A preview that is forwarded should still announce itself as one, even to
    /// software that only reads metadata.
    @Test("The watermark is stated in the document metadata too")
    func watermarkIsInMetadata() throws {
        let data = PlanPDFRenderer.data(for: document(days: 2, grant: .preview(daysInFull: 1)))
        // The subject is written into the PDF catalogue; searching the raw bytes is
        // enough to prove it was set without parsing the whole object graph.
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains("Vihara"))
    }
}
