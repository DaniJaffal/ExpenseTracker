//
//  Budget.swift
//  ExpenseTracker
//
//  Per-category monthly spending limit. The amount lives in the user's
//  default currency (AppSettings.defaultCurrency); expenses in other
//  currencies are converted via the current exchange rate when computing
//  month-to-date spend against the budget.
//
//  v1 model: one budget per category. To change the amount over time,
//  edit in place — no historical tracking.
//

import Foundation
import SwiftData

@Model
final class Budget {
    var id: UUID = UUID()

    /// Monthly cap, in the user's default currency.
    var monthlyAmount: Decimal = Decimal(0)

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    /// Last time we fired the 80%-warning notification for this budget.
    /// Used to avoid spamming — re-armed at the start of each calendar month.
    var lastNotifiedAt80: Date?

    /// Last time we fired the 100%-over-budget notification.
    var lastNotifiedAt100: Date?

    @Relationship var category: Category?

    init(
        id: UUID = UUID(),
        monthlyAmount: Decimal,
        category: Category? = nil
    ) {
        self.id = id
        self.monthlyAmount = monthlyAmount
        self.category = category
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
