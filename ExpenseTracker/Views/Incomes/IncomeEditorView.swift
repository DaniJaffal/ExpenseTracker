//
//  IncomeEditorView.swift
//  ExpenseTracker
//
//  Add or edit a single income entry. Symmetric with ExpenseEditorView but
//  simpler — no split tenders, no returns.
//

import SwiftUI
import SwiftData
import UIKit

struct IncomeEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let income: Income?

    @Query(sort: [SortDescriptor(\AppSettings.createdAt, order: .forward)])
    private var settingsList: [AppSettings]
    @Query(filter: #Predicate<Account> { !$0.isArchived },
           sort: [SortDescriptor(\Account.sortOrder), SortDescriptor(\Account.name)])
    private var accounts: [Account]
    @Query(sort: [SortDescriptor(\IncomeSource.sortOrder), SortDescriptor(\IncomeSource.name)])
    private var sources: [IncomeSource]

    @State private var amount: Decimal = 0
    @State private var currency: Currency = .usd
    @State private var date: Date = Date()
    @State private var note: String = ""
    @State private var accountID: UUID?
    @State private var sourceID: UUID?
    @State private var useRateOverride: Bool = false
    @State private var rateOverride: Decimal = 90_000
    @State private var selectedTagIDs: Set<UUID> = []
    @State private var showingTagPicker: Bool = false

    // Receipt attachment state.
    @State private var pickedReceiptImage: UIImage?
    @State private var currentReceiptFilename: String?
    @State private var originalReceiptFilename: String?

    @State private var showDeleteConfirm = false

    private var settings: AppSettings? { settingsList.first }
    private var isEditing: Bool { income != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Amount") {
                    CurrencyAmountField(title: "Amount", amount: $amount, currency: $currency)
                }

                Section("Details") {
                    TextField("Note (e.g. October salary)", text: $note, axis: .vertical)
                        .lineLimit(1...3)

                    DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])

                    Picker("Account", selection: $accountID) {
                        Text("None").tag(UUID?.none)
                        ForEach(accounts) { acc in
                            Text("\(acc.name) (\(acc.currency.displayCode))").tag(Optional(acc.id))
                        }
                    }

                    Picker("Source", selection: $sourceID) {
                        Text("None").tag(UUID?.none)
                        ForEach(sources) { src in
                            HStack {
                                Image(systemName: src.iconName)
                                Text(src.name)
                            }.tag(Optional(src.id))
                        }
                    }
                }

                Section {
                    TagFieldRow(selectedIDs: $selectedTagIDs) {
                        showingTagPicker = true
                    }
                } header: {
                    Text("Tags")
                }

                Section {
                    ReceiptFieldRow(
                        pickedImage: $pickedReceiptImage,
                        currentFilename: $currentReceiptFilename
                    )
                } header: {
                    Text("Receipt")
                }

                Section {
                    Toggle("Override exchange rate", isOn: $useRateOverride)
                    if useRateOverride {
                        HStack {
                            Text("1 USD =")
                            TextField("90000", value: $rateOverride, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                            Text("LBP").foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    Text(useRateOverride
                         ? "This rate applies only to this income."
                         : "App default rate (\(Formatters.rate(settings?.usdToLbpRate ?? 90_000)) LBP per USD) will be used.")
                }

                if isEditing {
                    Section {
                        Button("Delete Income", role: .destructive) {
                            showDeleteConfirm = true
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Income" : "New Income")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(amount <= 0)
                }
            }
            .onAppear(perform: load)
            .confirmationDialog(
                "Delete this income?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive, action: deleteIncome)
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showingTagPicker) {
                TagPickerSheet(selectedIDs: $selectedTagIDs)
            }
        }
    }

    // MARK: - Load / save

    private func load() {
        if let inc = income {
            amount = inc.amount
            currency = inc.currency
            date = inc.date
            note = inc.note
            accountID = inc.account?.id
            sourceID = inc.source?.id
            if let o = inc.exchangeRateOverride {
                useRateOverride = true
                rateOverride = o
            }
            selectedTagIDs = Set((inc.tags ?? []).map(\.id))
            originalReceiptFilename = inc.receiptImageName
            currentReceiptFilename = inc.receiptImageName
        } else {
            if let s = settings {
                currency = s.defaultCurrency
                if let defID = s.defaultAccountID,
                   let acc = accounts.first(where: { $0.id == defID }) {
                    accountID = acc.id
                    currency = acc.currency
                } else if let first = accounts.first {
                    accountID = first.id
                    currency = first.currency
                }
                rateOverride = s.usdToLbpRate
            }
            // Default to "Salary" if it exists, otherwise the first source.
            sourceID = (sources.first { $0.name == "Salary" } ?? sources.first)?.id
        }
    }

    private func save() {
        let chosenAccount = accounts.first { $0.id == accountID }
        let chosenSource = sources.first { $0.id == sourceID }
        let resolvedTags = fetchTags(for: selectedTagIDs)

        if let inc = income {
            inc.amount = amount
            inc.currency = currency
            inc.date = date
            inc.note = note
            inc.account = chosenAccount
            inc.source = chosenSource
            inc.exchangeRateOverride = useRateOverride ? rateOverride : nil
            inc.tags = resolvedTags
            ReceiptFieldRow.commit(
                pickedImage: pickedReceiptImage,
                currentFilename: currentReceiptFilename,
                originalFilename: originalReceiptFilename
            ) { newFilename in
                inc.receiptImageName = newFilename
            }
        } else {
            let new = Income(
                date: date,
                amount: amount,
                currency: currency,
                exchangeRateOverride: useRateOverride ? rateOverride : nil,
                note: note,
                account: chosenAccount,
                source: chosenSource
            )
            new.tags = resolvedTags
            ReceiptFieldRow.commit(
                pickedImage: pickedReceiptImage,
                currentFilename: currentReceiptFilename,
                originalFilename: originalReceiptFilename
            ) { newFilename in
                new.receiptImageName = newFilename
            }
            context.insert(new)
        }
        try? context.save()
        WidgetRefresh.bump()
        dismiss()
    }

    private func fetchTags(for ids: Set<UUID>) -> [Tag] {
        guard !ids.isEmpty else { return [] }
        let descriptor = FetchDescriptor<Tag>(predicate: #Predicate<Tag> { ids.contains($0.id) })
        return (try? context.fetch(descriptor)) ?? []
    }

    private func deleteIncome() {
        guard let inc = income else { return }
        if let receiptName = inc.receiptImageName {
            ReceiptStore.delete(filename: receiptName)
        }
        context.delete(inc)
        try? context.save()
        WidgetRefresh.bump()
        dismiss()
    }
}
