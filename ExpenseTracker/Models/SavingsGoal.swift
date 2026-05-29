//
//  SavingsGoal.swift
//  ExpenseTracker
//
//  A savings target linked to a single account. Progress is tracked
//  manually via `contributedAmount` because multiple goals can share
//  one account, and auto-allocating a shared balance across goals
//  would be misleading.
//
//  The currency of the goal is derived from the linked account.
//

import Foundation
import SwiftData

@Model
final class SavingsGoal {
    var id: UUID = UUID()
    var name: String = ""

    /// Target amount, in the linked account's currency.
    var targetAmount: Decimal = Decimal(0)

    /// User-tracked cumulative contribution toward this goal.
    var contributedAmount: Decimal = Decimal(0)

    var deadline: Date?
    var iconName: String = "star.fill"
    var colorHex: String = "#5856D6"
    var note: String = ""
    var sortOrder: Int = 0

    /// When the user marks the goal as complete (set when contributedAmount
    /// first reaches the target, or manually).
    var completedDate: Date?

    var createdAt: Date = Date()

    @Relationship var account: Account?

    init(
        id: UUID = UUID(),
        name: String,
        targetAmount: Decimal,
        contributedAmount: Decimal = 0,
        account: Account? = nil,
        deadline: Date? = nil,
        iconName: String = "star.fill",
        colorHex: String = "#5856D6",
        note: String = "",
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.targetAmount = targetAmount
        self.contributedAmount = contributedAmount
        self.account = account
        self.deadline = deadline
        self.iconName = iconName
        self.colorHex = colorHex
        self.note = note
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }

    var currency: Currency {
        account?.currency ?? .usd
    }

    var remaining: Decimal {
        max(0, targetAmount - contributedAmount)
    }

    var fraction: Double {
        guard targetAmount > 0 else { return 0 }
        let s = NSDecimalNumber(decimal: contributedAmount).doubleValue
        let t = NSDecimalNumber(decimal: targetAmount).doubleValue
        return max(0, min(1, s / t))
    }

    var percent: Int {
        guard targetAmount > 0 else { return 0 }
        let s = NSDecimalNumber(decimal: contributedAmount).doubleValue
        let t = NSDecimalNumber(decimal: targetAmount).doubleValue
        return Int(((s / t) * 100).rounded())
    }

    var isComplete: Bool {
        contributedAmount >= targetAmount && targetAmount > 0
    }
}
