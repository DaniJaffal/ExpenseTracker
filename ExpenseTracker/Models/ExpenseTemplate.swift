//
//  ExpenseTemplate.swift
//  ExpenseTracker
//
//  A reusable "favorite" expense — preset amount, currency, account,
//  category, note, and tags. Tapping a template in the picker opens
//  ExpenseEditor pre-filled, so logging a repeated expense is two taps.
//

import Foundation
import SwiftData

@Model
final class ExpenseTemplate {
    var id: UUID = UUID()
    var name: String = ""
    var iconName: String = "star.fill"
    var colorHex: String = "#5856D6"

    var amount: Decimal = Decimal(0)
    var currencyRaw: String = Currency.usd.rawValue
    var note: String = ""

    var sortOrder: Int = 0
    var usageCount: Int = 0
    var lastUsedAt: Date?
    var createdAt: Date = Date()

    @Relationship var account: Account?
    @Relationship var category: Category?

    /// Many-to-many with Tag. Inverse declared on Tag.templates.
    var tags: [Tag]? = []

    init(
        id: UUID = UUID(),
        name: String,
        iconName: String = "star.fill",
        colorHex: String = "#5856D6",
        amount: Decimal = 0,
        currency: Currency = .usd,
        note: String = "",
        sortOrder: Int = 0,
        account: Account? = nil,
        category: Category? = nil
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.amount = amount
        self.currencyRaw = currency.rawValue
        self.note = note
        self.sortOrder = sortOrder
        self.account = account
        self.category = category
        self.createdAt = Date()
    }

    var currency: Currency {
        get { Currency(rawValue: currencyRaw) ?? .usd }
        set { currencyRaw = newValue.rawValue }
    }
}
