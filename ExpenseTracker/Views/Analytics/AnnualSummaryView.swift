//
//  AnnualSummaryView.swift
//  ExpenseTracker
//
//  "Year in Review" — pick a year and see a hero card, quick stats, top
//  categories, biggest single expense, top income sources, and a
//  year-over-year comparison when the previous year has data.
//

import SwiftUI
import SwiftData

struct AnnualSummaryView: View {
    @Query(sort: [SortDescriptor(\AppSettings.createdAt, order: .forward)])
    private var settingsList: [AppSettings]

    @Query(sort: [SortDescriptor(\Expense.date, order: .reverse)])
    private var expenses: [Expense]

    @Query(sort: [SortDescriptor(\Income.date, order: .reverse)])
    private var incomes: [Income]

    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())

    private var displayCurrency: Currency { settingsList.first?.defaultCurrency ?? .usd }
    private var rate: Decimal { settingsList.first?.usdToLbpRate ?? 90_000 }

    // MARK: - Year list

    private var availableYears: [Int] {
        let cal = Calendar.current
        var years = Set(expenses.map { cal.component(.year, from: $0.date) })
        years.formUnion(incomes.map { cal.component(.year, from: $0.date) })
        let currentYear = cal.component(.year, from: Date())
        years.insert(currentYear)
        return Array(years).sorted(by: >)
    }

    // MARK: - Year-filtered slices

    private func expenses(in year: Int) -> [Expense] {
        let cal = Calendar.current
        return expenses.filter { cal.component(.year, from: $0.date) == year }
    }

    private func incomes(in year: Int) -> [Income] {
        let cal = Calendar.current
        return incomes.filter { cal.component(.year, from: $0.date) == year }
    }

    private var yearExpenses: [Expense] { expenses(in: selectedYear) }
    private var yearIncomes: [Income]  { incomes(in: selectedYear) }
    private var priorExpenses: [Expense] { expenses(in: selectedYear - 1) }
    private var priorIncomes: [Income]   { incomes(in: selectedYear - 1) }

    private var totalSpent: Decimal {
        yearExpenses.reduce(Decimal(0)) { $0 + BalanceService.netCost(of: $1, in: displayCurrency, usdToLbpRate: rate) }
    }

    private var totalEarned: Decimal {
        yearIncomes.reduce(Decimal(0)) { acc, inc in
            acc + CurrencyService.convert(inc.amount, from: inc.currency, to: displayCurrency, usdToLbpRate: rate)
        }
    }

    private var net: Decimal { totalEarned - totalSpent }

    private var dailyAverage: Decimal {
        let now = Date()
        let cal = Calendar.current
        let isCurrentYear = cal.component(.year, from: now) == selectedYear
        let endOfPeriod: Date = isCurrentYear ? now : (cal.date(from: DateComponents(year: selectedYear, month: 12, day: 31)) ?? now)
        let startOfYear = cal.date(from: DateComponents(year: selectedYear, month: 1, day: 1)) ?? now
        let days = max(1, cal.dateComponents([.day], from: startOfYear, to: endOfPeriod).day ?? 1)
        return totalSpent / Decimal(days)
    }

    // MARK: - Top categories

    private struct CategoryStat: Identifiable {
        let id: UUID
        let name: String
        let iconName: String
        let colorHex: String
        let total: Decimal
    }

    private var topCategories: [CategoryStat] {
        var totals: [UUID: (Decimal, String, String, String)] = [:]
        for exp in yearExpenses {
            guard let cat = exp.category else { continue }
            let value = BalanceService.netCost(of: exp, in: displayCurrency, usdToLbpRate: rate)
            let existing = totals[cat.id] ?? (0, cat.name, cat.iconName, cat.colorHex)
            totals[cat.id] = (existing.0 + value, existing.1, existing.2, existing.3)
        }
        return totals
            .map { CategoryStat(id: $0.key, name: $0.value.1, iconName: $0.value.2, colorHex: $0.value.3, total: $0.value.0) }
            .filter { $0.total > 0 }
            .sorted { $0.total > $1.total }
    }

    // MARK: - Top income sources

    private struct SourceStat: Identifiable {
        let id: UUID
        let name: String
        let iconName: String
        let colorHex: String
        let total: Decimal
    }

    private var topSources: [SourceStat] {
        var totals: [UUID: (Decimal, String, String, String)] = [:]
        for inc in yearIncomes {
            guard let src = inc.source else { continue }
            let value = CurrencyService.convert(inc.amount, from: inc.currency, to: displayCurrency, usdToLbpRate: rate)
            let existing = totals[src.id] ?? (0, src.name, src.iconName, src.colorHex)
            totals[src.id] = (existing.0 + value, existing.1, existing.2, existing.3)
        }
        return totals
            .map { SourceStat(id: $0.key, name: $0.value.1, iconName: $0.value.2, colorHex: $0.value.3, total: $0.value.0) }
            .filter { $0.total > 0 }
            .sorted { $0.total > $1.total }
    }

    // MARK: - Biggest single expense

    private var biggestExpense: Expense? {
        yearExpenses.max { a, b in
            BalanceService.netCost(of: a, in: displayCurrency, usdToLbpRate: rate)
            < BalanceService.netCost(of: b, in: displayCurrency, usdToLbpRate: rate)
        }
    }

    // MARK: - YoY

    private var hasPriorYearData: Bool {
        !priorExpenses.isEmpty || !priorIncomes.isEmpty
    }

    private var priorSpent: Decimal {
        priorExpenses.reduce(Decimal(0)) { $0 + BalanceService.netCost(of: $1, in: displayCurrency, usdToLbpRate: rate) }
    }

    private var priorEarned: Decimal {
        priorIncomes.reduce(Decimal(0)) { acc, inc in
            acc + CurrencyService.convert(inc.amount, from: inc.currency, to: displayCurrency, usdToLbpRate: rate)
        }
    }

    private func deltaPercent(current: Decimal, previous: Decimal) -> Double? {
        guard previous > 0 else { return nil }
        return NSDecimalNumber(decimal: (current - previous) / previous * 100).doubleValue
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                heroCard
                if yearExpenses.isEmpty && yearIncomes.isEmpty {
                    emptyState
                } else {
                    quickStatsGrid
                    if !topCategories.isEmpty {
                        topCategoriesCard
                    }
                    if let biggest = biggestExpense {
                        biggestExpenseCard(expense: biggest)
                    }
                    if !topSources.isEmpty {
                        topSourcesCard
                    }
                    if hasPriorYearData {
                        yearOverYearCard
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Year in Review")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(availableYears, id: \.self) { year in
                        Button {
                            selectedYear = year
                        } label: {
                            if year == selectedYear {
                                Label(String(year), systemImage: "checkmark")
                            } else {
                                Text(String(year))
                            }
                        }
                    }
                } label: {
                    Label(String(selectedYear), systemImage: "calendar.circle")
                }
            }
        }
    }

    // MARK: - Cards

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your \(String(selectedYear))")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
            Text(Formatters.currency(totalSpent, in: displayCurrency))
                .font(.system(size: 40, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text("spent across \(yearExpenses.count) transaction\(yearExpenses.count == 1 ? "" : "s")")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
            HStack(spacing: 6) {
                Image(systemName: net >= 0 ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                Text("Net \(net >= 0 ? "+" : "")\(Formatters.currency(net, in: displayCurrency))")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
            }
            .foregroundStyle(.white)
            .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color(hex: "#4F8EF7"), Color(hex: "#5856D6")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
    }

    private var quickStatsGrid: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                statTile(
                    label: "Spent",
                    value: Formatters.currency(totalSpent, in: displayCurrency),
                    icon: "arrow.up.circle.fill",
                    tint: Color(hex: "#FF3B30")
                )
                statTile(
                    label: "Earned",
                    value: Formatters.currency(totalEarned, in: displayCurrency),
                    icon: "arrow.down.circle.fill",
                    tint: Color(hex: "#34C759")
                )
            }
            HStack(spacing: 10) {
                statTile(
                    label: "Transactions",
                    value: "\(yearExpenses.count + yearIncomes.count)",
                    icon: "list.bullet.rectangle.fill",
                    tint: Color(hex: "#4F8EF7")
                )
                statTile(
                    label: "Avg / day",
                    value: Formatters.currency(dailyAverage, in: displayCurrency),
                    icon: "calendar.circle.fill",
                    tint: Color(hex: "#FF9500")
                )
            }
        }
    }

    private func statTile(label: String, value: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundStyle(tint)
                Text(label).font(.caption).foregroundStyle(.secondary)
            }
            Text(value)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var topCategoriesCard: some View {
        let topAmount = topCategories.first?.total ?? 1
        return VStack(alignment: .leading, spacing: 12) {
            Text("Top categories").font(.headline)
            VStack(spacing: 12) {
                ForEach(topCategories.prefix(5)) { stat in
                    let fraction = NSDecimalNumber(decimal: stat.total / topAmount).doubleValue
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) {
                            IconBadge(symbol: stat.iconName, color: Color(hex: stat.colorHex), size: 28)
                            Text(stat.name).font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(Formatters.currency(stat.total, in: displayCurrency))
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        BudgetProgressBar(
                            fraction: Swift.max(0.04, fraction),
                            tint: Color(hex: stat.colorHex),
                            height: 6
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func biggestExpenseCard(expense: Expense) -> some View {
        let value = BalanceService.netCost(of: expense, in: displayCurrency, usdToLbpRate: rate)
        return HStack(spacing: 12) {
            IconBadge(
                symbol: expense.category?.iconName ?? "tag.fill",
                color: Color(hex: expense.category?.colorHex ?? "#8E8E93"),
                size: 44
            )
            VStack(alignment: .leading, spacing: 2) {
                Text("Biggest single expense")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(expense.note.isEmpty ? (expense.category?.name ?? "Expense") : expense.note)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(Formatters.date(expense.date))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(Formatters.currency(value, in: displayCurrency))
                .font(.title3.weight(.bold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var topSourcesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top income sources").font(.headline)
            VStack(spacing: 8) {
                ForEach(topSources.prefix(4)) { stat in
                    HStack(spacing: 10) {
                        IconBadge(symbol: stat.iconName, color: Color(hex: stat.colorHex), size: 28)
                        Text(stat.name).font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(Formatters.currency(stat.total, in: displayCurrency))
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(Color(hex: "#34C759"))
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var yearOverYearCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("vs \(String(selectedYear - 1))").font(.headline)
            HStack(spacing: 10) {
                yoyTile(
                    label: "Spent",
                    current: totalSpent,
                    previous: priorSpent,
                    isExpense: true
                )
                yoyTile(
                    label: "Earned",
                    current: totalEarned,
                    previous: priorEarned,
                    isExpense: false
                )
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func yoyTile(label: String, current: Decimal, previous: Decimal, isExpense: Bool) -> some View {
        let delta = deltaPercent(current: current, previous: previous)
        return VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(Formatters.currency(current, in: displayCurrency))
                .font(.subheadline.weight(.bold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            HStack {
                Text("was \(Formatters.currency(previous, in: displayCurrency))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                if let delta {
                    deltaChip(value: delta, isExpense: isExpense)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// Color rules for expense delta: up = red. Income delta: up = green.
    private func deltaChip(value: Double, isExpense: Bool) -> some View {
        let isUp = value > 0
        let isGood = isExpense ? !isUp : isUp
        let tint = abs(value) < 0.5
            ? Color.secondary
            : (isGood ? Color(hex: "#34C759") : Color(hex: "#FF3B30"))
        let pct = Int(value.rounded())
        let sign = pct > 0 ? "+" : ""
        return HStack(spacing: 3) {
            Image(systemName: isUp ? "arrow.up.right" : "arrow.down.right")
                .font(.caption2.weight(.bold))
            Text("\(sign)\(pct)%")
                .font(.caption2.weight(.bold).monospacedDigit())
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(tint.opacity(0.16))
        .foregroundStyle(tint)
        .clipShape(Capsule())
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("No data for \(String(selectedYear))")
                .font(.subheadline.weight(.semibold))
            Text("Add some transactions or pick a different year.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
