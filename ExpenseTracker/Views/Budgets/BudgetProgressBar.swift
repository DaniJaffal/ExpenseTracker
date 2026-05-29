//
//  BudgetProgressBar.swift
//  ExpenseTracker
//
//  Small reusable progress bar that colors itself by budget status.
//

import SwiftUI

struct BudgetProgressBar: View {
    let fraction: Double      // 0...1
    let tint: Color
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(tint.opacity(0.18))
                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(tint)
                    .frame(width: max(4, proxy.size.width * fraction))
            }
        }
        .frame(height: height)
    }
}
