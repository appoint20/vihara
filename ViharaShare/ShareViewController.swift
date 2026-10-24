import UIKit
import SwiftUI
import UniformTypeIdentifiers

/// The share sheet entry point (COMPETITION.md wedge 3).
///
/// Nobody starts a trip in a trip planner; they start in a Reel. This is the front
/// door Wanderlog does not have on iOS — places saved in a social app have to be
/// retyped by hand there.
///
/// **It captures and nothing else.** It does not resolve places, does not touch the
/// catalogue, and does not open the network. An app extension gets a fraction of the
/// app's memory and is killed without ceremony, so the expensive half happens in the
/// app, where it can also be improved without shipping a new extension. See
/// ``SharedCapture``.
final class ShareViewController: UIViewController {

    private var capture: SharedCapture?
    private let inbox = SharedInbox()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        Task { @MainActor in
            let capture = await readSharedItems()
            self.capture = capture
            present(outcome: outcome(for: capture))
        }
    }

    /// Internal rather than private: ``ShareConfirmationView`` renders it, and the
    /// three cases are the whole of what this extension can report.
    enum Outcome {
        case saved(SharedCapture)
        /// Nothing usable came through — a share with neither a link nor text.
        case nothingToSave
        /// The App Group is not configured, so the capture cannot reach the app.
        case unavailable
    }

    func outcome(for capture: SharedCapture?) -> Outcome {
        guard let capture, !capture.isEmpty else { return .nothingToSave }
        guard inbox.isAvailable else { return .unavailable }
        return inbox.append(capture) ? .saved(capture) : .unavailable
    }

    private func present(outcome: Outcome) {
        let view = ShareConfirmationView(outcome: outcome) { [weak self] in
            self?.finish()
        }
        let host = UIHostingController(rootView: view)
        host.view.backgroundColor = .clear
        addChild(host)
        host.view.frame = self.view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.view.addSubview(host.view)
        host.didMove(toParent: self)
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: nil)
    }

    // MARK: - Reading what was shared

    /// Pulls the URL and every piece of text out of the extension context.
    ///
    /// Both are asked for, because the share sheet is inconsistent about which it
    /// provides: TikTok tends to hand over a URL with the caption as the item's
    /// `attributedContentText`, Safari gives a URL and a page title, and a plain
    /// text selection gives no URL at all.
    private func readSharedItems() async -> SharedCapture? {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else { return nil }

        var url: URL?
        var texts: [String] = []

        for item in items {
            // The caption the host app attached, where there is one. This is the
            // single most useful field in the whole payload, and it arrives without
            // any network call.
            if let contentText = item.attributedContentText?.string, !contentText.isEmpty {
                texts.append(contentText)
            }

            for provider in item.attachments ?? [] {
                if url == nil, provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    url = await provider.loadURL()
                }
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
                   let text = await provider.loadText(), !text.isEmpty {
                    texts.append(text)
                }
            }
        }

        // A URL that arrived as plain text is still a URL — Instagram shares this way.
        if url == nil, let found = texts.compactMap(Self.firstURL(in:)).first {
            url = found
        }

        let text = texts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            // The same string often arrives twice: once as content text, once as an
            // attachment.
            .reduce(into: [String]()) { unique, line in
                if !unique.contains(line) { unique.append(line) }
            }
            .joined(separator: "\n")

        return SharedCapture(url: url, text: text)
    }

    static func firstURL(in text: String) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        return detector.firstMatch(in: text, range: range)?.url
    }
}

private extension NSItemProvider {
    func loadURL() async -> URL? {
        await withCheckedContinuation { continuation in
            loadItem(forTypeIdentifier: UTType.url.identifier) { item, _ in
                continuation.resume(returning: item as? URL)
            }
        }
    }

    func loadText() async -> String? {
        await withCheckedContinuation { continuation in
            loadItem(forTypeIdentifier: UTType.plainText.identifier) { item, _ in
                continuation.resume(returning: item as? String)
            }
        }
    }
}
