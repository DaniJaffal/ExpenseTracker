//
//  Debt.swift
//  ExpenseTracker
//
//  Informational debt ledger — tracks who owes you and who you owe.
//  Does NOT touch account balances. Creating a debt records it; settling
//  it just marks the row resolved. If the user wants the balance to
//  reflect lending money or receiving repayment, they create an expense
//  or transfer manually.
//

import Foundation
import SwiftData

enum DebtDirection: String, CaseIterable, Codable, Identifiable, Sendable {
    case owedToMe = "owed_to_me"
    case iOwe = "i_owe"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .owedToMe: return "Owed to me"
        case .iOwe: return "I owe"
        }
    }

    /// Short label for compact UI (chips, summary).
    var shortLabel: String {
        switch self {
        case .owedToMe: return "Owed to me"
        case .iOwe: return "I owe"
        }
    }
}

@Model
final class Debt {
    var id: UUID = UUID()
    var personName: String = ""
    var amount: Decimal = Decimal(0)
    var currencyRaw: String = Currency.usd.rawValue
    var directionRaw: String = DebtDirection.owedToMe.rawValue
    var note: String = ""
    var dueDate: Date?
    var isSettled: Bool = false
    var settledDate: Date?
    var createdAt: Date = Date()

    init(
        id: UUID = UUID(),
        personName: String,
        amount: Decimal,
        currency: Currency,
        direction: DebtDirection,
        note: String = "",
        dueDate: Date? = nil
    ) {
        self.id = id
        self.personName = personName
        self.amount = amount
        self.currencyRaw = currency.rawValue
        self.directionRaw = direction.rawValue
        self.note = note
        self.dueDate = dueDate
        self.isSettled = false
        self.settledDate = nil
        self.createdAt = Date()
    }

    var currency: Currency {
        get { Currency(rawValue: currencyRaw) ?? .usd }
        set { currencyRaw = newValue.rawValue }
    }

    var direction: DebtDirection {
        get { DebtDirection(rawValue: directionRaw) ?? .owedToMe }
        set { directionRaw = newValue.rawValue }
    }
}
