//
//  DashboardView.swift
//  ExpenseTracker
//
//  Home tab — total balance, account cards, recent activity, upcoming items.
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: [SortDescriptor(\AppSettings.createdAt, order: .forward)])
    private var settingsList: [AppSettings]

    @Query(filter: #Predicate<Account> { !$0.isArchived },
           sort: [SortDescriptor(\Account.sortOrder), SortDescriptor(\Account.name)])
    private var accounts: [Account]

    @Query(sort: [SortDescriptor(\Expense.date, order: .reverse)])
    private var allExpenses: [Expense]

    @Query(sort: [SortDescriptor(\Income.date, order: .reverse)])
    private var allIncomes: [Income]

    @Query(filter: #Predicate<Subscription> { $0.isActive },
           sort: [SortDescriptor(\Subscription.nextRenewalDate, order: .forward)])
    private var subscriptions: [Subscription]

    @Query(filter: #Predicate<ExpectedExpense> { !$0.isPaid },
           sort: [SortDescriptor(\ExpectedExpense.dueDate, order: .forward)])
    private var expectedExpenses: [ExpectedExpense]

    @Query(sort: [SortDescriptor(\Budget.createdAt, order: .reverse)])
    private var budgets: [Budget]

    @Query(sort: [SortDescriptor(\SavingsGoal.sortOrder), SortDescriptor(\SavingsGoal.createdAt)])
    private var savingsGoals: [SavingsGoal]

    @Query(sort: [SortDescriptor(\ExpenseTemplate.createdAt)])
    private var allTemplates: [ExpenseTemplate]

    @State private var displayCurrency: Currency = .usd
    @State private var showingAddExpense = false
    @State private var showingAddIncome = false
    @State private var showingTemplatePicker = false
    @State private var pendingTemplate: ExpenseTemplate?
    @State private var editingExpense: Expense?
    @State private var editingIncome: Income?

    private var settings: AppSettings? { settingsList.first }

    private var rate: Decimal { settings?.usdToLbpRate ?? 90_000 }

    private var totalBalance: Decimal {
        BalanceService.totalBalance(accounts: accounts, in: displayCurrency, usdToLbpRate: rate)
    }

    private var monthSpend: Decimal {
        let cal = Calendar.current
        let startOfMonth = cal.dateInterval(of: .month, for: Date())?.start ?? Date()
        return allExpenses
            .filter { $0.date >= startOfMonth }
            .reduce(Decimal(0)) { acc, exp in
                acc + BalanceService.netCost(of: exp, in: displayCurrency, usdToLbpRate: rate)
            }
    }

    /// End-of-period cutoff used by the "available balance" line.
    /// • If the user set a payday day in Settings, this is the last instant of
    ///   the day BEFORE the next occurrence of that day-of-month. (So on
    ///   payday itself, the cutoff is "yesterday" and the line resets.)
    /// • Otherwise, the last instant of the current calendar month.
    private var availableCutoff: Date {
        let cal = Calendar.current
        let today = Date()
        if let day = settings?.paydayDayOfMonth, (1...31).contains(day) {
            var comps = DateComponents()
            comps.day = day
            // matchingPolicy: .nextTime gracefully clamps to the last day of
            // months that don't contain the requested day (e.g. 31 → Feb 28).
            let nextPayday = cal.nextDate(
                after: today,
                matching: comps,
                matchingPolicy: .nextTimePreservingSmallerComponents
            ) ?? today
            let startOfPayday = cal.startOfDay(for: nextPayday)
            // One second before the start of payday = end of the day before.
            return startOfPayday.addingTimeInterval(-1)
        }
        return cal.dateInterval(of: .month, for: today)?.end ?? today
    }

    /// Human label for `availableCutoff`, used in the dashboard summary.
    /// "this month" in end-of-month mode; "before payday (Jun 28)" otherwise.
    private var cutoffDescription: String {
        if settings?.paydayDayOfMonth != nil {
            // availableCutoff is the day before payday; show payday itself.
            let payday = availableCutoff.addingTimeInterval(1)
            return "before payday (\(Formatters.date(payday, style: .medium)))"
        }
        return "this month"
    }

    /// Sum of forward-looking money that's already committed before
    /// `availableCutoff`: unpaid expected expenses + subscriptions renewing
    /// on or before the cutoff. Includes anything overdue but still unpaid.
    private var committedUntilCutoff: Decimal {
        var total: Decimal = 0
        let cutoff = availableCutoff

        for exp in expectedExpenses where exp.dueDate <= cutoff {
            total += CurrencyService.convert(
                exp.amount,
                from: exp.currency,
                to: displayCurrency,
                usdToLbpRate: rate
            )
        }
        for sub in subscriptions where sub.nextRenewalDate <= cutoff {
            total += CurrencyService.convert(
                sub.amount,
                from: sub.currency,
                to: displayCurrency,
                usdToLbpRate: rate
            )
        }
        return total
    }

    /// Total balance after subtracting what's already committed before the
    /// cutoff. Can go negative when committed > balance.
    private var availableBalance: Decimal {
        totalBalance - committedUntilCutoff
    }

    private var recentExpenses: [Expense] {
        Array(allExpenses.prefix(5))
    }

    /// Unified recent transactions: latest 5 across both expenses and incomes.
    private var recentTransactions: [TransactionItem] {
        let expenses = allExpenses.map { TransactionItem(expense: $0) }
        let incomes = allIncomes.map { TransactionItem(income: $0) }
        return (expenses + incomes)
            .sorted { $0.date > $1.date }
            .prefix(5)
            .map { $0 }
    }

    private var upcomingSubs: [Subscription] {
        let cutoff = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
        return subscriptions.filter { $0.nextRenewalDate <= cutoff }.prefix(3).map { $0 }
    }

    private var upcomingExpected: [ExpectedExpense] {
        let cutoff = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
        return expectedExpenses.filter { $0.dueDate <= cutoff }.prefix(3).map { $0 }
    }

    /// Auto-generated insight cards for the current month.
    private var insights: [Insight] {
        InsightService.generate(
            expenses: allExpenses,
            incomes: allIncomes,
            budgets: budgets,
            subscriptions: subscriptions,
            displayCurrency: displayCurrency,
            usdToLbpRate: rate
        )
    }

    /// Top three budgets by spend percentage. Shown on the dashboard strip.
    private var topBudgets: [BudgetProgress] {
        let list = BudgetService.progressList(
            budgets: budgets,
            in: displayCurrency,
            usdToLbpRate: rate
        )
        return Array(list.prefix(3))
    }

    /// Active goals (not yet completed), sorted by progress descending.
    /// Limited to a small number for the dashboard strip.
    private var dashboardGoals: [SavingsGoal] {
        savingsGoals
            .filter { !$0.isComplete }
            .sorted { $0.fraction > $1.fraction }
            .prefix(4)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    summaryCard
                    accountsSection
                    monthSection
                    let insightItems = insights
                    if !insightItems.isEmpty {
                        DashboardInsightsSection(insights: insightItems)
                    }
                    if !topBudgets.isEmpty {
                        budgetsSection
                    }
                    if !dashboardGoals.isEmpty {
                        goalsSection
                    }
                    if !upcomingSubs.isEmpty || !upcomingExpected.isEmpty {
                        upcomingSection
                    }
                    recentSection
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Overview")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Display currency", selection: $displayCurrency) {
                            ForEach(Currency.allCases) { c in
                                Text(c.displayCode).tag(c)
                            }
                        }
                    } label: {
                        Label(displayCurrency.displayCode, systemImage: "arrow.left.arrow.right.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showingAddExpense = true
                        } label: {
                            Label("New Expense", systemImage: "arrow.up.circle.fill")
                        }
                        Button {
                            showingAddIncome = true
                        } label: {
                            Label("New Income", systemImage: "arrow.down.circle.fill")
                        }
                        if !allTemplates.isEmpty {
                            Divider()
                            Button {
                                showingTemplatePicker = true
                            } label: {
                                Label("Use Template", systemImage: "star.circle.fill")
                            }
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showingAddExpense) {
                ExpenseEditorView(expense: nil)
            }
            .sheet(isPresented: $showingAddIncome) {
                IncomeEditorView(income: nil)
            }
            .sheet(item: $editingExpense) { exp in
                NavigationStack { ExpenseEditorView(expense: exp) }
            }
            .sheet(item: $editingIncome) { inc in
                IncomeEditorView(income: inc)
            }
            .sheet(isPresented: $showingTemplatePicker) {
                TemplatePickerSheet { template in
                    pendingTemplate = template
                }
            }
            .sheet(item: $pendingTemplate) { template in
                ExpenseEditorView(expense: nil, prefilledFrom: template)
            }
            .onAppear {
                if let settings { displayCurrency = settings.defaultCurrency }
            }
        }
    }

    // MARK: - Sections

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Total balance")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
            Text(Formatters.currency(totalBalance, in: displayCurrency))
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())

            availableLine

            HStack {
                Label(Formatters.currency(monthSpend, in: displayCurrency),
                      systemImage: "arrow.down.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.95))
                Text("spent this month")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
                Spacer()
            }
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
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
    }

    /// Sub-line under the total. Three states:
    ///   • Nothing due before cutoff → "✓ Nothing due <cutoffDescription>"
    ///   • Committed > 0, balance covers it → "✨ $X available · $Y due <cutoffDescription>"
    ///   • Committed > 0, balance does not cover it → red "⚠ $X short · $Y due <cutoffDescription>"
    @ViewBuilder
    private var availableLine: some View {
        if committedUntilCutoff <= 0 {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                Text("Nothing due \(cutoffDescription)")
                    .font(.caption)
            }
            .foregroundStyle(.white.opacity(0.85))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.top, 2)
        } else {
            let isShort = availableBalance < 0
            HStack(spacing: 6) {
                Image(systemName: isShort ? "exclamationmark.triangle.fill" : "sparkles")
                    .font(.caption2)
                Text(Formatters.currency(availableBalance, in: displayCurrency))
                    .font(.caption.weight(.bold).monospacedDigit())
                Text(isShort ? "short" : "available")
                    .font(.caption)
                Text("·")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
                Text("\(Formatters.currency(committedUntilCutoff, in: displayCurrency)) due \(cutoffDescription)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
            }
            .foregroundStyle(isShort ? Color(hex: "#FFD7D7") : .white)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.top, 2)
        }
    }

    private var accountsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "Accounts", destination: AnyView(AccountsListView()))
            if accounts.isEmpty {
                VStack(spacing: 8) {
                    Text("No accounts yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    NavigationLink {
                        AccountEditorView(account: nil)
                    } label: {
                        Text("Add your first account")
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(accounts) { account in
                            NavigationLink {
                                AccountDetailView(account: account)
                            } label: {
                                AccountCard(account: account, rate: rate)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var monthSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(Formatters.monthYear(Date()))
                    .font(.headline)
                Spacer()
            }
            HStack(spacing: 12) {
                StatTile(
                    title: "Spent",
                    value: Formatters.currency(monthSpend, in: displayCurrency),
                    symbol: "arrow.down.circle.fill",
                    tint: Color(hex: "#FF3B30")
                )
                StatTile(
                    title: "Expenses",
                    value: "\(monthExpenseCount)",
                    symbol: "list.bullet.rectangle.fill",
                    tint: Color(hex: "#4F8EF7")
                )
            }
        }
    }

    private var monthExpenseCount: Int {
        let cal = Calendar.current
        let startOfMonth = cal.dateInterval(of: .month, for: Date())?.start ?? Date()
        return allExpenses.filter { $0.date >= startOfMonth }.count
    }

    private var budgetsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "Budgets", destination: AnyView(BudgetsListView()))
            VStack(spacing: 10) {
                ForEach(topBudgets, id: \.budget.id) { item in
                    DashboardBudgetRow(item: item)
                }
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "Goals", destination: AnyView(SavingsGoalsListView()))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(dashboardGoals) { goal in
                        NavigationLink {
                            SavingsGoalsListView()
                        } label: {
                            DashboardGoalCard(goal: goal)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Coming up")
                .font(.headline)
            VStack(spacing: 0) {
                ForEach(upcomingSubs) { sub in
                    UpcomingRow(
                        symbol: "repeat.circle.fill",
                        color: Color(hex: sub.category?.colorHex ?? "#5856D6"),
                        title: sub.name,
                        subtitle: "Renews \(Formatters.relativeDate(sub.nextRenewalDate))",
                        amount: Formatters.currency(sub.amount, in: sub.currency)
                    )
                    Divider().padding(.leading, 60)
                }
                ForEach(upcomingExpected) { exp in
                    UpcomingRow(
                        symbol: "calendar.badge.clock",
                        color: Color(hex: exp.category?.colorHex ?? "#FF9500"),
                        title: exp.name,
                        subtitle: "Due \(Formatters.relativeDate(exp.dueDate))",
                        amount: Formatters.currency(exp.amount, in: exp.currency)
                    )
                    if exp.id != upcomingExpected.last?.id {
                        Divider().padding(.leading, 60)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "Recent activity", destination: AnyView(TransactionsListView()))

            if recentTransactions.isEmpty {
                Text("No transactions yet — tap + to add one.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                VStack(spacing: 0) {
                    ForEach(recentTransactions) { item in
                        Button {
                            if let exp = item.expense {
                                editingExpense = exp
                            } else if let inc = item.income {
                                editingIncome = inc
                            }
                        } label: {
                            RecentRow(item: item)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 12)
                        }
                        .buttonStyle(.plain)
                        if item.id != recentTransactions.last?.id {
                            Divider().padding(.leading, 60)
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private func sectionHeader(title: String, destination: AnyView) -> some View {
        HStack {
            Text(title).font(.headline)
            Spacer()
            NavigationLink {
                destination
            } label: {
                Text("See all")
                    .font(.subheadline)
            }
        }
    }
}

// MARK: - Subviews

private struct AccountCard: View {
    let account: Account
    let rate: Decimal

    var body: some View {
        let balance = BalanceService.currentBalance(for: account, usdToLbpRate: rate)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                IconBadge(symbol: account.iconName, color: Color(hex: account.colorHex), size: 32)
                Spacer()
                Text(account.currency.displayCode)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(Capsule())
            }
            Text(account.name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Text(Formatters.currency(balance, in: account.currency))
                .font(.title3.weight(.bold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(account.type.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(width: 180, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct StatTile: View {
    let title: String
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: symbol)
                    .foregroundStyle(tint)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct RecentRow: View {
    let item: TransactionItem

    var body: some View {
        HStack(spacing: 12) {
            IconBadge(symbol: item.iconName, color: Color(hex: item.colorHex))
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(
                (item.isIncome ? "+" : "−") +
                Formatters.currency(item.amount, in: item.currency).replacingOccurrences(of: "-", with: "")
            )
            .font(.subheadline.weight(.semibold).monospacedDigit())
            .foregroundStyle(item.isIncome ? Color(hex: "#34C759") : .primary)
        }
    }
}

private struct DashboardGoalCard: View {
    let goal: SavingsGoal

    private var tint: Color { Color(hex: goal.colorHex) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.white.opacity(0.22))
                    Image(systemName: goal.iconName)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 28, height: 28)
                Text("\(goal.percent)%")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.white.opacity(0.22))
                    .clipShape(Capsule())
                Spacer()
            }
            Text(goal.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Text(Formatters.currency(goal.contributedAmount, in: goal.currency))
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("of \(Formatters.currency(goal.targetAmount, in: goal.currency))")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
            BudgetProgressBar(fraction: goal.fraction, tint: .white.opacity(0.95), height: 5)
        }
        .padding(12)
        .frame(width: 170, alignment: .leading)
        .background(
            LinearGradient(
                colors: [tint, tint.opacity(0.65)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct DashboardBudgetRow: View {
    let item: BudgetProgress

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                IconBadge(symbol: item.categoryIcon, color: Color(hex: item.categoryColor), size: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.categoryName)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text("\(Formatters.currency(item.spent, in: item.currency)) of \(Formatters.currency(item.cap, in: item.currency))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(Int(item.percentRaw.rounded()))%")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(item.tintColor)
            }
            BudgetProgressBar(fraction: item.fraction, tint: item.tintColor, height: 6)
        }
    }
}

private struct UpcomingRow: View {
    let symbol: String
    let color: Color
    let title: String
    let subtitle: String
    let amount: String

    var body: some View {
        HStack(spacing: 12) {
            IconBadge(symbol: symbol, color: color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(amount)
                .font(.subheadline.weight(.semibold).monospacedDigit())
        }
        .padding(12)
    }
}
