//
//  PaymentLeg.swift
//  ExpenseTracker
//
//  Additional payment legs for split-currency / multi-account expenses.
//  An Expense's primary amount/currency/account is the first leg; this model
//  represents any *additional* legs needed to record a transaction paid with
//  more than one tender (e.g. $10 USD card + 500 000 LBP cash for one bill).
//

import Foundation
import SwiftData

@Model
final class PaymentLeg {
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
