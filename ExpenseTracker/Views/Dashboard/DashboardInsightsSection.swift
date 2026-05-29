//
//  DashboardInsightsSection.swift
//  ExpenseTracker
//
//  Renders the auto-generated insight cards. Each row is a compact card with
//  a color-tinted icon badge, a bold headline, and a secondary subtitle.
//

import SwiftUI

struct DashboardInsightsSection: View {
    let insights: [Insight]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Insights")
                .font(.headline)
            VStack(spacing: 0) {
                ForEach(Array(insights.enumerated()), id: \.element.id) { index, insight in
                    InsightRow(insight: insight)
                        .padding(12)
                    if index != insights.count - 1 {
                        Divider().padding(.leading, 60)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

private struct InsightRow: View {
    let insight: Insight

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(hex: insight.iconColorHex).opacity(0.18))
                Image(systemName: insight.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(hex: insight.iconColorHex))
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(insight.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                Text(insight.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 4)

            if let trailing = insight.trailingText {
                Text(trailing)
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(Color(hex: insight.iconColorHex))
            }
        }
    }
}
