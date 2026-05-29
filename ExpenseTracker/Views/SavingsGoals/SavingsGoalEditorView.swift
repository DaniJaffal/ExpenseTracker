//
//  SavingsGoalEditorView.swift
//  ExpenseTracker
//
//  Add or edit a savings goal. Currency is derived from the linked account.
//

import SwiftUI
import SwiftData

struct SavingsGoalEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let goal: SavingsGoal?

    @Query(filter: #Predicate<Account> { !$0.isArchived },
           sort: [SortDescriptor(\Account.sortOrder), SortDescriptor(\Account.name)])
    private var accounts: [Account]

    @State private var name: String = ""
    @State private var targetAmount: Decimal = 0
    @State private var contributedAmount: Decimal = 0
    @State private var accountID: UUID?
    @State private var hasDeadline: Bool = false
    @State private var deadline: Date = Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()
    @State private var iconName: String = "star.fill"
    @State private var colorHex: String = "#5856D6"
    @State private var note: String = ""
    @State private var showDeleteConfirm = false

    private var isEditing: Bool { goal != nil }

    /// Linked account, resolved from state.
    private var chosenAccount: Account? {
        accounts.first { $0.id == accountID }
    }

    private var currency: Currency { chosenAccount?.currency ?? .usd }

    /// Savings accounts shown first as the suggested choice.
    private var sortedAccounts: [Account] {
        accounts.sorted { lhs, rhs in
            if lhs.type == .savings && rhs.type != .savings { return true }
            if lhs.type != .savings && rhs.type == .savings { return false }
            return (lhs.sortOrder, lhs.name) < (rhs.sortOrder, rhs.name)
        }
    }

    var body: some View {
        Form {
            Section("Goal") {
                TextField("Name (e.g. Trip to Japan)", text: $name)
            }

            Section {
                Picker("Saving in", selection: $accountID) {
                    Text("Choose…").tag(UUID?.none)
                    ForEach(sortedAccounts) { acc in
                        HStack {
                            Image(systemName: acc.iconName)
                            Text("\(acc.name) (\(acc.currency.displayCode))")
                            if acc.type == .savings {
                                Text("· Savings")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tag(Optional(acc.id))
                    }
                }
            } header: {
                Text("Account")
            } footer: {
                Text("Goal amount and progress are in this account's currency.")
            }

            Section("Target & progress") {
                HStack {
                    Text("Target")
                    Spacer()
                    TextField("0", value: $targetAmount, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.title3.monospacedDigit())
                    Text(currency.displayCode).foregroundStyle(.secondary)
                }
                if isEditing {
                    HStack {
                        Text("Saved so far")
                        Spacer()
                        TextField("0", value: $contributedAmount, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.title3.monospacedDigit())
                        Text(currency.displayCode).foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Toggle("Set a deadline", isOn: $hasDeadline)
                if hasDeadline {
                    DatePicker("Deadline", selection: $deadline, displayedComponents: .date)
                }
            } header: {
                Text("Deadline")
            }

            Section("Appearance") {
                IconColorPicker(iconName: $iconName, colorHex: $colorHex)
            }

            Section("Note") {
                TextField("Anything to remember", text: $note, axis: .vertical)
                    .lineLimit(1...4)
            }

            if isEditing {
                Section {
                    Button("Delete Goal", role: .destructive) {
                        showDeleteConfirm = true
                    }
                }
            }
        }
        .navigationTitle(isEditing ? "Edit Goal" : "New Goal")
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
        .confirmationDialog(
            "Delete this goal?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive, action: deleteGoal)
            Button("Cancel", role: .cancel) {}
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && targetAmount > 0
            && accountID != nil
    }

    private func load() {
        if let g = goal {
            name = g.name
            targetAmount = g.targetAmount
            contributedAmount = g.contributedAmount
            accountID = g.account?.id
            if let dl = g.deadline {
                hasDeadline = true
                deadline = dl
            }
            iconName = g.iconName
            colorHex = g.colorHex
            note = g.note
        } else {
            // Default the picker to the first savings account if any.
            if let savings = accounts.first(where: { $0.type == .savings }) {
                accountID = savings.id
            } else if let first = accounts.first {
                accountID = first.id
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let g = goal {
            let nowComplete = contributedAmount >= targetAmount && targetAmount > 0
            let wasComplete = g.contributedAmount >= g.targetAmount && g.targetAmount > 0
            g.name = trimmed
            g.targetAmount = targetAmount
            g.contributedAmount = contributedAmount
            g.account = chosenAccount
            g.deadline = hasDeadline ? deadline : nil
            g.iconName = iconName
            g.colorHex = colorHex
            g.note = note
            if nowComplete && !wasComplete {
                g.completedDate = Date()
            } else if !nowComplete {
                g.completedDate = nil
            }
        } else {
            let new = SavingsGoal(
                name: trimmed,
                targetAmount: targetAmount,
                contributedAmount: 0,
                account: chosenAccount,
                deadline: hasDeadline ? deadline : nil,
                iconName: iconName,
                colorHex: colorHex,
                note: note
            )
            context.insert(new)
        }
        try? context.save()
        dismiss()
    }

    private func deleteGoal() {
        guard let g = goal else { return }
        context.delete(g)
        try? context.save()
        dismiss()
    }
}
