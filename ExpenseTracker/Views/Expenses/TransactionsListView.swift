//
//  TransactionsListView.swift
//  ExpenseTracker
//
//  Unified list of expenses + incomes with a filter chip (All / Spent / Earned).
//  Replaces the prior expense-only list.
//

import SwiftUI
import SwiftData

struct TransactionsListView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: [SortDescriptor(\Expense.date, order: .reverse)])
    private var expenses: [Expense]

    @Query(sort: [SortDescriptor(\Income.date, order: .reverse)])
    private var incomes: [Income]

    @Query(sort: [SortDescriptor(\ExpenseTemplate.createdAt)])
    private var allTemplates: [ExpenseTemplate]

    @State private var showingAddExpense = false
    @State private var showingAddIncome = false
    @State private var showingTemplatePicker = false
    @State private var pendingTemplate: ExpenseTemplate?
    @State private var searchText = ""
    @State private var filter: TransactionFilter = .all
    @State private var advancedFilter: TransactionFilterState = TransactionFilterState()
    @State private var showingFilterSheet = false
    @State private var editingExpense: Expense?
    @State private var editingIncome: Income?

    enum TransactionFilter: String, CaseIterable, Identifiable {
        case all     = "All"
        case spent   = "Spent"
        case earned  = "Earned"
        var id: String { rawValue }
    }

    private var items: [TransactionItem] {
        var list: [TransactionItem] = []
        if filter != .earned {
            list.append(contentsOf: expenses
                .filter(matchesExpense)
                .map { TransactionItem(expense: $0) })
        }
        if filter != .spent {
            list.append(contentsOf: incomes
                .filter(matchesIncome)
                .map { TransactionItem(income: $0) })
        }
        let q = searchText.lowercased()
        let filtered = q.isEmpty ? list : list.filter { it in
            it.title.lowercased().contains(q) ||
            it.subtitle.lowercased().contains(q)
        }
        return filtered.sorted { $0.date > $1.date }
    }

    // MARK: - Advanced filter predicates

    private func matchesExpense(_ exp: Expense) -> Bool {
        guard advancedFilter.includesDate(exp.date) else { return false }
        guard advancedFilter.includesAmount(exp.amount) else { return false }
        if advancedFilter.receiptsOnly && exp.receiptImageName == nil { return false }
        if !advancedFilter.selectedCategoryIDs.isEmpty {
            guard let id = exp.category?.id,
                  advancedFilter.selectedCategoryIDs.contains(id) else { return false }
        }
        if !advancedFilter.selectedAccountIDs.isEmpty {
            guard let id = exp.account?.id,
                  advancedFilter.selectedAccountIDs.contains(id) else { return false }
        }
        if !advancedFilter.selectedTagIDs.isEmpty {
            let tagIDs = Set((exp.tags ?? []).map(\.id))
            if tagIDs.isDisjoint(with: advancedFilter.selectedTagIDs) { return false }
        }
        // Sources filter applies only to incomes; ignored for expenses.
        return true
    }

    private func matchesIncome(_ inc: Income) -> Bool {
        guard advancedFilter.includesDate(inc.date) else { return false }
        guard advancedFilter.includesAmount(inc.amount) else { return false }
        if advancedFilter.receiptsOnly && inc.receiptImageName == nil { return false }
        if !advancedFilter.selectedSourceIDs.isEmpty {
            guard let id = inc.source?.id,
                  advancedFilter.selectedSourceIDs.contains(id) else { return false }
        }
        if !advancedFilter.selectedAccountIDs.isEmpty {
            guard let id = inc.account?.id,
                  advancedFilter.selectedAccountIDs.contains(id) else { return false }
        }
        if !advancedFilter.selectedTagIDs.isEmpty {
            let tagIDs = Set((inc.tags ?? []).map(\.id))
            if tagIDs.isDisjoint(with: advancedFilter.selectedTagIDs) { return false }
        }
        // Categories filter applies only to expenses; ignored for incomes.
        return true
    }

    private var grouped: [(key: Date, value: [TransactionItem])] {
        let dict = Dictionary(grouping: items) { it in
            Calendar.current.startOfDay(for: it.date)
        }
        return dict.sorted { $0.key > $1.key }
    }

    var body: some View {
        Group {
            if expenses.isEmpty && incomes.isEmpty {
                EmptyStateView(
                    symbol: "list.bullet.rectangle",
                    title: "No transactions yet",
                    message: "Tap + to log an expense or income.",
                    actionTitle: "Add Expense",
                    action: { showingAddExpense = true }
                )
            } else {
                List {
                    Section {
                        VStack(spacing: 8) {
                            Picker("Filter", selection: $filter) {
                                ForEach(TransactionFilter.allCases) { f in
                                    Text(f.rawValue).tag(f)
                                }
                            }
                            .pickerStyle(.segmented)
                            if advancedFilter.hasActiveFilters {
                                ActiveFilterChips(state: $advancedFilter)
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                    }

                    if items.isEmpty {
                        Section {
                            Text("No results.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        ForEach(grouped, id: \.key) { day, dayItems in
                            Section(Formatters.date(day, style: .full)) {
                                ForEach(dayItems) { item in
                                    Button {
                                        open(item)
                                    } label: {
                                        TransactionRow(item: item)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .onDelete { indexSet in
                                    for index in indexSet {
                                        delete(dayItems[index])
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .searchable(text: $searchText, prompt: "Search transactions")
            }
        }
        .navigationTitle("Transactions")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingFilterSheet = true
                } label: {
                    Image(systemName: advancedFilter.hasActiveFilters
                          ? "line.3.horizontal.decrease.circle.fill"
                          : "line.3.horizontal.decrease.circle")
                        .font(.title3)
                        .foregroundStyle(advancedFilter.hasActiveFilters ? Color(hex: "#0A84FF") : .primary)
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
        .sheet(isPresented: $showingFilterSheet) {
            TransactionFilterSheet(state: $advancedFilter)
        }
    }

    // MARK: - Open / delete

    private func open(_ item: TransactionItem) {
        if let exp = item.expense {
            editingExpense = exp
        } else if let inc = item.income {
            editingIncome = inc
        }
    }

    private func delete(_ item: TransactionItem) {
        if let exp = item.expense {
            context.delete(exp)
        } else if let inc = item.income {
            context.delete(inc)
        }
        try? context.save()
        WidgetRefresh.bump()
    }
}

// MARK: - Item wrapper

struct TransactionItem: Identifiable {
    let id: String
    let date: Date
    let title: String
    let subtitle: String
    let amount: Decimal
    let currency: Currency
    let isIncome: Bool
    let iconName: String
    let colorHex: String
    let tags: [Tag]
    let hasReceipt: Bool
    let expense: Expense?
    let income: Income?

    init(expense: Expense) {
        self.id = "exp-\(expense.id.uuidString)"
        self.date = expense.date
        self.title = expense.note.isEmpty
            ? (expense.category?.name ?? "Expense")
            : expense.note
        self.subtitle = TransactionItem.subtitle(forExpense: expense)
        self.amount = expense.amount
        self.currency = expense.currency
        self.isIncome = false
        self.iconName = expense.category?.iconName ?? "tag.fill"
        self.colorHex = expense.category?.colorHex ?? "#8E8E93"
        self.tags = expense.tags ?? []
        self.hasReceipt = expense.receiptImageName != nil
        self.expense = expense
        self.income = nil
    }

    init(income: Income) {
        self.id = "inc-\(income.id.uuidString)"
        self.date = income.date
        self.title = income.note.isEmpty
            ? (income.source?.name ?? "Income")
            : income.note
        self.subtitle = TransactionItem.subtitle(forIncome: income)
        self.amount = income.amount
        self.currency = income.currency
        self.isIncome = true
        self.iconName = income.source?.iconName ?? "dollarsign.circle.fill"
        self.colorHex = income.source?.colorHex ?? "#34C759"
        self.tags = income.tags ?? []
        self.hasReceipt = income.receiptImageName != nil
        self.expense = nil
        self.income = income
    }

    private static func subtitle(forExpense exp: Expense) -> String {
        let acc = exp.account?.name ?? "No account"
        let cat = exp.category?.name
        if let cat { return "\(acc) · \(cat)" }
        return acc
    }

    private static func subtitle(forIncome inc: Income) -> String {
        let acc = inc.account?.name ?? "No account"
        let src = inc.source?.name
        if let src { return "\(acc) · \(src)" }
        return acc
    }
}

// MARK: - Row

// MARK: - Active filter chip strip

struct ActiveFilterChips: View {
    @Binding var state: TransactionFilterState

    @Query(sort: [SortDescriptor(\Category.sortOrder)])
    private var categories: [Category]
    @Query(sort: [SortDescriptor(\IncomeSource.sortOrder)])
    private var sources: [IncomeSource]
    @Query(sort: [SortDescriptor(\Account.sortOrder)])
    private var accounts: [Account]
    @Query(sort: [SortDescriptor(\Tag.sortOrder)])
    private var tags: [Tag]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                if state.dateRangePreset != .all {
                    chip(state.dateRangePreset.rawValue, icon: "calendar") {
                        state.dateRangePreset = .all
                    }
                }
                if !state.selectedCategoryIDs.isEmpty {
                    chip(label(for: state.selectedCategoryIDs.count, "category", "categories"),
                         icon: "tag.fill") {
                        state.selectedCategoryIDs.removeAll()
                    }
                }
                if !state.selectedSourceIDs.isEmpty {
                    chip(label(for: state.selectedSourceIDs.count, "source", "sources"),
                         icon: "dollarsign.circle.fill") {
                        state.selectedSourceIDs.removeAll()
                    }
                }
                if !state.selectedAccountIDs.isEmpty {
                    chip(label(for: state.selectedAccountIDs.count, "account", "accounts"),
                         icon: "creditcard.fill") {
                        state.selectedAccountIDs.removeAll()
                    }
                }
                if !state.selectedTagIDs.isEmpty {
                    chip(label(for: state.selectedTagIDs.count, "tag", "tags"),
                         icon: "number") {
                        state.selectedTagIDs.removeAll()
                    }
                }
                if state.minAmount != nil || state.maxAmount != nil {
                    chip(amountChipText, icon: "dollarsign.circle") {
                        state.minAmount = nil
                        state.maxAmount = nil
                    }
                }
                if state.receiptsOnly {
                    chip("With receipts", icon: "paperclip") {
                        state.receiptsOnly = false
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func label(for count: Int, _ singular: String, _ plural: String) -> String {
        "\(count) \(count == 1 ? singular : plural)"
    }

    private var amountChipText: String {
        switch (state.minAmount, state.maxAmount) {
        case let (min?, max?): return "\(format(min)) – \(format(max))"
        case let (min?, nil):  return "≥ \(format(min))"
        case let (nil, max?):  return "≤ \(format(max))"
        default:               return ""
        }
    }

    private func format(_ value: Decimal) -> String {
        NumberFormatter.localizedString(
            from: NSDecimalNumber(decimal: value),
            number: .decimal
        )
    }

    private func chip(_ text: String, icon: String, onRemove: @escaping () -> Void) -> some View {
        Button(action: onRemove) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2.weight(.semibold))
                Text(text)
                    .font(.caption.weight(.medium))
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Color(hex: "#0A84FF").opacity(0.12))
            .foregroundStyle(Color(hex: "#0A84FF"))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct TransactionRow: View {
    let item: TransactionItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            IconBadge(symbol: item.iconName, color: Color(hex: item.colorHex))
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    if item.isIncome {
                        Text("Income")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color(hex: "#34C759"))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color(hex: "#34C759").opacity(0.15))
                            .clipShape(Capsule())
                    } else if let exp = item.expense, !(exp.additionalPayments ?? []).isEmpty {
                        Text("Split")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color(hex: "#5856D6"))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color(hex: "#5856D6").opacity(0.15))
                            .clipShape(Capsule())
                    }
                    if item.hasReceipt {
                        Image(systemName: "paperclip")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if !item.tags.isEmpty {
                    FlowLayout(spacing: 4, lineSpacing: 4) {
                        ForEach(item.tags.prefix(4)) { tag in
                            TagPill(name: tag.name, colorHex: tag.colorHex)
                        }
                        if item.tags.count > 4 {
                            Text("+\(item.tags.count - 4)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 2)
                }
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
