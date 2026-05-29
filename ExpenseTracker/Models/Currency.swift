//
//  Currency.swift
//  ExpenseTracker
//
//  Supported currencies. Stored as raw String so SwiftData/CloudKit can persist.
//

import Foundation

enum Currency: String, CaseIterable, Codable, Identifiable, Sendable {
    case usd = "USD"
    case lbp = "LBP"

    var id: String { rawValue }

    var displayCode: String { rawValue }

    var symbol: String {
        switch self {
        case .usd: return "$"
        case .lbp: return "ل.ل"
        }
    }

    var fullName: String {
        switch self {
        case .usd: return "US Dollar"
        case .lbp: return "Lebanese Pound"
        }
    }

    /// How many fraction digits to show in the UI by default.
    var defaultFractionDigits: Int {
        switch self {
        case .usd: return 2
        case .lbp: return 0
        }
    }
}
