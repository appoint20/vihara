import CoreGraphics
import CoreText
import Foundation
import UIKit

/// Automatic registration for bundled Google Fonts.
///
/// Registers Cormorant Garamond and Plus Jakarta Sans at launch and for previews,
/// ensuring typography renders reliably across simulator, device, and SwiftUI canvas.
public enum FontRegistration {

    private static var isRegistered = false

    @MainActor
    public static func registerCustomFonts() {
        guard !isRegistered else { return }
        isRegistered = true

        let fontNames = [
            "CormorantGaramond-Regular",
            "CormorantGaramond-Medium",
            "CormorantGaramond-SemiBold",
            "CormorantGaramond-Bold",
            "PlusJakartaSans-Regular",
            "PlusJakartaSans-Medium",
            "PlusJakartaSans-SemiBold",
            "PlusJakartaSans-Bold"
        ]

        for name in fontNames {
            registerFont(named: name)
        }
    }

    private static func registerFont(named name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "ttf")
                ?? Bundle(for: BundleToken.self).url(forResource: name, withExtension: "ttf")
                ?? Bundle.allBundles.compactMap({ $0.url(forResource: name, withExtension: "ttf") }).first
        else {
            return
        }

        var error: Unmanaged<CFError>?
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
    }

    private final class BundleToken {}
}
