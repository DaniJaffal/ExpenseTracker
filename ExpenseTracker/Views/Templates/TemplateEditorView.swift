//
//  TemplateEditorView.swift
//  ExpenseTracker
//
//  Create or edit an expense template. Same fields the template carries:
//  name + appearance, amount + currency, account, category, tags, note.
//

import SwiftUI
import SwiftData

struct TemplateEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let template: ExpenseTemplate?

    @Query(filter: #Predicate<Account> { !$0.isArchived },
           sort: [SortDescriptor(\Account.sortOrder), SortDescriptor(\Account.name)])
    private var accounts: [Account]
    @Query(sort: [SortDescriptor(\Category.sortOrder), SortDescriptor(\Category.name)])
    private var categories: [Category]

    @State private var name: String = ""
    @State private var iconName: String = "star.fill"
    @State private var colorHex: String = "#5856D6"
    @State private var amount: Decimal = 0
    @State private var currency: Currency = .usd
    @State private var note: String = ""
    @State private var accountID: UUID?
    @State private var categoryID: UUID?
    @State private var selectedTagIDs: Set<UUID> = []
    @State private var showingTagPicker = false
    @State private var showDeleteConfirm = false

    private var isEditing: Bool { template != nil }

    var body: some View {
        Form {
            Section("Name & appearance") {
                TextField("Template name (e.g. Morning Coffee)", text: $name)
                IconColorPicker(iconName: $iconName, colorHex: $colorHex)
            }

            Section("Default amount") {
                CurrencyAmountField(title: "Amount", amount: $amount, currency: $currency)
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

            Section("Note") {
                TextField("Default note (optional)", text: $note, axis: .vertical)
                    .lineLimit(1...3)
            }

            if isEditing {
                Section {
                    Button("Delete Template", role: .destructive) {
                        showDeleteConfirm = true
                    }
                }
            }
        }
        .navigationTitle(isEditing ? "Edit Template" : "New Template")
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
        .sheet(isPresented: $showingTagPicker) {
            TagPickerSheet(selectedIDs: $selectedTagIDs)
        }
        .confirmationDialog(
            "Delete this template?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive, action: deleteTemplate)
            Button("Cancel", role: .cancel) {}
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func load() {
        if let t = template {
            name = t.name
            iconName = t.iconName
            colorHex = t.colorHex
            amount = t.amount
            currency = t.currency
            note = t.note
            accountID = t.account?.id
            categoryID = t.category?.id
            selectedTagIDs = Set((t.tags ?? []).map(\.id))
        }
    }

    private func save() {
        let chosenAccount = accounts.first { $0.id == accountID }
        let chosenCategory = categories.first { $0.id == categoryID }
        let resolvedTags = fetchTags(for: selectedTagIDs)
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)

        if let t = template {
            t.name = trimmed
            t.iconName = iconName
            t.colorHex = colorHex
            t.amount = amount
            t.currency = currency
            t.note = note
            t.account = chosenAccount
            t.category = chosenCategory
            t.tags = resolvedTags
        } else {
            let new = ExpenseTemplate(
                name: trimmed,
                iconName: iconName,
                colorHex: colorHex,
                amount: amount,
                currency: currency,
                note: note,
                account: chosenAccount,
                category: chosenCategory
            )
            new.tags = resolvedTags
            context.insert(new)
        }
        try? context.save()
        dismiss()
    }

    private func deleteTemplate() {
        guard let t = template else { return }
        context.delete(t)
        try? context.save()
        dismiss()
    }

    private func fetchTags(for ids: Set<UUID>) -> [Tag] {
        guard !ids.isEmpty else { return [] }
        let descriptor = FetchDescriptor<Tag>(predicate: #Predicate<Tag> { ids.contains($0.id) })
        return (try? context.fetch(descriptor)) ?? []
    }
}
