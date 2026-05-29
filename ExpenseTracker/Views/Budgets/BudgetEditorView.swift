//
//  BudgetEditorView.swift
//  ExpenseTracker
//
//  Add or edit a monthly budget. In add-mode only categories without an
//  existing budget can be picked (one budget per category). In edit-mode
//  the category is fixed.
//

import SwiftUI
import SwiftData

struct BudgetEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// nil = creating new
    let budget: Budget?

    @Query(sort: [SortDescriptor(\Category.sortOrder), SortDescriptor(\Category.name)])
    private var categories: [Category]

    @Query(sort: [SortDescriptor(\AppSettings.createdAt, order: .forward)])
    private var settingsList: [AppSettings]

    @State private var categoryID: UUID?
    @State private var monthlyAmount: Decimal = 0
    @State private var showDeleteConfirm = false

    private var isEditing: Bool { budget != nil }
    private var defaultCurrency: Currency { settingsList.first?.defaultCurrency ?? .usd }

    /// Only categories without an existing budget. Used in add-mode.
    private var assignableCategories: [Category] {
        categories.filter { $0.budget == nil }
    }

    private var chosenCategory: Category? {
        if let budget { return budget.category }
        return categories.first { $0.id == categoryID }
    }

    var body: some View {
        Form {
            Section("Category") {
                if isEditing, let category = budget?.category {
                    HStack {
                        IconBadge(symbol: category.iconName, color: Color(hex: category.colorHex), size: 30)
                        Text(category.name).font(.subheadline.weight(.semibold))
                        Spacer()
                    }
                } else {
                    if assignableCategories.isEmpty {
                        Text("Every category already has a budget. Edit an existing one instead.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Category", selection: $categoryID) {
                            Text("Choose…").tag(UUID?.none)
                            ForEach(assignableCategories) { cat in
                                HStack {
                                    Image(systemName: cat.iconName)
                                    Text(cat.name)
                                }.tag(Optional(cat.id))
                            }
                        }
                    }
                }
            }

            Section {
                HStack {
                    TextField("0", value: $monthlyAmount, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.title3.monospacedDigit())
                    Text(defaultCurrency.displayCode).foregroundStyle(.secondary)
                }
            } header: {
                Text("Monthly cap")
            } footer: {
                Text("All budgets are in your default currency (\(defaultCurrency.fullName)). Expenses in other currencies convert at the app rate.")
            }

            if isEditing {
                Section {
                    Button("Delete Budget", role: .destructive) {
                        showDeleteConfirm = true
                    }
                }
            }
        }
        .navigationTitle(isEditing ? "Edit Budget" : "New Budget")
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
            "Delete this budget?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive, action: deleteBudget)
            Button("Cancel", role: .cancel) {}
        }
    }

    private var canSave: Bool {
        guard monthlyAmount > 0 else { return false }
        if isEditing { return true }
        return categoryID != nil
    }

    private func load() {
        if let b = budget {
            monthlyAmount = b.monthlyAmount
            categoryID = b.category?.id
        } else if let first = assignableCategories.first {
            categoryID = first.id
        }
    }

    private func save() {
        if let b = budget {
            b.monthlyAmount = monthlyAmount
            b.updatedAt = Date()
        } else {
            guard let category = chosenCategory else { return }
            let new = Budget(monthlyAmount: monthlyAmount, category: category)
            context.insert(new)
        }
        try? context.save()
        WidgetRefresh.bump()
        dismiss()
    }

    private func deleteBudget() {
        guard let b = budget else { return }
        context.delete(b)
        try? context.save()
        WidgetRefresh.bump()
        dismiss()
    }
}
