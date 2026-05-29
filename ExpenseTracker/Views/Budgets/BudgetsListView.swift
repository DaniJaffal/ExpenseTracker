//
//  BudgetsListView.swift
//  ExpenseTracker
//
//  List of all budgets with their month-to-date progress.
//

import SwiftUI
import SwiftData

struct BudgetsListView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: [SortDescriptor(\Budget.createdAt, order: .reverse)])
    private var budgets: [Budget]

    @Query(sort: [SortDescriptor(\AppSettings.createdAt, order: .forward)])
    private var settingsList: [AppSettings]

    @State private var editing: Budget?
    @State private var showingAdd = false

    private var displayCurrency: Currency { settingsList.first?.defaultCurrency ?? .usd }
    private var rate: Decimal { settingsList.first?.usdToLbpRate ?? 90_000 }

    private var progressList: [BudgetProgress] {
        BudgetService.progressList(
            budgets: budgets,
            in: displayCurrency,
            usdToLbpRate: rate
        )
    }

    var body: some View {
        Group {
            if budgets.isEmpty {
                EmptyStateView(
                    symbol: "chart.bar.doc.horizontal",
                    title: "No budgets yet",
                    message: "Set a monthly cap for any category to keep your spending in check.",
                    actionTitle: "Add Budget",
                    action: { showingAdd = true }
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        summaryRow
                        VStack(spacing: 12) {
                            ForEach(progressList, id: \.budget.id) { item in
                                BudgetCardLarge(item: item)
                                    .onTapGesture { editing = item.budget }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            delete(item.budget)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .background(Color(.systemGroupedBackground))
            }
        }
        .navigationTitle("Budgets")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingAdd = true } label: {
                    Image(systemName: "plus.circle.fill").font(.title3)
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            NavigationStack { BudgetEditorView(budget: nil) }
        }
        .sheet(item: $editing) { budget in
            NavigationStack { BudgetEditorView(budget: budget) }
        }
    }

    private var summaryRow: some View {
        let totalCap = progressList.reduce(Decimal(0)) { $0 + $1.cap }
        let totalSpent = progressList.reduce(Decimal(0)) { $0 + $1.spent }
        let overCount = progressList.filter { $0.status == .over }.count
        let warnCount = progressList.filter { $0.status == .warning }.count

        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("This month")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(Formatters.currency(totalSpent, in: displayCurrency))
                    .font(.title3.weight(.bold).monospacedDigit())
                Text("of \(Formatters.currency(totalCap, in: displayCurrency))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                if overCount > 0 {
                    Label("\(overCount) over", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(hex: "#FF3B30"))
                }
                if warnCount > 0 {
                    Label("\(warnCount) near limit", systemImage: "exclamationmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(hex: "#FF9500"))
                }
                if overCount == 0 && warnCount == 0 {
                    Label("On track", systemImage: "checkmark.seal.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(hex: "#34C759"))
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func delete(_ budget: Budget) {
        context.delete(budget)
        try? context.save()
        WidgetRefresh.bump()
    }
}

// MARK: - Large card

struct BudgetCardLarge: View {
    let item: BudgetProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                IconBadge(symbol: item.categoryIcon, color: Color(hex: item.categoryColor))
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.categoryName)
                        .font(.subheadline.weight(.semibold))
                    Text("\(Formatters.currency(item.spent, in: item.currency)) of \(Formatters.currency(item.cap, in: item.currency))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(percentText)
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(item.tintColor)
            }
            BudgetProgressBar(fraction: item.fraction, tint: item.tintColor, height: 8)

            if item.status == .over {
                Text("Over by \(Formatters.currency(item.spent - item.cap, in: item.currency))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(hex: "#FF3B30"))
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var percentText: String {
        let rounded = Int(item.percentRaw.rounded())
        return "\(rounded)%"
    }
}
