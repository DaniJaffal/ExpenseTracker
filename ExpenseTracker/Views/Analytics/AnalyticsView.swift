//
//  AnalyticsView.swift
//  ExpenseTracker
//
//  Spending breakdowns by category, by month, and by account using Swift Charts.
//

import SwiftUI
import SwiftData
import Charts

struct AnalyticsView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: [SortDescriptor(\AppSettings.createdAt, order: .forward)])
    private var settingsList: [AppSettings]

    @Query(sort: [SortDescriptor(\Expense.date, order: .reverse)])
    private var expenses: [Expense]

    @Query(filter: #Predicate<Account> { !$0.isArchived })
    private var accounts: [Account]

    @State private var displayCurrency: Currency = .usd
    @State private var rangeDays: Int = 30
    @State private var compareEnabled: Bool = false

    private var rate: Decimal { settingsList.first?.usdToLbpRate ?? 90_000 }

    private var rangeStart: Date {
        Calendar.current.date(byAdding: .day, value: -rangeDays, to: Date()) ?? Date()
    }

    /// Start of the previous-period window (`2 × rangeDays` ago).
    private var previousRangeStart: Date {
        Calendar.current.date(byAdding: .day, value: -2 * rangeDays, to: Date()) ?? Date()
    }

    private var filtered: [Expense] {
        expenses.filter { $0.date >= rangeStart }
    }

    /// Expenses falling into the previous-period window.
    private var previousFiltered: [Expense] {
        expenses.filter { $0.date >= previousRangeStart && $0.date < rangeStart }
    }

    // Aggregates

    private struct CategorySlice: Identifiable {
        let id = UUID()
        let name: String
        let color: Color
        let total: Decimal
    }

    private var byCategory: [CategorySlice] {
        var totals: [String: (Decimal, String)] = [:]
        for exp in filtered {
            let key = exp.category?.name ?? "Uncategorized"
            let color = exp.category?.colorHex ?? "#8E8E93"
            let value = BalanceService.netCost(of: exp, in: displayCurrency, usdToLbpRate: rate)
            let (curTotal, _) = totals[key] ?? (Decimal(0), color)
            totals[key] = (curTotal + value, color)
        }
        return totals
            .map { CategorySlice(name: $0.key, color: Color(hex: $0.value.1), total: $0.value.0) }
            .filter { $0.total > 0 }
            .sorted { $0.total > $1.total }
    }

    private struct DailyPoint: Identifiable {
        let id = UUID()
        let date: Date
        let total: Decimal
    }

    private var byDay: [DailyPoint] {
        let cal = Calendar.current
        var totals: [Date: Decimal] = [:]
        for exp in filtered {
            let day = cal.startOfDay(for: exp.date)
            let value = BalanceService.netCost(of: exp, in: displayCurrency, usdToLbpRate: rate)
            totals[day, default: 0] += value
        }
        return totals
            .map { DailyPoint(date: $0.key, total: $0.value) }
            .sorted { $0.date < $1.date }
    }

    private struct AccountSlice: Identifiable {
        let id = UUID()
        let name: String
        let color: Color
        let total: Decimal
    }

    private var byAccount: [AccountSlice] {
        var totals: [UUID: (Decimal, String, String)] = [:] // total, name, color
        for exp in filtered {
            guard let acc = exp.account else { continue }
            let value = BalanceService.netCost(of: exp, in: displayCurrency, usdToLbpRate: rate)
            let existing = totals[acc.id] ?? (Decimal(0), acc.name, acc.colorHex)
            totals[acc.id] = (existing.0 + value, acc.name, acc.colorHex)
        }
        return totals.values
            .map { AccountSlice(name: $0.1, color: Color(hex: $0.2), total: $0.0) }
            .filter { $0.total > 0 }
            .sorted { $0.total > $1.total }
    }

    private var totalSpend: Decimal {
        filtered.reduce(Decimal(0)) { $0 + BalanceService.netCost(of: $1, in: displayCurrency, usdToLbpRate: rate) }
    }

    // MARK: - Previous-period aggregates (for comparison mode)

    private var previousTotalSpend: Decimal {
        previousFiltered.reduce(Decimal(0)) { $0 + BalanceService.netCost(of: $1, in: displayCurrency, usdToLbpRate: rate) }
    }

    /// Previous-period spend by category name. Used to compute per-row deltas.
    private var previousByCategory: [String: Decimal] {
        var totals: [String: Decimal] = [:]
        for exp in previousFiltered {
            let key = exp.category?.name ?? "Uncategorized"
            let value = BalanceService.netCost(of: exp, in: displayCurrency, usdToLbpRate: rate)
            totals[key, default: 0] += value
        }
        return totals
    }

    /// Signed percentage change vs the previous-period value, capped to ±999%.
    /// Returns nil when there's no meaningful previous value to compare to.
    private func deltaPercent(current: Decimal, previous: Decimal) -> Double? {
        guard previous > 0 else { return nil }
        let pct = NSDecimalNumber(decimal: (current - previous) / previous * 100).doubleValue
        return max(-999, min(999, pct))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                rangePicker
                compareToggleRow
                summaryHeader

                if filtered.isEmpty {
                    Text("No expenses in this range yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 40)
                } else {
                    dailyChartCard
                    categoryChartCard
                    if !byAccount.isEmpty {
                        accountChartCard
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Analytics")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Currency", selection: $displayCurrency) {
                        ForEach(Currency.allCases) { c in
                            Text(c.displayCode).tag(c)
                        }
                    }
                } label: {
                    Label(displayCurrency.displayCode, systemImage: "arrow.left.arrow.right.circle")
                }
            }
        }
        .onAppear {
            if let s = settingsList.first { displayCurrency = s.defaultCurrency }
        }
    }

    // MARK: - Sections

    private var rangePicker: some View {
        Picker("Range", selection: $rangeDays) {
            Text("7d").tag(7)
            Text("30d").tag(30)
            Text("90d").tag(90)
            Text("1y").tag(365)
        }
        .pickerStyle(.segmented)
    }

    private var compareToggleRow: some View {
        Toggle(isOn: $compareEnabled) {
            Label("Compare to previous \(rangeDays) days", systemImage: "arrow.left.arrow.right")
                .font(.subheadline)
        }
        .toggleStyle(.switch)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var summaryHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Total spend (last \(rangeDays) days)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(Formatters.currency(totalSpend, in: displayCurrency))
                    .font(.system(size: 32, weight: .bold, design: .rounded).monospacedDigit())
                if compareEnabled, let delta = deltaPercent(current: totalSpend, previous: previousTotalSpend) {
                    DeltaPill(value: delta)
                }
            }
            if compareEnabled {
                Text("Previous: \(Formatters.currency(previousTotalSpend, in: displayCurrency))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var dailyChartCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Daily spend").font(.headline)
            Chart(byDay) { point in
                BarMark(
                    x: .value("Day", point.date, unit: .day),
                    y: .value("Spend", NSDecimalNumber(decimal: point.total).doubleValue)
                )
                .foregroundStyle(Color(hex: "#4F8EF7"))
            }
            .frame(height: 200)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var categoryChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("By category").font(.headline)
            Chart(byCategory) { slice in
                SectorMark(
                    angle: .value("Spend", NSDecimalNumber(decimal: slice.total).doubleValue),
                    innerRadius: .ratio(0.6),
                    angularInset: 1.5
                )
                .foregroundStyle(slice.color)
                .annotation(position: .overlay, alignment: .center) {
                    EmptyView()
                }
            }
            .frame(height: 220)

            VStack(spacing: 8) {
                ForEach(byCategory) { slice in
                    let previous = previousByCategory[slice.name] ?? 0
                    let delta = compareEnabled
                        ? deltaPercent(current: slice.total, previous: previous)
                        : nil
                    HStack(spacing: 8) {
                        Circle().fill(slice.color).frame(width: 10, height: 10)
                        Text(slice.name).font(.subheadline)
                        Spacer()
                        if let delta {
                            DeltaPill(value: delta, compact: true)
                        }
                        Text(Formatters.currency(slice.total, in: displayCurrency))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    if compareEnabled {
                        HStack {
                            Spacer()
                            Text("Previous: \(Formatters.currency(previous, in: displayCurrency))")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var accountChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("By account").font(.headline)
            Chart(byAccount) { slice in
                BarMark(
                    x: .value("Spend", NSDecimalNumber(decimal: slice.total).doubleValue),
                    y: .value("Account", slice.name)
                )
                .foregroundStyle(slice.color)
            }
            .frame(height: CGFloat(byAccount.count * 40 + 40))
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Delta pill

/// Small ± pill used in comparison mode. Up = red (spending more), down = green.
private struct DeltaPill: View {
    let value: Double
    var compact: Bool = false

    private var isUp: Bool { value > 0 }
    private var tint: Color {
        if abs(value) < 0.5 { return Color.secondary }
        return isUp ? Color(hex: "#FF3B30") : Color(hex: "#34C759")
    }

    var body: some View {
        let pct = Int(value.rounded())
        let sign = pct > 0 ? "+" : ""
        HStack(spacing: 3) {
            Image(systemName: isUp ? "arrow.up.right" : "arrow.down.right")
                .font(.caption2.weight(.bold))
            Text("\(sign)\(pct)%")
                .font(compact ? .caption2.weight(.bold) : .caption.weight(.bold))
                .monospacedDigit()
        }
        .padding(.horizontal, compact ? 6 : 8)
        .padding(.vertical, compact ? 2 : 4)
        .background(tint.opacity(0.16))
        .foregroundStyle(tint)
        .clipShape(Capsule())
    }
}
