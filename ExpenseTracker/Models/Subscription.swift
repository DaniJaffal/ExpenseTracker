//
//  Subscription.swift
//  ExpenseTracker
//
//  Recurring subscriptions / memberships.
//

import Foundation
import SwiftData

enum BillingCycle: String, CaseIterable, Codable, Identifiable, Sendable {
    case weekly
    case monthly
    case quarterly
    case semiAnnual = "semi_annual"
    case yearly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .weekly:     return "Weekly"
        case .monthly:    return "Monthly"
        case .quarterly:  return "Quarterly"
        case .semiAnnual: return "Semi-Annual"
        case .yearly:     return "Yearly"
        }
    }

    /// Calendar component + value to advance by one cycle.
    var dateComponent: (Calendar.Component, Int) {
        switch self {
        case .weekly:     return (.weekOfYear, 1)
        case .monthly:    return (.month, 1)
        case .quarterly:  return (.month, 3)
        case .semiAnnual: return (.month, 6)
        case .yearly:     return (.year, 1)
        }
    }
}

@Model
final class Subscription {
    var id: UUID = UUID()
    var name: String = ""
    var amount: Decimal = Decimal(0)
    var currencyRaw: String = Currency.usd.rawValue
    var billingCycleRaw: String = BillingCycle.monthly.rawValue
    var startDate: Date = Date()
    var nextRenewalDate: Date = Date()
    var lastChargedDate: Date?
    var notificationLeadDays: Int = 2
    var notificationsEnabled: Bool = false
    var isActive: Bool = true
    var note: String = ""
    var createdAt: Date = Date()

    @Relationship var account: Account?
    @Relationship var category: Category?

    @Relationship(deleteRule: .nullify, inverse: \Expense.subscription)
    var paidExpenses: [Expense]? = []

    init(
        id: UUID = UUID(),
        name: String,
        amount: Decimal,
        currency: Currency,
        billingCycle: BillingCycle,
        startDate: Date,
        nextRenewalDate: Date? = nil,
        notificationLeadDays: Int = 2,
        notificationsEnabled: Bool = false,
        isActive: Bool = true,
        note: String = "",
        account: Account? = nil,
        category: Category? = nil
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.currencyRaw = currency.rawValue
        self.billingCycleRaw = billingCycle.rawValue
        self.startDate = startDate
        self.nextRenewalDate = nextRenewalDate ?? startDate
        self.notificationLeadDays = notificationLeadDays
        self.notificationsEnabled = notificationsEnabled
        self.isActive = isActive
        self.note = note
        self.account = account
        self.category = category
        self.createdAt = Date()
    }

    var currency: Currency {
        get { Currency(rawValue: currencyRaw) ?? .usd }
        set { currencyRaw = newValue.rawValue }
    }

    var billingCycle: BillingCycle {
        get { BillingCycle(rawValue: billingCycleRaw) ?? .monthly }
        set { billingCycleRaw = newValue.rawValue }
    }
}
