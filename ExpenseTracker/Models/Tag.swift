//
//  Tag.swift
//  ExpenseTracker
//
//  Cross-cutting labels for expenses and incomes. Categories are mutually
//  exclusive (one per item); tags are additive (many per item, applied
//  across categories). Useful for things like "Work trip", "Christmas",
//  "Family" that span multiple expense categories.
//

import Foundation
import SwiftData

@Model
final class Tag {
    var id: UUID = UUID()
    var name: String = ""
    var colorHex: String = "#5856D6"
    var sortOrder: Int = 0
    var createdAt: Date = Date()

    /// Expenses tagged with this tag. Many-to-many.
    /// Deleting a tag nullifies (removes) the reference from the expense's
    /// own tag list, but leaves the expense intact.
    @Relationship(deleteRule: .nullify, inverse: \Expense.tags)
    var expenses: [Expense]? = []

    /// Incomes tagged with this tag. Same semantics.
    @Relationship(deleteRule: .nullify, inverse: \Income.tags)
    var incomes: [Income]? = []

    /// Expense templates that include this tag. When the user picks a template,
    /// its tags are copied onto the new expense.
    @Relationship(deleteRule: .nullify, inverse: \ExpenseTemplate.tags)
    var templates: [ExpenseTemplate]? = []

    init(
        id: UUID = UUID(),
        name: String,
        colorHex: String = "#5856D6",
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }
}
