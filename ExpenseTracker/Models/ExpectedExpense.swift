//
//  ExpectedExpense.swift
//  ExpenseTracker
//
//  Upcoming planned expenses — loans, bills, anything you expect to pay.
//

import Foundation
import SwiftData

enum ExpectedRecurrence: String, CaseIterable, Codable, Identifiable, Sendable {
    case once
    case weekly
    case monthly
    case quarterly
    case yearly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .once:      return "One-time"
        case .weekly:    return "Weekly"
        case .monthly:   return "Monthly"
        case .quarterly: return "Quarterly"
        case .yearly:    return "Yearly"
        }
    }

    var dateComponent: (Calendar.Component, Int)? {
        switch self {
        case .once:      return nil
        case .weekly:    return (.weekOfYear, 1)
        case .monthly:   return (.month, 1)
        case .quarterly: return (.month, 3)
        case .yearly:    return (.year, 1)
        }
    }
}

@Model
final class ExpectedExpense {
    var id: UUID = UUID()
    var name: String = ""
    var amount: Decimal = Decimal(0)
    var currencyRaw: String = Currency.usd.rawValue
    var dueDate: Date = Date()
    var recurrenceRaw: String = ExpectedRecurrence.once.rawValue
    var isPaid: Bool = false
    var paidDate: Date?
    var notificationLeadDays: Int = 2
    var notificationsEnabled: Bool = false
    var note: String = ""
    var createdAt: Date = Date()

    @Relationship var account: Account?
    @Relationship var category: Category?

    @Relationship(deleteRule: .nullify, inverse: \Expense.expectedExpense)
    var paidExpenses: [Expense]? = []

    init(
        id: UUID = UUID(),
        name: String,
        amount: Decimal,
        currency: Currency,
        dueDate: Date,
        recurrence: ExpectedRecurrence = .once,
        notificationLeadDays: Int = 2,
        notificationsEnabled: Bool = false,
        note: String = "",
        account: Account? = nil,
        category: Category? = nil
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.currencyRaw = currency.rawValue
        self.dueDate = dueDate
        self.recurrenceRaw = recurrence.rawValue
        self.notificationLeadDays = notificationLeadDays
        self.notificationsEnabled = notificationsEnabled
        self.note = note
        self.account = account
        self.category = category
        self.createdAt = Date()
    }

    var currency: Currency {
        get { Currency(rawValue: currencyRaw) ?? .usd }
        set { currencyRaw = newValue.rawValue }
    }

    var recurrence: ExpectedRecurrence {
        get { ExpectedRecurrence(rawValue: recurrenceRaw) ?? .once }
        set { recurrenceRaw = newValue.rawValue }
    }
}
