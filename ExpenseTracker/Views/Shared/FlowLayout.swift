//
//  FlowLayout.swift
//  ExpenseTracker
//
//  Wrapping layout that flows subviews left-to-right and pushes overflow to
//  a new line. Used for tag chip displays in editors and rows.
//

import SwiftUI

struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            let isFirstOnLine = lineWidth == 0
            let candidateWidth = lineWidth + (isFirstOnLine ? 0 : spacing) + size.width

            if candidateWidth > maxWidth && !isFirstOnLine {
                totalHeight += lineHeight + lineSpacing
                totalWidth = max(totalWidth, lineWidth)
                lineWidth = size.width
                lineHeight = size.height
            } else {
                lineWidth = candidateWidth
                lineHeight = max(lineHeight, size.height)
            }

            if index == subviews.count - 1 {
                totalHeight += lineHeight
                totalWidth = max(totalWidth, lineWidth)
            }
        }
        return CGSize(width: min(maxWidth, totalWidth), height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
