//
//  IncomeSource.swift
//  ExpenseTracker
//
//  Categorization for incomes (Salary, Freelance, Gift, etc.). Separate from
//  Expense Categories so analytics and UI don't mix unrelated buckets.
//

import Foundation
import SwiftData

@Model
final class IncomeSource {
    var id: UUID = UUID()
    var name: String = ""
    var iconName: String = "dollarsign.circle.fill"
    var colorHex: String = "#34C759"
    var isCustom: Bool = false
    var sortOrder: Int = 0
    var createdAt: Date = Date()

    @Relationship(deleteRule: .nullify, inverse: \Income.source)
    var incomes: [Income]? = []

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

/// Default income sources inserted on first launch.
enum SeedIncomeSources {
    struct Seed {
        let name: String
        let icon: String
        let color: String
    }

    static let all: [Seed] = [
        .init(name: "Salary",     icon: "briefcase.fill",                  color: "#34C759"),
        .init(name: "Freelance",  icon: "laptopcomputer",                  color: "#0A84FF"),
        .init(name: "Gift",       icon: "gift.fill",                       color: "#FF2D55"),
        .init(name: "Refund",     icon: "arrow.uturn.left.circle.fill",    color: "#FF9500"),
        .init(name: "Investment", icon: "chart.line.uptrend.xyaxis",       color: "#AF52DE"),
        .init(name: "Other",      icon: "ellipsis.circle.fill",            color: "#8E8E93"),
    ]
}
