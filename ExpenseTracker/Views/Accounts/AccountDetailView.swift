//
//  AccountDetailView.swift
//  ExpenseTracker
//
//  Per-account screen showing the full chronological activity feed for one
//  account: expenses, payment legs, refunds received, transfers in and out.
//  Reached by tapping an account card on the Dashboard or a row in the
//  Accounts list.
//

import SwiftUI
import SwiftData
import Charts

struct AccountDetailView: View {
    @Environment(\.modelContext) private var context

    let account: Account

    @Query(sort: [SortDescriptor(\AppSettings.createdAt, order: .forward)])
    private var settingsList: [AppSettings]

    @State private var editingExpense: Expense?
    @State private var editingIncome: Income?
    @State private var showingEditAccount = false
    @State private var trendRangeDays: Int = 30

    private var rate: Decimal { settingsList.first?.usdToLbpRate ?? 90_000 }

    private var currentBalance: Decimal {
        BalanceService.currentBalance(for: account, usdToLbpRate: rate)
    }

    // MARK: - Activities

    private var activities: [AccountActivity] {
        var items: [AccountActivity] = []

        // Expenses sourced from this account → outflow.
        for expense in account.expenses ?? [] {
            let amountInAcc = CurrencyService.convert(
                expense.amount,
                from: expense.currency,
                to: account.currency,
                usdToLbpRate: CurrencyService.effectiveRate(
                    override: expense.exchangeRateOverride,
                    settingsRate: rate
                )
            )
            items.append(AccountActivity(
                id: "exp-\(expense.id.uuidString)",
                date: expense.date,
                kind: .expense,
                title: expense.note.isEmpty ? (expense.category?.name ?? "Expense") : expense.note,
                subtitle: subtitleForExpense(expense),
                signedAmount: -amountInAcc,
                currency: account.currency,
                expense: expense
            ))

            // If the return for this expense lands back in this same account, add a separate inflow row.
            if let returned = expense.amountReturned, returned > 0,
               (expense.returnedToAccount == nil || expense.returnedToAccount?.id == account.id) {
                let returnedCurrency = expense.returnedCurrency ?? expense.currency
                let returnRate = CurrencyService.effectiveRate(
                    override: expense.returnedExchangeRateOverride ?? expense.exchangeRateOverride,
                    settingsRate: rate
                )
                let inflow = CurrencyService.convert(
                    returned,
                    from: returnedCurrency,
                    to: account.currency,
                    usdToLbpRate: returnRate
                )
                items.append(AccountActivity(
                    id: "exp-return-\(expense.id.uuidString)",
                    date: expense.date,
                    kind: .returnReceived,
                    title: "Refund — \(expense.note.isEmpty ? (expense.category?.name ?? "Expense") : expense.note)",
                    subtitle: "Returned to this account",
                    signedAmount: inflow,
                    currency: account.currency,
                    expense: expense
                ))
            }
        }

        // Expenses where THIS account received the return (and isn't the source).
        for expense in account.expenseReturnsReceived ?? [] {
            if expense.account?.id == account.id { continue }
            guard let returned = expense.amountReturned, returned > 0 else { continue }
            let returnedCurrency = expense.returnedCurrency ?? expense.currency
            let returnRate = CurrencyService.effectiveRate(
                override: expense.returnedExchangeRateOverride ?? expense.exchangeRateOverride,
                settingsRate: rate
            )
            let inflow = CurrencyService.convert(
                returned,
                from: returnedCurrency,
                to: account.currency,
                usdToLbpRate: returnRate
            )
            items.append(AccountActivity(
                id: "ret-primary-\(expense.id.uuidString)",
                date: expense.date,
                kind: .returnReceived,
                title: "Refund — \(expense.note.isEmpty ? (expense.category?.name ?? "Expense") : expense.note)",
                subtitle: "From \(expense.account?.name ?? "expense")",
                signedAmount: inflow,
                currency: account.currency,
                expense: expense
            ))
        }

        // Additional payment legs that drew from this account → outflow.
        for leg in account.paymentLegs ?? [] {
            guard let parent = leg.expense else { continue }
            let legRate = CurrencyService.effectiveRate(
                override: parent.exchangeRateOverride,
                settingsRate: rate
            )
            let outflow = CurrencyService.convert(
                leg.amount,
                from: leg.currency,
                to: account.currency,
                usdToLbpRate: legRate
            )
            items.append(AccountActivity(
                id: "pleg-\(leg.id.uuidString)",
                date: parent.date,
                kind: .paymentLeg,
                title: parent.note.isEmpty ? (parent.category?.name ?? "Split payment") : parent.note,
                subtitle: "Split payment · \(parent.category?.name ?? "Expense")",
                signedAmount: -outflow,
                currency: account.currency,
                expense: parent
            ))
        }

        // Additional return legs received → inflow.
        for leg in account.returnLegsReceived ?? [] {
            guard let parent = leg.expense else { continue }
            let legRate = CurrencyService.effectiveRate(
                override: parent.returnedExchangeRateOverride ?? parent.exchangeRateOverride,
                settingsRate: rate
            )
            let inflow = CurrencyService.convert(
                leg.amount,
                from: leg.currency,
                to: account.currency,
                usdToLbpRate: legRate
            )
            items.append(AccountActivity(
                id: "rleg-\(leg.id.uuidString)",
                date: parent.date,
                kind: .returnReceived,
                title: "Refund — \(parent.note.isEmpty ? (parent.category?.name ?? "Expense") : parent.note)",
                subtitle: "Split refund · From \(parent.account?.name ?? "expense")",
                signedAmount: inflow,
                currency: account.currency,
                expense: parent
            ))
        }

        // Transfers out → outflow.
        for transfer in account.transfersOut ?? [] {
            items.append(AccountActivity(
                id: "txo-\(transfer.id.uuidString)",
                date: transfer.date,
                kind: .transferOut,
                title: "Transfer to \(transfer.toAccount?.name ?? "—")",
                subtitle: transfer.note.isEmpty ? "Transfer" : transfer.note,
                signedAmount: -transfer.amount,
                currency: account.currency,
                expense: nil
            ))
        }

        // Incomes credited to this account → inflow.
        for income in account.incomes ?? [] {
            let incomeRate = CurrencyService.effectiveRate(
                override: income.exchangeRateOverride,
                settingsRate: rate
            )
            let amountInAcc = CurrencyService.convert(
                income.amount,
                from: income.currency,
                to: account.currency,
                usdToLbpRate: incomeRate
            )
            items.append(AccountActivity(
                id: "inc-\(income.id.uuidString)",
                date: income.date,
                kind: .income,
                title: income.note.isEmpty ? (income.source?.name ?? "Income") : income.note,
                subtitle: income.source?.name ?? "Income",
                signedAmount: amountInAcc,
                currency: account.currency,
                expense: nil,
                income: income
            ))
        }

        // Transfers in → inflow.
        for transfer in account.transfersIn ?? [] {
            let inflowAmount: Decimal
            if let explicit = transfer.receivedAmount {
                inflowAmount = explicit
            } else if let from = transfer.fromAccount {
                let r = CurrencyService.effectiveRate(
                    override: transfer.exchangeRateOverride,
                    settingsRate: rate
                )
                inflowAmount = CurrencyService.convert(
                    transfer.amount,
                    from: from.currency,
                    to: account.currency,
                    usdToLbpRate: r
                )
            } else {
                inflowAmount = transfer.amount
            }
            items.append(AccountActivity(
                id: "txi-\(transfer.id.uuidString)",
                date: transfer.date,
                kind: .transferIn,
                title: "From \(transfer.fromAccount?.name ?? "—")",
                subtitle: transfer.note.isEmpty ? "Transfer" : transfer.note,
                signedAmount: inflowAmount,
                currency: account.currency,
                expense: nil
            ))
        }

        return items.sorted { $0.date > $1.date }
    }

