//
//  Account.swift
//  ExpenseTracker
//
//  An account holds money in a single currency. The user can have many of each type.
//

import Foundation
import SwiftData

enum AccountType: String, CaseIterable, Codable, Identifiable, Sendable {
    case cash
    case card
    case savings

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cash:    return "Cash"
        case .card:    return "Card"
        case .savings: return "Savings"
        }
    }

    /// Default SF Symbol for an account of this type.
    var defaultSymbol: String {
        switch self {
        case .cash:    return "banknote.fill"
        case .card:    return "creditcard.fill"
        case .savings: return "building.columns.fill"
        }
    }
}

@Model
final class Account {
    var id: UUID = UUID()
    var name: String = ""
    var typeRaw: String = AccountType.cash.rawValue
    var currencyRaw: String = Currency.usd.rawValue
    var initialBalance: Decimal = Decimal(0)
    var colorHex: String = "#4F8EF7"
    var iconName: String = "banknote.fill"
    var sortOrder: Int = 0
    var isArchived: Bool = false
    var createdAt: Date = Date()

    // Inverse relationships — populated by SwiftData.
    @Relationship(deleteRule: .nullify, inverse: \Expense.account)
    var expenses: [Expense]? = []

    /// Expenses where this account is the destination of a "money returned" credit.
    @Relationship(deleteRule: .nullify, inverse: \Expense.returnedToAccount)
    var expenseReturnsReceived: [Expense]? = []

    /// Additional payment legs that draw from this account
    /// (used by split-currency / multi-account expenses).
    @Relationship(deleteRule: .nullify, inverse: \PaymentLeg.account)
    var paymentLegs: [PaymentLeg]? = []

    /// Additional return legs that credit money INTO this account
    /// (used by multi-currency / multi-account refunds).
    @Relationship(deleteRule: .nullify, inverse: \ReturnLeg.account)
    var returnLegsReceived: [ReturnLeg]? = []

    /// Money flowing in to this account: salary, freelance pay, gifts, etc.
    @Relationship(deleteRule: .nullify, inverse: \Income.account)
    var incomes: [Income]? = []

    @Relationship(deleteRule: .nullify, inverse: \Transfer.fromAccount)
    var transfersOut: [Transfer]? = []

    @Relationship(deleteRule: .nullify, inverse: \Transfer.toAccount)
    var transfersIn: [Transfer]? = []

    @Relationship(deleteRule: .nullify, inverse: \Subscription.account)
    var subscriptions: [Subscription]? = []

    @Relationship(deleteRule: .nullify, inverse: \ExpectedExpense.account)
    var expectedExpenses: [ExpectedExpense]? = []

    init(
        id: UUID = UUID(),
        name: String,
        type: AccountType,
        currency: Currency,
        initialBalance: Decimal = 0,
        colorHex: String = "#4F8EF7",
        iconName: String? = nil,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.typeRaw = type.rawValue
        self.currencyRaw = currency.rawValue
        self.initialBalance = initialBalance
        self.colorHex = colorHex
        self.iconName = iconName ?? type.defaultSymbol
        self.sortOrder = sortOrder
        self.isArchived = false
        self.createdAt = Date()
    }

    var type: AccountType {
        get { AccountType(rawValue: typeRaw) ?? .cash }
        set { typeRaw = newValue.rawValue }
    }

    var currency: Currency {
        get { Currency(rawValue: currencyRaw) ?? .usd }
        set { currencyRaw = newValue.rawValue }
    }
}
