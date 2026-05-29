//
//  ExpenseRow.swift
//  ExpenseTracker
//

import SwiftUI

struct ExpenseRow: View {
    let expense: Expense

    var body: some View {
        HStack(spacing: 12) {
            IconBadge(
                symbol: expense.category?.iconName ?? "tag.fill",
                color: Color(hex: expense.category?.colorHex ?? "#8E8E93")
            )
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(expense.note.isEmpty ? (expense.category?.name ?? "Expense") : expense.note)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    if !(expense.additionalPayments ?? []).isEmpty {
                        Text("Split")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color(hex: "#5856D6"))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color(hex: "#5856D6").opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                HStack(spacing: 6) {
                    if let acc = expense.account {
                        Text(acc.name)
                    } else {
                        Text("No account")
                    }
                    Text("·")
                    Text(Formatters.relativeDate(expense.date))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Formatters.currency(expense.amount, in: expense.currency))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.primary)
                if expense.hasReturn,
                   let returned = expense.amountReturned,
                   let rc = expense.returnedCurrency ?? Optional(expense.currency) {
                    Text("+\(Formatters.currency(returned, in: rc))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Color(hex: "#34C759"))
                }
            }
        }
    }
}
