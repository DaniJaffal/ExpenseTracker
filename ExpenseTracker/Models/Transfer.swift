//
//  Transfer.swift
//  ExpenseTracker
//
//  Moves money between two accounts. Supports cross-currency transfers.
//

import Foundation
import SwiftData

@Model
final class Transfer {
    var id: UUID = UUID()
    var date: Date = Date()

    /// Amount leaving the source account (in source account's currency).
    var amount: Decimal = Decimal(0)

    /// Amount arriving in destination account, if different from `amount` after conversion.
    /// nil → derive from rate. Setting this lets the user record the exact arrival amount.
    var receivedAmount: Decimal?

    /// Override USD↔LBP rate used for this transfer. nil → use AppSettings rate.
    var exchangeRateOverride: Decimal?

    var note: String = ""
    var createdAt: Date = Date()

    @Relationship var fromAccount: Account?
    @Relationship var toAccount: Account?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        amount: Decimal,
        receivedAmount: Decimal? = nil,
        exchangeRateOverride: Decimal? = nil,
        note: String = "",
        fromAccount: Account? = nil,
        toAccount: Account? = nil
    ) {
        self.id = id
        self.date = date
        self.amount = amount
        self.receivedAmount = receivedAmount
        self.exchangeRateOverride = exchangeRateOverride
        self.note = note
        self.fromAccount = fromAccount
        self.toAccount = toAccount
        self.createdAt = Date()
    }
}
