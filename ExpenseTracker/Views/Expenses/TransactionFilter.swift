//
//  TransactionFilter.swift
//  ExpenseTracker
//
//  Filter state for the Transactions list. Wraps date range, categories,
//  sources, accounts, tags, amount range, and a receipts-only flag.
//

import Foundation

enum DateRangePreset: String, CaseIterable, Identifiable, Sendable {
    case all        = "All time"
    case thisMonth  = "This month"
    case lastMonth  = "Last month"
    case last30Days = "Last 30 days"
    case thisYear   = "This year"
    case lastYear   = "Last year"
    case custom     = "Custom range"

    var id: String { rawValue }
}

struct TransactionFilterState: Equatable {
    var dateRangePreset: DateRangePreset = .all
    var customStart: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    var customEnd: Date = Date()

    var selectedCategoryIDs: Set<UUID> = []
    var selectedSourceIDs: Set<UUID> = []
    var selectedAccountIDs: Set<UUID> = []
    var selectedTagIDs: Set<UUID> = []

    var minAmount: Decimal?
    var maxAmount: Decimal?

    var receiptsOnly: Bool = false

    /// True when any non-default filter is active.
    var hasActiveFilters: Bool {
        dateRangePreset != .all
            || !selectedCategoryIDs.isEmpty
            || !selectedSourceIDs.isEmpty
            || !selectedAccountIDs.isEmpty
            || !selectedTagIDs.isEmpty
            || minAmount != nil
            || maxAmount != nil
            || receiptsOnly
    }

    var activeFilterCount: Int {
        var n = 0
        if dateRangePreset != .all { n += 1 }
        if !selectedCategoryIDs.isEmpty { n += 1 }
        if !selectedSourceIDs.isEmpty { n += 1 }
        if !selectedAccountIDs.isEmpty { n += 1 }
        if !selectedTagIDs.isEmpty { n += 1 }
        if minAmount != nil || maxAmount != nil { n += 1 }
        if receiptsOnly { n += 1 }
        return n
    }

    mutating func reset() { self = TransactionFilterState() }

    // MARK: - Predicates

    func includesDate(_ date: Date) -> Bool {
        let cal = Calendar.current
        switch dateRangePreset {
        case .all:
            return true
        case .thisMonth:
            return cal.isDate(date, equalTo: Date(), toGranularity: .month)
        case .lastMonth:
            guard let lastMonth = cal.date(byAdding: .month, value: -1, to: Date()) else { return false }
            return cal.isDate(date, equalTo: lastMonth, toGranularity: .month)
        case .last30Days:
            guard let thirtyAgo = cal.date(byAdding: .day, value: -30, to: Date()) else { return false }
            return date >= thirtyAgo
        case .thisYear:
            return cal.isDate(date, equalTo: Date(), toGranularity: .year)
        case .lastYear:
            guard let lastYear = cal.date(byAdding: .year, value: -1, to: Date()) else { return false }
            return cal.isDate(date, equalTo: lastYear, toGranularity: .year)
        case .custom:
            return date >= customStart && date <= customEnd
        }
    }

    func includesAmount(_ amount: Decimal) -> Bool {
        if let min = minAmount, amount < min { return false }
        if let max = maxAmount, amount > max { return false }
        return true
    }
}
