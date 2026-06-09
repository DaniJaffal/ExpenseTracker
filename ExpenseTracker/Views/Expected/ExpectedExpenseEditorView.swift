//
//  ExpectedExpenseEditorView.swift
//  ExpenseTracker
//

import SwiftUI
import SwiftData

struct ExpectedExpenseEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let item: ExpectedExpense?

    @Query(filter: #Predicate<Account> { !$0.isArchived },
           sort: [SortDescriptor(\Account.name)])
    private var accounts: [Account]
    @Query(sort: [SortDescriptor(\Category.sortOrder)])
    private var categories: [Category]

    @State private var name: String = ""
    @State private var amount: Decimal = 0
    @State private var currency: Currency = .usd
    @State private var dueDate: Date = Date()
    @State private var recurrence: ExpectedRecurrence = .once
    @State private var accountID: UUID?
    @State private var categoryID: UUID?
    @State private var isPaid: Bool = false
    @State private var notificationsEnabled: Bool = false
    @State private var notificationLeadDays: Int = 2
    @State private var note: String = ""
    @State private var showDeleteConfirm = false

    private var isEditing: Bool { item != nil }

    var body: some View {
        Form {
            Section("Basics") {
                TextField("Name (e.g. Car loan)", text: $name)
                CurrencyAmountField(title: "Amount", amount: $amount, currency: $currency)
                DatePicker("Due date", selection: $dueDate, displayedComponents: .date)
                Picker("Recurrence", selection: $recurrence) {
                    ForEach(ExpectedRecurrence.allCases) { r in
                        Text(r.displayName).tag(r)
                    }
                }
            }

            Section("Account & category") {
                Picker("Account", selection: $accountID) {
                    Text("None").tag(UUID?.none)
                    ForEach(accounts) { acc in
                        Text("\(acc.name) (\(acc.currency.displayCode))").tag(Optional(acc.id))
                    }
                }
                Picker("Category", selection: $categoryID) {
                    Text("None").tag(UUID?.none)
                    ForEach(categories) { cat in
                        Text(cat.name).tag(Optional(cat.id))
                    }
                }
            }

            Section("Notifications") {
                Toggle("Notify before due date", isOn: $notificationsEnabled)
                if notificationsEnabled {
                    Stepper("Lead time: \(notificationLeadDays) day\(notificationLeadDays == 1 ? "" : "s")",
                            value: $notificationLeadDays, in: 0...30)
                }
            }

            Section("Status") {
                Toggle("Paid", isOn: $isPaid)
                TextField("Note", text: $note, axis: .vertical)
                    .lineLimit(1...4)
            }

            if isEditing {
                Section {
                    Button("Delete", role: .destructive) {
                        showDeleteConfirm = true
                    }
                }
            }
        }
        .navigationTitle(isEditing ? item?.name ?? "Expected" : "New Expected Expense")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { Task { await save() } }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || amount <= 0)
            }
        }
        .onAppear(perform: load)
        .confirmationDialog(
            "Delete this item?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { Task { await deleteItem() } }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func load() {
        guard let it = item else { return }
        name = it.name
        amount = it.amount
        currency = it.currency
        dueDate = it.dueDate
        recurrence = it.recurrence
        accountID = it.account?.id
        categoryID = it.category?.id
        isPaid = it.isPaid
        notificationsEnabled = it.notificationsEnabled
        notificationLeadDays = it.notificationLeadDays
        note = it.note
    }

    private func save() async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let acc = accounts.first { $0.id == accountID }
        let cat = categories.first { $0.id == categoryID }

        let target: ExpectedExpense
        let shouldLogPayment: Bool

        if let it = item {
            let crossedToPaid = isPaid && !it.isPaid
            it.name = trimmed
            it.amount = amount
            it.currency = currency
            it.dueDate = dueDate
            it.recurrence = recurrence
            it.account = acc
            it.category = cat
            it.notificationsEnabled = notificationsEnabled
            it.notificationLeadDays = notificationLeadDays
            it.note = note

            if crossedToPaid {
                // Defer paid/date handling to RecurringService so an Expense
                // is created and recurrence rolls forward.
                shouldLogPayment = true
            } else {
                if !isPaid { it.paidDate = nil }
                it.isPaid = isPaid
                shouldLogPayment = false
            }
            target = it
        } else {
            let new = ExpectedExpense(
                name: trimmed,
                amount: amount,
                currency: currency,
                dueDate: dueDate,
                recurrence: recurrence,
                notificationLeadDays: notificationLeadDays,
                notificationsEnabled: notificationsEnabled,
                note: note,
                account: acc,
                category: cat
            )
            context.insert(new)
            target = new
            shouldLogPayment = isPaid
        }

        try? context.save()

        if shouldLogPayment {
            _ = RecurringService.markPaid(target, in: context)
            WidgetRefresh.bump()
        }

        NotificationService.shared.cancelNotification(for: target)
        if !target.isPaid {
            await NotificationService.shared.scheduleNotification(for: target)
        }
        dismiss()
    }

    private func deleteItem() async {
        guard let it = item else { return }
        NotificationService.shared.cancelNotification(for: it)
        context.delete(it)
        try? context.save()
        dismiss()
    }
}
