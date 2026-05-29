//
//  Income.swift
//  ExpenseTracker
//
//  Money flowing IN to an account: salary, freelance pay, gifts, refunds, etc.
//  Symmetric to Expense (money out) but simpler — no split-tender, no returns.
//

import Foundation
import SwiftData

@Model
final class Income {
    var id: UUID = UUID()
    var date: Date = Date()
    var amount: Decimal = Decimal(0)
    var currencyRaw: String = Currency.usd.rawValue

    /// Optional per-income USD→LBP rate override. nil = use AppSettings rate.
    var exchangeRateOverride: Decimal?

    var note: String = ""
    var createdAt: Date = Date()

    @Relationship var account: Account?
    @Relationship var source: IncomeSource?

    /// Cross-cutting labels applied to this income. Many-to-many with Tag.
    /// The inverse `Tag.incomes` declares the relationship metadata.
    var tags: [Tag]? = []

    /// Filename of the attached receipt image on disk (in App Group's
    /// Receipts/ folder). nil = no attachment.
    var receiptImageName: String?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        amount: Decimal,
        currency: Currency,
        exchangeRateOverride: Decimal? = nil,
        note: String = "",
        account: Account? = nil,
        source: IncomeSource? = nil
    ) {
        self.id = id
        self.date = date
        self.amount = amount
        self.currencyRaw = currency.rawValue
        self.exchangeRateOverride = exchangeRateOverride
        self.note = note
        self.account = account
        self.source = source
        self.createdAt = Date()
    }

    var currency: Currency {
        get { Currency(rawValue: currencyRaw) ?? .usd }
        set { currencyRaw = newValue.rawValue }
    }
}
