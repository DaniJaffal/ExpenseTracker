//
//  ReturnLeg.swift
//  ExpenseTracker
//
//  Additional "money returned" legs for an expense. Mirrors PaymentLeg but for
//  refund / change handed back. Used when the user receives the change in
//  multiple currencies or wants to route portions to different accounts
//  (e.g. paid $50 USD, got back $40 USD into cash USD and the remainder as LBP cash).
//

import Foundation
import SwiftData

@Model
final class ReturnLeg {
    var id: UUID = UUID()
    var amount: Decimal = Decimal(0)
    var currencyRaw: String = Currency.usd.rawValue
    var sortOrder: Int = 0
    var createdAt: Date = Date()

    @Relationship var account: Account?
    @Relationship var expense: Expense?

    init(
        id: UUID = UUID(),
        amount: Decimal,
        currency: Currency,
        sortOrder: Int = 0,
        account: Account? = nil,
        expense: Expense? = nil
    ) {
        self.id = id
        self.amount = amount
        self.currencyRaw = currency.rawValue
        self.sortOrder = sortOrder
        self.account = account
        self.expense = expense
        self.createdAt = Date()
    }

    var currency: Currency {
        get { Currency(rawValue: currencyRaw) ?? .usd }
        set { currencyRaw = newValue.rawValue }
    }
}
