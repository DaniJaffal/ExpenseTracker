//
//  ExpectedExpensesListView.swift
//  ExpenseTracker
//

import SwiftUI
import SwiftData

struct ExpectedExpensesListView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: [SortDescriptor(\ExpectedExpense.dueDate, order: .forward)])
    private var items: [ExpectedExpense]

    @State private var showingAdd = false

    private var upcoming: [ExpectedExpense] { items.filter { !$0.isPaid } }
    private var paid: [ExpectedExpense] { items.filter { $0.isPaid } }

    var body: some View {
        Group {
            if items.isEmpty {
                EmptyStateView(
                    symbol: "calendar.badge.clock",
                    title: "No expected expenses",
                    message: "Plan loans, bills, or future costs and we'll remind you.",
                    actionTitle: "Add Expected Expense",
                    action: { showingAdd = true }
                )
            } else {
                List {
                    Section("Upcoming") {
                        ForEach(upcoming) { item in
                            NavigationLink {
                                ExpectedExpenseEditorView(item: item)
                            } label: {
                                ExpectedRow(item: item)
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    item.isPaid = true
                                    item.paidDate = Date()
                                    try? context.save()
                                    NotificationService.shared.cancelNotification(for: item)
                                } label: {
                                    Label("Mark Paid", systemImage: "checkmark.circle.fill")
                                }
                                .tint(.green)
                            }
                        }
                    }
                    if !paid.isEmpty {
                        Section("Paid") {
                            ForEach(paid) { item in
                                NavigationLink {
                                    ExpectedExpenseEditorView(item: item)
                                } label: {
                                    ExpectedRow(item: item).opacity(0.6)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Expected")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingAdd = true } label: {
                    Image(systemName: "plus.circle.fill").font(.title3)
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            NavigationStack { ExpectedExpenseEditorView(item: nil) }
        }
    }
}

private struct ExpectedRow: View {
    let item: ExpectedExpense

    var body: some View {
        HStack(spacing: 12) {
            IconBadge(
                symbol: item.category?.iconName ?? "calendar.badge.clock",
                color: Color(hex: item.category?.colorHex ?? "#FF9500")
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.subheadline.weight(.semibold))
                Text("\(item.recurrence.displayName) · Due \(Formatters.relativeDate(item.dueDate))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(Formatters.currency(item.amount, in: item.currency))
                .font(.subheadline.weight(.semibold).monospacedDigit())
        }
        .padding(.vertical, 4)
    }
}
