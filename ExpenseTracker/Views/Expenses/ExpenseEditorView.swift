//
//  ExpenseEditorView.swift
//  ExpenseTracker
//
//  Add or edit a single expense. Handles money-returned + per-expense rate override.
//

import SwiftUI
import SwiftData
import UIKit

struct ExpenseEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// nil = creating a new expense
    let expense: Expense?

    /// If supplied (and `expense == nil`), the editor pre-fills its state
    /// from this template and bumps the template's usage counter on save.
    var prefilledFrom: ExpenseTemplate? = nil

    @Query(sort: [SortDescriptor(\AppSettings.createdAt, order: .forward)])
    private var settingsList: [AppSettings]
    @Query(filter: #Predicate<Account> { !$0.isArchived },
           sort: [SortDescriptor(\Account.sortOrder), SortDescriptor(\Account.name)])
    private var accounts: [Account]
    @Query(sort: [SortDescriptor(\Category.sortOrder), SortDescriptor(\Category.name)])
    private var categories: [Category]

    // Form state
    @State private var amount: Decimal = 0
    @State private var currency: Currency = .usd
    @State private var date: Date = Date()
    @State private var note: String = ""
    @State private var accountID: UUID?
    @State private var categoryID: UUID?

    @State private var amountReturned: Decimal? = nil
    @State private var returnedCurrency: Currency? = nil
    @State private var returnedToAccountID: UUID? = nil
    @State private var hasManuallyChosenReturnAccount: Bool = false

    // Additional return legs (beyond the primary return above).
    @State private var returnLegs: [DraftReturnLeg] = []

    @State private var useRateOverride: Bool = false
    @State private var rateOverride: Decimal = 90_000

    // Split-payment state. Each draft maps 1:1 with a PaymentLeg on save.
    @State private var splitEnabled: Bool = false
    @State private var legs: [DraftPaymentLeg] = []

    @State private var selectedTagIDs: Set<UUID> = []
    @State private var showingTagPicker: Bool = false

    // Receipt attachment state.
    @State private var pickedReceiptImage: UIImage?
    @State private var currentReceiptFilename: String?
    @State private var originalReceiptFilename: String?

    @State private var showDeleteConfirm = false

    private var settings: AppSettings? { settingsList.first }
    private var isEditing: Bool { expense != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Amount") {
                    CurrencyAmountField(title: "Amount", amount: $amount, currency: $currency)
                }

                Section("Details") {
                    TextField("Note (e.g. lunch with friends)", text: $note, axis: .vertical)
                        .lineLimit(1...3)

                    DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])

                    Picker("Account", selection: $accountID) {
                        Text("None").tag(UUID?.none)
                        ForEach(accounts) { acc in
                            Text("\(acc.name) (\(acc.currency.displayCode))").tag(Optional(acc.id))
                        }
                    }

                    Picker("Category", selection: $categoryID) {
                        Text("None").tag(UUID?.none)
                        ForEach(categories) { cat in
                            HStack {
                                Image(systemName: cat.iconName)
                                Text(cat.name)
                            }.tag(Optional(cat.id))
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
                    Toggle("Split into multiple payments", isOn: $splitEnabled)
                    if splitEnabled {
                        ForEach($legs) { $leg in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Payment \((legs.firstIndex(where: { $0.id == leg.id }) ?? 0) + 2)")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Button(role: .destructive) {
                                        legs.removeAll { $0.id == leg.id }
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundStyle(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                                HStack(spacing: 8) {
                                    TextField("0", value: $leg.amount, format: .number)
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.trailing)
                                        .font(.title3.monospacedDigit())
                                    Picker("", selection: $leg.currency) {
                                        ForEach(Currency.allCases) { c in
                                            Text(c.displayCode).tag(c)
                                        }
                                    }
                                    .labelsHidden()
                                    .pickerStyle(.menu)
                                    .tint(.primary)
                                }
                                Picker("From", selection: $leg.accountID) {
                                    Text("Select account").tag(UUID?.none)
                                    ForEach(accounts) { acc in
                                        Text("\(acc.name) (\(acc.currency.displayCode))").tag(Optional(acc.id))
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }

                        Button {
                            legs.append(DraftPaymentLeg(
                                amount: 0,
                                currency: currency,
                                accountID: nil
                            ))
                        } label: {
                            Label("Add another payment", systemImage: "plus.circle.fill")
                        }
                    }
                } footer: {
                    if splitEnabled {
                        let total = totalInDisplayCurrency()
                        Text("Total spent: \(Formatters.currency(total.amount, in: total.currency)) across \(legs.count + 1) payments.")
                    } else {
                        Text("Use this when you paid one transaction with more than one currency or account.")
                    }
                }
                .onChange(of: splitEnabled) { _, newValue in
                    if newValue && legs.isEmpty {
                        legs.append(DraftPaymentLeg(
                            amount: 0,
                            currency: currency == .usd ? .lbp : .usd,
                            accountID: nil
                        ))
                    }
                    if !newValue {
                        legs.removeAll()
                    }
                }

                Section {
                    OptionalCurrencyAmountField(
                        title: "Money returned",
                        amount: $amountReturned,
                        currency: $returnedCurrency
                    )

                    if amountReturned != nil {
                        // Custom binding so we only flip the "manually chosen" flag
                        // when the user touches the picker — not when auto-detect updates it.
                        Picker("Returned to", selection: Binding<UUID?>(
                            get: { returnedToAccountID },
                            set: { newValue in
                                returnedToAccountID = newValue
                                hasManuallyChosenReturnAccount = true
                            }
                        )) {
                            Text("Same as source").tag(UUID?.none)
                            ForEach(accounts) { acc in
                                Text("\(acc.name) (\(acc.currency.displayCode))").tag(Optional(acc.id))
                            }
                        }

                        // Additional return legs: each with its own amount, currency, destination account.
                        ForEach($returnLegs) { $leg in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Return \((returnLegs.firstIndex(where: { $0.id == leg.id }) ?? 0) + 2)")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Button(role: .destructive) {
                                        returnLegs.removeAll { $0.id == leg.id }
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundStyle(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                                HStack(spacing: 8) {
                                    TextField("0", value: $leg.amount, format: .number)
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.trailing)
                                        .font(.title3.monospacedDigit())
                                    Picker("", selection: $leg.currency) {
                                        ForEach(Currency.allCases) { c in
                                            Text(c.displayCode).tag(c)
                                        }
                                    }
                                    .labelsHidden()
                                    .pickerStyle(.menu)
                                    .tint(.primary)
                                    .onChange(of: leg.currency) { _, newCurrency in
                                        guard !leg.hasManualAccount else { return }
                                        leg.accountID = autoDetectReturnAccount(for: newCurrency)?.id
                                    }
                                }
                                Picker("To", selection: Binding<UUID?>(
                                    get: { leg.accountID },
                                    set: { newValue in
                                        leg.accountID = newValue
                                        leg.hasManualAccount = true
                                    }
                                )) {
                                    Text("Same as source").tag(UUID?.none)
                                    ForEach(accounts) { acc in
                                        Text("\(acc.name) (\(acc.currency.displayCode))").tag(Optional(acc.id))
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }

                        Button {
                            // Default the new leg to the OTHER currency than the primary return,
                            // because that's typically the reason for adding it.
                            let otherCurrency: Currency = (returnedCurrency ?? .usd) == .usd ? .lbp : .usd
                            var newLeg = DraftReturnLeg(amount: 0, currency: otherCurrency, accountID: nil)
                            newLeg.accountID = autoDetectReturnAccount(for: otherCurrency)?.id
                            returnLegs.append(newLeg)
                        } label: {
                            Label("Add another return amount", systemImage: "plus.circle.fill")
                        }
                    }
                } footer: {
                    if amountReturned != nil {
                        let total = totalReturnInDisplayCurrency()
                        let totalText = "Total returned: \(Formatters.currency(total.amount, in: total.currency))"
                        if let autoName = autoReturnAccountName, !hasManuallyChosenReturnAccount, returnLegs.isEmpty {
                            Text("\(totalText). Primary auto-detected: \(autoName).")
                        } else {
                            Text(totalText)
                        }
                    } else {
                        Text("Use this for refunds, change, or money handed back — possibly in a different currency.")
                    }
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
                         ? "This rate applies only to this expense."
                         : "App default rate (\(Formatters.rate(settings?.usdToLbpRate ?? 90_000)) LBP per USD) will be used.")
                }

                if isEditing {
                    Section {
                        Button("Delete Expense", role: .destructive) {
                            showDeleteConfirm = true
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Expense" : "New Expense")
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
            .onAppear(perform: load)
            .onChange(of: returnedCurrency) { _, newCurrency in
                guard !hasManuallyChosenReturnAccount, let c = newCurrency else { return }
                returnedToAccountID = autoDetectReturnAccount(for: c)?.id
            }
            .onChange(of: amountReturned) { _, newValue in
                // When toggle flips on, the OptionalCurrencyAmountField sets currency = .usd
                // by default. Auto-pick a return account if the user hasn't overridden.
                if newValue != nil, !hasManuallyChosenReturnAccount {
                    let c = returnedCurrency ?? .usd
                    returnedToAccountID = autoDetectReturnAccount(for: c)?.id
                }
                if newValue == nil {
                    returnedToAccountID = nil
                    hasManuallyChosenReturnAccount = false
                    returnLegs.removeAll()
                }
            }
            .confirmationDialog(
                "Delete this expense?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive, action: deleteExpense)
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showingTagPicker) {
                TagPickerSheet(selectedIDs: $selectedTagIDs)
            }
        }
    }

    // MARK: - Auto-detect

    /// Resolve which account should receive returned money for a given currency.
    /// Preference order:
    ///   1. First non-archived **Cash** account in that currency (sorted by sortOrder, then name)
    ///   2. First non-archived account of any type in that currency
    ///   3. nil → balance math falls back to crediting the source account
    private func autoDetectReturnAccount(for currency: Currency) -> Account? {
        let matching = accounts.filter { $0.currency == currency }
        if let cash = matching.first(where: { $0.type == .cash }) {
            return cash
        }
        return matching.first
    }

    private var autoReturnAccountName: String? {
        guard let id = returnedToAccountID,
              let acc = accounts.first(where: { $0.id == id }) else { return nil }
        return "\(acc.name) (\(acc.currency.displayCode))"
    }

    // MARK: - Split-payment helpers

    /// Save button enabled only when:
    /// - Primary amount > 0
    /// - If split: each payment leg has amount > 0 and a chosen account
    /// - Every additional return leg has amount > 0
    private var canSave: Bool {
        guard amount > 0 else { return false }
        if splitEnabled {
            for leg in legs {
                if leg.amount <= 0 || leg.accountID == nil { return false }
            }
        }
        for r in returnLegs {
            if r.amount <= 0 { return false }
        }
        return true
    }

    /// Total of all returns (primary + legs) in the primary expense currency.
    private func totalReturnInDisplayCurrency() -> (amount: Decimal, currency: Currency) {
        let display = currency
        let rate = useRateOverride ? rateOverride : (settings?.usdToLbpRate ?? 90_000)
        var total: Decimal = 0
        if let primary = amountReturned, primary > 0 {
            let primaryCurrency = returnedCurrency ?? display
            total += CurrencyService.convert(primary, from: primaryCurrency, to: display, usdToLbpRate: rate)
        }
        for r in returnLegs where r.amount > 0 {
            total += CurrencyService.convert(r.amount, from: r.currency, to: display, usdToLbpRate: rate)
        }
        return (total, display)
    }

    /// Sum of primary + all legs in a useful display currency for the footer label.
    /// Prefers the primary expense currency; if not enough info, falls back to USD.
    private func totalInDisplayCurrency() -> (amount: Decimal, currency: Currency) {
        let display = currency
        let rate = useRateOverride ? rateOverride : (settings?.usdToLbpRate ?? 90_000)
        var total = CurrencyService.convert(amount, from: currency, to: display, usdToLbpRate: rate)
        for leg in legs {
            total += CurrencyService.convert(leg.amount, from: leg.currency, to: display, usdToLbpRate: rate)
        }
        return (total, display)
    }

    // MARK: - Load / save

    private func load() {
        if let exp = expense {
            amount = exp.amount
            currency = exp.currency
            date = exp.date
            note = exp.note
            accountID = exp.account?.id
            categoryID = exp.category?.id
            amountReturned = exp.amountReturned
            returnedCurrency = exp.returnedCurrency
            returnedToAccountID = exp.returnedToAccount?.id
            // An existing expense with an explicit return account is treated as
            // "user-chosen" so we don't auto-overwrite it when the currency changes.
            hasManuallyChosenReturnAccount = (exp.returnedToAccount != nil)
            if let o = exp.exchangeRateOverride {
                useRateOverride = true
                rateOverride = o
            }
            // Load existing payment legs into draft state.
            let sortedLegs = (exp.additionalPayments ?? []).sorted { $0.sortOrder < $1.sortOrder }
            if !sortedLegs.isEmpty {
                splitEnabled = true
                legs = sortedLegs.map { leg in
                    DraftPaymentLeg(
                        modelID: leg.id,
                        amount: leg.amount,
                        currency: leg.currency,
                        accountID: leg.account?.id
                    )
                }
            }
            // Load existing return legs into draft state.
            let sortedReturns = (exp.additionalReturns ?? []).sorted { $0.sortOrder < $1.sortOrder }
            returnLegs = sortedReturns.map { r in
                DraftReturnLeg(
                    modelID: r.id,
                    amount: r.amount,
                    currency: r.currency,
                    accountID: r.account?.id,
                    hasManualAccount: r.account != nil
                )
            }
            // Load tag selection.
            selectedTagIDs = Set((exp.tags ?? []).map(\.id))
            // Load existing receipt.
            originalReceiptFilename = exp.receiptImageName
            currentReceiptFilename = exp.receiptImageName
        } else if let template = prefilledFrom {
            // New expense seeded from a template.
            amount = template.amount
            currency = template.currency
            note = template.note
            accountID = template.account?.id
            categoryID = template.category?.id
            selectedTagIDs = Set((template.tags ?? []).map(\.id))
            if let s = settings { rateOverride = s.usdToLbpRate }
        } else {
            // New expense — pick sensible defaults.
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
        }
    }

    private func save() {
        let chosenAccount = accounts.first { $0.id == accountID }
        let chosenCategory = categories.first { $0.id == categoryID }
        let chosenReturnAccount = accounts.first { $0.id == returnedToAccountID }
        let resolvedTags = fetchTags(for: selectedTagIDs)

        let target: Expense
        if let exp = expense {
            exp.amount = amount
            exp.currency = currency
            exp.date = date
            exp.note = note
            exp.account = chosenAccount
            exp.category = chosenCategory
            exp.amountReturned = amountReturned
            exp.returnedCurrency = returnedCurrency
            exp.returnedToAccount = amountReturned != nil ? chosenReturnAccount : nil
            exp.exchangeRateOverride = useRateOverride ? rateOverride : nil
            exp.tags = resolvedTags
            ReceiptFieldRow.commit(
                pickedImage: pickedReceiptImage,
                currentFilename: currentReceiptFilename,
                originalFilename: originalReceiptFilename
            ) { newFilename in
                exp.receiptImageName = newFilename
            }
            target = exp
        } else {
            let new = Expense(
                date: date,
                amount: amount,
                currency: currency,
                exchangeRateOverride: useRateOverride ? rateOverride : nil,
                note: note,
                amountReturned: amountReturned,
                returnedCurrency: returnedCurrency,
                returnedToAccount: amountReturned != nil ? chosenReturnAccount : nil,
                account: chosenAccount,
                category: chosenCategory
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
            target = new

            // Bump the template's usage statistics so the picker can sort by it.
            if let template = prefilledFrom {
                template.usageCount += 1
                template.lastUsedAt = Date()
            }
        }

        // Reconcile additional payment legs.
        // Strategy: delete any existing leg not in drafts, update legs whose modelID we know,
        // insert new legs for drafts without a modelID.
        let existingLegs = target.additionalPayments ?? []
        let draftIDs = Set(legs.compactMap { $0.modelID })

        // Delete legs that the user removed.
        for leg in existingLegs where !draftIDs.contains(leg.id) {
            context.delete(leg)
        }

        if splitEnabled {
            for (index, draft) in legs.enumerated() {
                let legAccount = accounts.first { $0.id == draft.accountID }
                if let modelID = draft.modelID,
                   let existing = existingLegs.first(where: { $0.id == modelID }) {
                    existing.amount = draft.amount
                    existing.currency = draft.currency
                    existing.account = legAccount
                    existing.sortOrder = index
                } else {
                    let newLeg = PaymentLeg(
                        amount: draft.amount,
                        currency: draft.currency,
                        sortOrder: index,
                        account: legAccount,
                        expense: target
                    )
                    context.insert(newLeg)
                }
            }
        }

        // Reconcile additional return legs.
        // Returns only exist when the primary "Money returned" toggle is on
        // (i.e. amountReturned != nil). If the toggle is off, drop everything.
        let existingReturns = target.additionalReturns ?? []
        if amountReturned == nil {
            for r in existingReturns { context.delete(r) }
        } else {
            let draftReturnIDs = Set(returnLegs.compactMap { $0.modelID })
            for r in existingReturns where !draftReturnIDs.contains(r.id) {
                context.delete(r)
            }
            for (index, draft) in returnLegs.enumerated() {
                let legAccount = accounts.first { $0.id == draft.accountID }
                if let modelID = draft.modelID,
                   let existing = existingReturns.first(where: { $0.id == modelID }) {
                    existing.amount = draft.amount
                    existing.currency = draft.currency
                    existing.account = legAccount
                    existing.sortOrder = index
                } else {
                    let newReturn = ReturnLeg(
                        amount: draft.amount,
                        currency: draft.currency,
                        sortOrder: index,
                        account: legAccount,
                        expense: target
                    )
                    context.insert(newReturn)
                }
            }
        }

        try? context.save()
        WidgetRefresh.bump()
        BudgetNotificationService.checkAndNotify(in: context)
        dismiss()
    }

    /// Resolve a set of Tag IDs into actual Tag instances from the model store.
    private func fetchTags(for ids: Set<UUID>) -> [Tag] {
        guard !ids.isEmpty else { return [] }
        let descriptor = FetchDescriptor<Tag>(predicate: #Predicate<Tag> { ids.contains($0.id) })
        return (try? context.fetch(descriptor)) ?? []
    }

    private func deleteExpense() {
        guard let exp = expense else { return }
        if let receiptName = exp.receiptImageName {
            ReceiptStore.delete(filename: receiptName)
        }
        context.delete(exp)
        try? context.save()
        WidgetRefresh.bump()
        BudgetNotificationService.checkAndNotify(in: context)
        dismiss()
    }
}

/// Transient UI state for one additional payment leg. Maps to a PaymentLeg
/// SwiftData model on save (modelID set for existing legs, nil for new ones).
struct DraftPaymentLeg: Identifiable {
    let id: UUID = UUID()
    var modelID: UUID? = nil
    var amount: Decimal
    var currency: Currency
    var accountID: UUID?
}

/// Transient UI state for one additional return leg.
/// `hasManualAccount` tracks whether the user has explicitly chosen the
/// destination account for this leg — once true, currency changes no longer
/// overwrite the choice via auto-detection.
struct DraftReturnLeg: Identifiable {
    let id: UUID = UUID()
    var modelID: UUID? = nil
    var amount: Decimal
    var currency: Currency
    var accountID: UUID?
    var hasManualAccount: Bool = false
}
