import SwiftUI
import SafariServices

/// The partner's page, inside Vihara.
///
/// `SFSafariViewController`, **not** `ASWebAuthenticationSession`, and the difference
/// is revenue rather than taste — see
/// [ADR-006](../../../docs/adr/006-affiliate-links-server-authoritative.md).
/// `ASWebAuthenticationSession` exists for OAuth and raises a system consent alert
/// ("…Wants to Use …booking.com… to Sign In") before the page loads. A traveller
/// tapping a ticket link is not signing in, and a permission dialog at the top of a
/// funnel is a funnel that does not convert.
///
/// Attribution is a cookie in **this** browser context. Since iOS 11 this controller
/// keeps a data store separate from Safari, so a click here and a purchase in Safari
/// an hour later is an unpaid booking — which is why the hand-off stays in the app
/// instead of calling `openURL`.
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let configuration = SFSafariViewController.Configuration()
        // Reader mode would strip the booking form off the page it is pointed at.
        configuration.entersReaderIfAvailable = false
        let controller = SFSafariViewController(url: url, configuration: configuration)
        controller.dismissButtonStyle = .close
        controller.preferredControlTintColor = nil
        return controller
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

// The sheet that presents this lives in ``PlanView``, which keeps exactly one —
// SwiftUI honours a single `.sheet` per view, and this screen has five destinations.
// ``PlanViewModel/open(_:)`` has already checked the URL's scheme, which is why this
// type can hand it to `SFSafariViewController` without rechecking at the crash site.