    private func subtitleForExpense(_ exp: Expense) -> String {
        let categoryName = exp.category?.name ?? "Uncategorized"
        if !(exp.additionalPayments ?? []).isEmpty {
            return "Split payment · \(categoryName)"
        }
        return categoryName
    }

    private var grouped: [(key: Date, value: [AccountActivity])] {
        let dict = Dictionary(grouping: activities) { a in
            Calendar.current.startOfDay(for: a.date)
        }
        return dict.sorted { $0.key > $1.key }
    }

    // MARK: - Trend

    private struct TrendPoint: Identifiable {
        let id = UUID()
        let date: Date
        let balance: Decimal
    }

    /// Daily balance samples covering the last `trendRangeDays` days.
    /// For year-long ranges we sample weekly to keep the chart performant.
    private var trendPoints: [TrendPoint] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let start = cal.date(byAdding: .day, value: -(trendRangeDays - 1), to: today) else { return [] }

        // Weekly sampling for the 1-year range, daily otherwise.
        let stride = trendRangeDays > 90 ? 7 : 1
        var points: [TrendPoint] = []
        var cursor = start
        while cursor <= today {
            // End-of-day cutoff so all activities on that day are included.
            let endOfDay = cal.date(byAdding: .day, value: 1, to: cursor)?.addingTimeInterval(-1) ?? cursor
            let balance = BalanceService.balance(for: account, on: endOfDay, usdToLbpRate: rate)
            points.append(TrendPoint(date: cursor, balance: balance))
            cursor = cal.date(byAdding: .day, value: stride, to: cursor) ?? today.addingTimeInterval(1)
        }
        return points
    }

    private var trendMin: Decimal {
        trendPoints.map(\.balance).min() ?? 0
    }

    private var trendMax: Decimal {
        trendPoints.map(\.balance).max() ?? 1
    }

    // MARK: - MTD stats

    private var mtdInflow: Decimal {
        let monthStart = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
        return activities
            .filter { $0.date >= monthStart && $0.signedAmount > 0 }
            .reduce(Decimal(0)) { $0 + $1.signedAmount }
    }

    private var mtdOutflow: Decimal {
        let monthStart = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
        return activities
            .filter { $0.date >= monthStart && $0.signedAmount < 0 }
            .reduce(Decimal(0)) { $0 + (-$1.signedAmount) }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                mtdCard
                trendCard
                activityList
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(account.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingEditAccount = true
                } label: {
                    Image(systemName: "pencil")
                }
            }
        }
        .sheet(isPresented: $showingEditAccount) {
            NavigationStack { AccountEditorView(account: account) }
        }
        .sheet(item: $editingExpense) { expense in
            NavigationStack { ExpenseEditorView(expense: expense) }
        }
        .sheet(item: $editingIncome) { inc in
            IncomeEditorView(income: inc)
        }
    }

    // MARK: - Subviews

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.white.opacity(0.2))
                    Image(systemName: account.iconName)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.name)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("\(account.type.displayName) · \(account.currency.displayCode)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
            }

            Text("Current balance")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.85))

            Text(Formatters.currency(currentBalance, in: account.currency))
                .font(.system(size: 32, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color(hex: account.colorHex),
                    Color(hex: account.colorHex).opacity(0.65)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
    }

    private var mtdCard: some View {
        HStack(spacing: 12) {
            mtdTile(
                title: "In this month",
                value: Formatters.currency(mtdInflow, in: account.currency),
                symbol: "arrow.down.left.circle.fill",
                tint: Color(hex: "#34C759")
            )
            mtdTile(
                title: "Out this month",
                value: Formatters.currency(mtdOutflow, in: account.currency),
                symbol: "arrow.up.right.circle.fill",
                tint: Color(hex: "#FF3B30")
            )
        }
    }

    private func mtdTile(title: String, value: String, symbol: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: symbol).foregroundStyle(tint)
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
            Text(value)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var trendCard: some View {
        let tint = Color(hex: account.colorHex)
        let points = trendPoints
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Balance trend").font(.headline)
                Spacer()
                Picker("Range", selection: $trendRangeDays) {
                    Text("7d").tag(7)
                    Text("30d").tag(30)
                    Text("90d").tag(90)
                    Text("1y").tag(365)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }

            if points.isEmpty {
                Text("No data in this range yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                Chart(points) { point in
                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Balance", NSDecimalNumber(decimal: point.balance).doubleValue)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [tint.opacity(0.35), tint.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.monotone)

                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Balance", NSDecimalNumber(decimal: point.balance).doubleValue)
                    )
                    .foregroundStyle(tint)
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round))
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine().foregroundStyle(Color.secondary.opacity(0.15))
                        AxisValueLabel().font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine().foregroundStyle(Color.secondary.opacity(0.15))
                        AxisValueLabel().font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .frame(height: 170)

                HStack {
                    rangeStatTile(
                        label: "Low",
                        value: Formatters.currency(trendMin, in: account.currency),
                        tint: Color(hex: "#FF3B30")
                    )
                    rangeStatTile(
                        label: "High",
                        value: Formatters.currency(trendMax, in: account.currency),
                        tint: Color(hex: "#34C759")
                    )
                    rangeStatTile(
                        label: "Now",
                        value: Formatters.currency(currentBalance, in: account.currency),
                        tint: tint
                    )
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func rangeStatTile(label: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var activityList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Activity")
                .font(.headline)
                .padding(.top, 4)
            if activities.isEmpty {
                Text("No activity in this account yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                ForEach(grouped, id: \.key) { day, items in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(Formatters.date(day, style: .full))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                        VStack(spacing: 0) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                ActivityRow(item: item) {
                                    if let exp = item.expense {
                                        editingExpense = exp
                                    } else if let inc = item.income {
                                        editingIncome = inc
                                    }
                                }
                                if index != items.count - 1 {
                                    Divider().padding(.leading, 60)
                                }
                            }
                        }
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
        }
    }
}

