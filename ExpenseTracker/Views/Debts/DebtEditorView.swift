//
//  DebtEditorView.swift
//  ExpenseTracker
//
//  Add or edit a single debt entry. Informational only — no balance impact.
//

import SwiftUI
import SwiftData

struct DebtEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let debt: Debt?

    @State private var direction: DebtDirection = .owedToMe
    @State private var personName: String = ""
    @State private var amount: Decimal = 0
    @State private var currency: Currency = .usd
    @State private var hasDueDate: Bool = false
    @State private var dueDate: Date = Date()
    @State private var note: String = ""
    @State private var isSettled: Bool = false
    @State private var settledDate: Date?
    @State private var showDeleteConfirm = false

    private var isEditing: Bool { debt != nil }

    var body: some View {
        Form {
            Section {
                Picker("Type", selection: $direction) {
                    ForEach(DebtDirection.allCases) { d in
                        Text(d.displayName).tag(d)
                    }
                }
                .pickerStyle(.segmented)
            } footer: {
                Text(direction == .owedToMe
                     ? "Someone owes you money. Tracking only — your accounts aren't affected."
                     : "You owe someone money. Tracking only — your accounts aren't affected.")
            }

            Section("Who") {
                TextField("Person or place", text: $personName)
            }

            Section {
                CurrencyAmountField(title: "Amount", amount: $amount, currency: $currency)
            } header: {
                Text("Amount")
            }

            Section {
                Toggle("Set a due date", isOn: $hasDueDate)
                if hasDueDate {
                    DatePicker("Due", selection: $dueDate, displayedComponents: .date)
                }
            } header: {
                Text("Due")
            }

            Section("Note") {
                TextField("What's this for?", text: $note, axis: .vertical)
                    .lineLimit(1...4)
            }

            if isEditing {
                Section {
                    Toggle("Settled", isOn: $isSettled)
                    if isSettled, let date = settledDate {
                        HStack {
                            Text("Settled on")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(Formatters.date(date))
                                .foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    Text(isSettled
                         ? "This debt is resolved. It still appears in the history."
                         : "Mark settled when the money has changed hands.")
                }

                Section {
                    Button("Delete Debt", role: .destructive) {
                        showDeleteConfirm = true
                    }
                }
            }
        }
        .navigationTitle(isEditing ? "Edit Debt" : "New Debt")
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
        .onChange(of: isSettled) { _, newValue in
            // Stamp / clear the settledDate when the toggle flips.
            if newValue && settledDate == nil { settledDate = Date() }
            if !newValue { settledDate = nil }
        }
        .confirmationDialog(
            "Delete this debt?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive, action: deleteDebt)
            Button("Cancel", role: .cancel) {}
        }
    }

    private var canSave: Bool {
        !personName.trimmingCharacters(in: .whitespaces).isEmpty && amount > 0
    }

    private func load() {
        guard let d = debt else { return }
        direction = d.direction
        personName = d.personName
        amount = d.amount
        currency = d.currency
        if let due = d.dueDate {
            hasDueDate = true
            dueDate = due
        }
        note = d.note
        isSettled = d.isSettled
        settledDate = d.settledDate
    }

    private func save() {
        let trimmedName = personName.trimmingCharacters(in: .whitespacesAndNewlines)
        if let d = debt {
            d.personName = trimmedName
            d.amount = amount
            d.currency = currency
            d.direction = direction
            d.note = note
            d.dueDate = hasDueDate ? dueDate : nil
            d.isSettled = isSettled
            d.settledDate = isSettled ? (settledDate ?? Date()) : nil
        } else {
            let new = Debt(
                personName: trimmedName,
                amount: amount,
                currency: currency,
                direction: direction,
                note: note,
                dueDate: hasDueDate ? dueDate : nil
            )
            context.insert(new)
        }
        try? context.save()
        dismiss()
    }

    private func deleteDebt() {
        guard let d = debt else { return }
        context.delete(d)
        try? context.save()
        dismiss()
    }
}
