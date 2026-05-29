//
//  SubscriptionEditorView.swift
//  ExpenseTracker
//

import SwiftUI
import SwiftData

struct SubscriptionEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let subscription: Subscription?

    @Query(filter: #Predicate<Account> { !$0.isArchived },
           sort: [SortDescriptor(\Account.name)])
    private var accounts: [Account]
    @Query(sort: [SortDescriptor(\Category.sortOrder)])
    private var categories: [Category]

    @State private var name: String = ""
    @State private var amount: Decimal = 0
    @State private var currency: Currency = .usd
    @State private var billingCycle: BillingCycle = .monthly
    @State private var startDate: Date = Date()
    @State private var nextRenewalDate: Date = Date()
    @State private var accountID: UUID?
    @State private var categoryID: UUID?
    @State private var isActive: Bool = true
    @State private var notificationsEnabled: Bool = false
    @State private var notificationLeadDays: Int = 2
    @State private var note: String = ""
    @State private var showDeleteConfirm = false

    private var isEditing: Bool { subscription != nil }

    var body: some View {
        Form {
            Section("Basics") {
                TextField("Name (e.g. Netflix)", text: $name)
                CurrencyAmountField(title: "Amount", amount: $amount, currency: $currency)
                Picker("Billing", selection: $billingCycle) {
                    ForEach(BillingCycle.allCases) { c in
                        Text(c.displayName).tag(c)
                    }
                }
            }

            Section("Dates") {
                DatePicker("Start date", selection: $startDate, displayedComponents: .date)
                DatePicker("Next renewal", selection: $nextRenewalDate, displayedComponents: .date)
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
                Toggle("Notify before renewal", isOn: $notificationsEnabled)
                if notificationsEnabled {
                    Stepper("Lead time: \(notificationLeadDays) day\(notificationLeadDays == 1 ? "" : "s")",
                            value: $notificationLeadDays, in: 0...30)
                }
            }

            Section("Status") {
                Toggle("Active", isOn: $isActive)
                TextField("Note", text: $note, axis: .vertical)
                    .lineLimit(1...4)
            }

            if isEditing {
                Section {
                    Button("Delete Subscription", role: .destructive) {
                        showDeleteConfirm = true
                    }
                }
            }
        }
        .navigationTitle(isEditing ? subscription?.name ?? "Subscription" : "New Subscription")
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
        .onChange(of: startDate) { _, new in
            if !isEditing { nextRenewalDate = new }
        }
        .confirmationDialog(
            "Delete this subscription?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { Task { await deleteSub() } }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func load() {
        guard let sub = subscription else { return }
        name = sub.name
        amount = sub.amount
        currency = sub.currency
        billingCycle = sub.billingCycle
        startDate = sub.startDate
        nextRenewalDate = sub.nextRenewalDate
        accountID = sub.account?.id
        categoryID = sub.category?.id
        isActive = sub.isActive
        notificationsEnabled = sub.notificationsEnabled
        notificationLeadDays = sub.notificationLeadDays
        note = sub.note
    }

    private func save() async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let acc = accounts.first { $0.id == accountID }
        let cat = categories.first { $0.id == categoryID }

        let target: Subscription
        if let sub = subscription {
            sub.name = trimmed
            sub.amount = amount
            sub.currency = currency
            sub.billingCycle = billingCycle
            sub.startDate = startDate
            sub.nextRenewalDate = nextRenewalDate
            sub.account = acc
            sub.category = cat
            sub.isActive = isActive
            sub.notificationsEnabled = notificationsEnabled
            sub.notificationLeadDays = notificationLeadDays
            sub.note = note
            target = sub
        } else {
            let new = Subscription(
                name: trimmed,
                amount: amount,
                currency: currency,
                billingCycle: billingCycle,
                startDate: startDate,
                nextRenewalDate: nextRenewalDate,
                notificationLeadDays: notificationLeadDays,
                notificationsEnabled: notificationsEnabled,
                isActive: isActive,
                note: note,
                account: acc,
                category: cat
            )
            context.insert(new)
            target = new
        }

        try? context.save()
        await NotificationService.shared.scheduleNotification(for: target)
        dismiss()
    }

    private func deleteSub() async {
        guard let sub = subscription else { return }
        NotificationService.shared.cancelNotification(for: sub)
        context.delete(sub)
        try? context.save()
        dismiss()
    }
}