// MARK: - Activity model

private struct AccountActivity: Identifiable {
    let id: String
    let date: Date
    let kind: Kind
    let title: String
    let subtitle: String
    /// Signed in the account's own currency. Positive = inflow, negative = outflow.
    let signedAmount: Decimal
    let currency: Currency
    /// If set, tapping the row opens the expense editor for this expense.
    let expense: Expense?
    /// If set, tapping the row opens the income editor for this income.
    let income: Income?

    init(
        id: String,
        date: Date,
        kind: Kind,
        title: String,
        subtitle: String,
        signedAmount: Decimal,
        currency: Currency,
        expense: Expense? = nil,
        income: Income? = nil
    ) {
        self.id = id
        self.date = date
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.signedAmount = signedAmount
        self.currency = currency
        self.expense = expense
        self.income = income
    }

    enum Kind {
        case expense
        case paymentLeg
        case returnReceived
        case income
        case transferOut
        case transferIn
    }

    var iconName: String {
        switch kind {
        case .expense, .paymentLeg: return "arrow.up.right"
        case .returnReceived:       return "arrow.uturn.left"
        case .income:               return "arrow.down.left.circle.fill"
        case .transferOut:          return "arrow.up.right"
        case .transferIn:           return "arrow.down.left"
        }
    }

    var color: Color {
        switch kind {
        case .expense, .paymentLeg: return Color(hex: "#FF3B30")
        case .returnReceived:       return Color(hex: "#34C759")
        case .income:               return Color(hex: "#34C759")
        case .transferOut:          return Color(hex: "#FF9500")
        case .transferIn:           return Color(hex: "#0A84FF")
        }
    }

    var isTappable: Bool { expense != nil || income != nil }
}

// MARK: - Activity row

private struct ActivityRow: View {
    let item: AccountActivity
    let onTap: () -> Void

    var body: some View {
        Button(action: { if item.isTappable { onTap() } }) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(item.color.opacity(0.16))
                    Image(systemName: item.iconName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(item.color)
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(Formatters.currency(item.signedAmount, in: item.currency, sign: true))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(item.signedAmount >= 0 ? Color(hex: "#34C759") : .primary)
            }
            .padding(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!item.isTappable)
    }
}
