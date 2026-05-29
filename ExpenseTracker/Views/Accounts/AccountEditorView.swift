//
//  AccountEditorView.swift
//  ExpenseTracker
//

import SwiftUI
import SwiftData

struct AccountEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let account: Account?

    @State private var name: String = ""
    @State private var type: AccountType = .cash
    @State private var currency: Currency = .usd
    @State private var initialBalance: Decimal = 0
    @State private var iconName: String = "banknote.fill"
    @State private var colorHex: String = "#4F8EF7"
    @State private var isArchived: Bool = false
    @State private var showDeleteConfirm = false

    private var isEditing: Bool { account != nil }

    var body: some View {
        Form {
            Section("Basics") {
                TextField("Name (e.g. Wallet, Visa)", text: $name)
                Picker("Type", selection: $type) {
                    ForEach(AccountType.allCases) { t in
                        Text(t.displayName).tag(t)
                    }
                }
                Picker("Currency", selection: $currency) {
                    ForEach(Currency.allCases) { c in
                        Text("\(c.displayCode) — \(c.fullName)").tag(c)
                    }
                }
                .disabled(isEditing)
                if isEditing {
                    Text("Currency can't change after creation — expenses already reference this account.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Initial balance") {
                HStack {
                    TextField("0", value: $initialBalance, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                    Text(currency.displayCode).foregroundStyle(.secondary)
                }
            }

            Section("Appearance") {
                IconColorPicker(iconName: $iconName, colorHex: $colorHex)
            }

            if isEditing {
                Section {
                    Toggle("Archive account", isOn: $isArchived)
                    Button("Delete Account", role: .destructive) {
                        showDeleteConfirm = true
                    }
                } footer: {
                    Text("Archiving hides this account but keeps its expense history. Deleting removes the account and unlinks its expenses.")
                }
            }
        }
        .navigationTitle(isEditing ? account?.name ?? "Account" : "New Account")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear(perform: load)
        .onChange(of: type) { _, newValue in
            if !isEditing { iconName = newValue.defaultSymbol }
        }
        .confirmationDialog(
            "Delete this account?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive, action: deleteAccount)
            Button("Cancel", role: .cancel) {}
        }
    }

    private func load() {
        guard let acc = account else { return }
        name = acc.name
        type = acc.type
        currency = acc.currency
        initialBalance = acc.initialBalance
        iconName = acc.iconName
        colorHex = acc.colorHex
        isArchived = acc.isArchived
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let acc = account {
            acc.name = trimmed
            acc.type = type
            // currency intentionally not updated
            acc.initialBalance = initialBalance
            acc.iconName = iconName
            acc.colorHex = colorHex
            acc.isArchived = isArchived
        } else {
            let new = Account(
                name: trimmed,
                type: type,
                currency: currency,
                initialBalance: initialBalance,
                colorHex: colorHex,
                iconName: iconName
            )
            context.insert(new)
        }
        try? context.save()
        WidgetRefresh.bump()
        dismiss()
    }

    private func deleteAccount() {
        guard let acc = account else { return }
        context.delete(acc)
        try? context.save()
        WidgetRefresh.bump()
        dismiss()
    }
}
