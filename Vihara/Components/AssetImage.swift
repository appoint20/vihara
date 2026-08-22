import SwiftUI

/// A photograph from the asset catalog, sized to fill whatever space it is given.
///
/// The muted fill sits behind the image at all times, so a missing or renamed asset
/// degrades to a colour field instead of collapsing the layout — which is what the
/// prototype relies on until real photography lands.
struct AssetImage: View {
    let name: String

    var body: some View {
        Rectangle()
            .fill(Theme.C.imageFallback)
            .overlay {
                if let image = UIImage(named: name) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipped()
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: Theme.S.rail) {
        AssetImage(name: "dest_bologna")
        AssetImage(name: "a_name_that_does_not_exist")
    }
    .frame(height: Theme.Size.destCard.height)
    .padding(Theme.S.screen)
}
