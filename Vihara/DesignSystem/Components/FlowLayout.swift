import SwiftUI

/// Lays subviews left to right, wrapping when the line is full.
///
/// German compounds are long and Dynamic Type makes them longer, so a fixed row of
/// intake chips either truncates or scrolls sideways — both of which hide options the
/// traveller is meant to correct. Wrapping is the only honest arrangement.
///
/// A `Layout` rather than a `LazyVGrid`: the chips have intrinsic, unequal widths, and
/// a grid would force them onto a column rhythm they do not have.
struct FlowLayout: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat

    init(spacing: CGFloat = Theme.Plan.S.s2, lineSpacing: CGFloat = Theme.Plan.S.s2) {
        self.spacing = spacing
        self.lineSpacing = lineSpacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let rows = arrange(subviews: subviews, in: proposal.width ?? .infinity)
        let height = rows.reduce(0) { $0 + $1.height } +
                     lineSpacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect,
                       proposal: ProposedViewSize,
                       subviews: Subviews,
                       cache: inout Void) {
        var y = bounds.minY
        for row in arrange(subviews: subviews, in: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y),
                                      proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(subviews: Subviews, in width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            // A chip wider than the container still gets its own line rather than
            // being dropped — it overflows visibly instead of vanishing.
            if !current.indices.isEmpty, needed > width {
                rows.append(current)
                current = Row()
                current.indices = [index]
                current.width = size.width
                current.height = size.height
            } else {
                current.indices.append(index)
                current.width = needed
                current.height = max(current.height, size.height)
            }
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}
