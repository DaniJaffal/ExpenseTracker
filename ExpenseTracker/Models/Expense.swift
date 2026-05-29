//
//  Expense.swift
//  ExpenseTracker
//
//  A single expense entry. Optionally has money returned (potentially in a different currency).
//

import Foundation
import SwiftData

@Model
final class Expense {
    var id: UUID = UUID()
    var date: Date = Date()
    var amount: Decimal = Decimal(0)
    var currencyRaw: String = Currency.usd.rawValue

    /// Optional per-expense USD→LBP rate override. nil = use AppSettings rate.
    var exchangeRateOverride: Decimal?

    var note: String = ""

    // Money returned (e.g. partial refund, change handed back in another currency)
    var amountReturned: Decimal?
    var returnedCurrencyRaw: String?
    /// Optional per-return USD→LBP rate override (used if returned currency differs from expense currency).
    var returnedExchangeRateOverride: Decimal?

    var createdAt: Date = Date()

    @Relationship var account: Account?
    @Relationship var category: Category?
    @Relationship var subscription: Subscription?
    @Relationship var expectedExpense: ExpectedExpense?

    /// Where the returned money lands. nil = same as `account`.
    /// Auto-resolved by the editor to the first Cash account matching the
    /// returned currency, but the user can override.
    @Relationship var returnedToAccount: Account?

    /// Additional payment legs for split-currency / multi-account expenses.
    /// The Expense's own `amount`/`currency`/`account` represent the *primary*
    /// (first) leg; everything in this list is paid on top.
    @Relationship(deleteRule: .cascade, inverse: \PaymentLeg.expense)
    var additionalPayments: [PaymentLeg]? = []

    /// Additional return legs for multi-currency / multi-account refunds.
    /// `amountReturned`/`returnedCurrency`/`returnedToAccount` represent the
    /// *primary* return; everything in this list is on top of that.
    @Relationship(deleteRule: .cascade, inverse: \ReturnLeg.expense)
    var additionalReturns: [ReturnLeg]? = []

    /// Cross-cutting labels applied to this expense. Many-to-many with Tag.
    /// The inverse `Tag.expenses` declares the relationship metadata.
    var tags: [Tag]? = []

    /// Filename of the attached receipt image on disk (in App Group's
    /// Receipts/ folder). nil = no attachment. Image bytes never live in
    /// the database — only the filename does.
    var receiptImageName: String?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        amount: Decimal,
        currency: Currency,
        exchangeRateOverride: Decimal? = nil,
        note: String = "",
        amountReturned: Decimal? = nil,
        returnedCurrency: Currency? = nil,
        returnedExchangeRateOverride: Decimal? = nil,
        returnedToAccount: Account? = nil,
        account: Account? = nil,
        category: Category? = nil,
        subscription: Subscription? = nil,
        expectedExpense: ExpectedExpense? = nil
    ) {
        self.id = id
        self.date = date
        self.amount = amount
        self.currencyRaw = currency.rawValue
        self.exchangeRateOverride = exchangeRateOverride
        self.note = note
        self.amountReturned = amountReturned
        self.returnedCurrencyRaw = returnedCurrency?.rawValue
        self.returnedExchangeRateOverride = returnedExchangeRateOverride
        self.returnedToAccount = returnedToAccount
        self.account = account
        self.category = category
        self.subscription = subscription
        self.expectedExpense = expectedExpense
        self.createdAt = Date()
    }

    var currency: Currency {
        get { Currency(rawValue: currencyRaw) ?? .usd }
        set { currencyRaw = newValue.rawValue }
    }

    var returnedCurrency: Currency? {
        get { returnedCurrencyRaw.flatMap(Currency.init(rawValue:)) }
        set { returnedCurrencyRaw = newValue?.rawValue }
    }

    var hasReturn: Bool {
        if let r = amountReturned, r > 0 { return true }
        return false
    }
}
