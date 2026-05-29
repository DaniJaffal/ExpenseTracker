//
//  TransferEditorView.swift
//  ExpenseTracker
//

import SwiftUI
import SwiftData

struct TransferEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<Account> { !$0.isArchived },
           sort: [SortDescriptor(\Account.name)])
    private var accounts: [Account]

    @Query(sort: [SortDescriptor(\AppSettings.createdAt, order: .forward)])
    private var settingsList: [AppSettings]

    @State private var fromID: UUID?
    @State private var toID: UUID?
    @State private var amount: Decimal = 0
    @State private var customReceived: Bool = false
    @State private var receivedAmount: Decimal = 0
    @State private var date: Date = Date()
    @State private var note: String = ""

    private var settings: AppSettings? { settingsList.first }
    private var from: Account? { accounts.first { $0.id == fromID } }
    private var to: Account? { accounts.first { $0.id == toID } }

    private var convertedPreview: Decimal? {
        guard let from, let to, amount > 0 else { return nil }
        guard from.currency != to.currency else { return nil }
        let rate = settings?.usdToLbpRate ?? 90_000
        return CurrencyService.convert(amount, from: from.currency, to: to.currency, usdToLbpRate: rate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("From") {
                    Picker("Account", selection: $fromID) {
                        Text("Select").tag(UUID?.none)
                        ForEach(accounts) { acc in
                            Text("\(acc.name) (\(acc.currency.displayCode))").tag(Optional(acc.id))
                        }
                    }
                    HStack {
                        TextField("0", value: $amount, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text(from?.currency.displayCode ?? "").foregroundStyle(.secondary)
                    }
                }

                Section("To") {
                    Picker("Account", selection: $toID) {
                        Text("Select").tag(UUID?.none)
                        ForEach(accounts.filter { $0.id != fromID }) { acc in
                            Text("\(acc.name) (\(acc.currency.displayCode))").tag(Optional(acc.id))
                        }
                    }

                    if let from, let to, from.currency != to.currency {
                        Toggle("Specify received amount", isOn: $customReceived)
                        if customReceived {
                            HStack {
                                TextField("0", value: $receivedAmount, format: .number)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                Text(to.currency.displayCode).foregroundStyle(.secondary)
                            }
                        } else if let preview = convertedPreview {
                            HStack {
                                Text("Will arrive as")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(Formatters.currency(preview, in: to.currency))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Details") {
                    DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    TextField("Note (optional)", text: $note)
                }
            }
            .navigationTitle("New Transfer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!canSave)
                }
            }
            .onAppear {
                if accounts.count >= 2 {
                    fromID = accounts[0].id
                    toID = accounts[1].id
                }
            }
        }
    }

    private var canSave: Bool {
        from != nil && to != nil && fromID != toID && amount > 0
    }

    private func save() {
        guard let from, let to else { return }
        let transfer = Transfer(
            date: date,
            amount: amount,
            receivedAmount: (from.currency != to.currency && customReceived) ? receivedAmount : nil,
            exchangeRateOverride: nil,
            note: note,
            fromAccount: from,
            toAccount: to
        )
        context.insert(transfer)
        try? context.save()
        WidgetRefresh.bump()
        dismiss()
    }
}
