//
//  Category.swift
//  ExpenseTracker
//
//  Expense category. Seed list inserted on first launch; user can add custom ones.
//

import Foundation
import SwiftData

@Model
final class Category {
    var id: UUID = UUID()
    var name: String = ""
    var iconName: String = "tag.fill"   // SF Symbol
    var colorHex: String = "#8E8E93"
    var isCustom: Bool = false
    var sortOrder: Int = 0
    var createdAt: Date = Date()

    @Relationship(deleteRule: .nullify, inverse: \Expense.category)
    var expenses: [Expense]? = []

    @Relationship(deleteRule: .nullify, inverse: \Subscription.category)
    var subscriptions: [Subscription]? = []

    @Relationship(deleteRule: .nullify, inverse: \ExpectedExpense.category)
    var expectedExpenses: [ExpectedExpense]? = []

    /// At most one Budget per category. Cascade-delete: removing the
    /// category also removes its budget.
    @Relationship(deleteRule: .cascade, inverse: \Budget.category)
    var budget: Budget?

    init(
        id: UUID = UUID(),
        name: String,
        iconName: String,
        colorHex: String,
        isCustom: Bool = false,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.isCustom = isCustom
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }
}

/// Default categories created on first launch.
enum SeedCategories {
    struct Seed {
        let name: String
        let icon: String
        let color: String
    }

    static let all: [Seed] = [
        .init(name: "Food & Drink",   icon: "fork.knife",            color: "#FF8C42"),
        .init(name: "Groceries",      icon: "cart.fill",             color: "#34C759"),
        .init(name: "Transport",      icon: "car.fill",              color: "#5AC8FA"),
        .init(name: "Bills",          icon: "doc.text.fill",         color: "#FF3B30"),
        .init(name: "Entertainment",  icon: "tv.fill",               color: "#AF52DE"),
        .init(name: "Shopping",       icon: "bag.fill",              color: "#FF2D55"),
        .init(name: "Health",         icon: "cross.case.fill",       color: "#FF6B6B"),
        .init(name: "Home",           icon: "house.fill",            color: "#A2845E"),
        .init(name: "Travel",         icon: "airplane",              color: "#0A84FF"),
        .init(name: "Subscriptions",  icon: "repeat.circle.fill",    color: "#5856D6"),
        .init(name: "Education",      icon: "book.fill",             color: "#FFCC00"),
        .init(name: "Gifts",          icon: "gift.fill",             color: "#FF9500"),
        .init(name: "Other",          icon: "ellipsis.circle.fill",  color: "#8E8E93"),
    ]
}
