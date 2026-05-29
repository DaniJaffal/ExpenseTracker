//
//  BudgetService.swift
//  ExpenseTracker
//
//  Budget computations — month-to-date spend per category, progress, status.
//

import Foundation
import SwiftUI

enum BudgetStatus {
    case onTrack          // < 80% of budget
    case warning          // 80%–99%
    case over             // ≥ 100%
}

struct BudgetProgress {
    let budget: Budget
    let categoryName: String
    let categoryIcon: String
    let categoryColor: String
    let spent: Decimal              // in display currency
    let cap: Decimal                // in display currency
    let currency: Currency
    let fraction: Double            // spent / cap, clamped to [0, 1] for the bar
    let percentRaw: Double          // unclamped, can exceed 100
    let status: BudgetStatus

    var tintColor: Color {
        switch status {
        case .onTrack: return Color(hex: "#34C759")
        case .warning: return Color(hex: "#FF9500")
        case .over:    return Color(hex: "#FF3B30")
        }
    }
}

enum BudgetService {

    /// Month-to-date spend (net of returns) charged against a category, in the
    /// supplied display currency. Iterates the category's expenses directly.
    static func monthSpend(
        for category: Category,
        in displayCurrency: Currency,
        usdToLbpRate: Decimal,
        referenceDate: Date = Date()
    ) -> Decimal {
        let cal = Calendar.current
        guard let monthStart = cal.dateInterval(of: .month, for: referenceDate)?.start else {
            return 0
        }
        let expenses = (category.expenses ?? []).filter { $0.date >= monthStart }
        return expenses.reduce(Decimal(0)) { running, exp in
            running + BalanceService.netCost(of: exp, in: displayCurrency, usdToLbpRate: usdToLbpRate)
        }
    }

    /// Builds a BudgetProgress for one budget against the current month.
    static func progress(
        for budget: Budget,
        in displayCurrency: Currency,
        usdToLbpRate: Decimal,
        referenceDate: Date = Date()
    ) -> BudgetProgress {
        let category = budget.category
        let categoryName = category?.name ?? "—"
        let categoryIcon = category?.iconName ?? "tag.fill"
        let categoryColor = category?.colorHex ?? "#8E8E93"

        let spent: Decimal
        if let category {
            spent = monthSpend(
                for: category,
                in: displayCurrency,
                usdToLbpRate: usdToLbpRate,
                referenceDate: referenceDate
            )
        } else {
            spent = 0
        }

        let cap = budget.monthlyAmount
        let percent: Double = {
            guard cap > 0 else { return 0 }
            let s = NSDecimalNumber(decimal: spent).doubleValue
            let c = NSDecimalNumber(decimal: cap).doubleValue
            return (s / c) * 100
        }()
        let fraction = max(0, min(1, percent / 100))

        let status: BudgetStatus
        switch percent {
        case ..<80:     status = .onTrack
        case 80..<100:  status = .warning
        default:        status = .over
        }

        return BudgetProgress(
            budget: budget,
            categoryName: categoryName,
            categoryIcon: categoryIcon,
            categoryColor: categoryColor,
            spent: spent,
            cap: cap,
            currency: displayCurrency,
            fraction: fraction,
            percentRaw: percent,
            status: status
        )
    }

    /// All budgets sorted by highest spend % first.
    static func progressList(
        budgets: [Budget],
        in displayCurrency: Currency,
        usdToLbpRate: Decimal,
        referenceDate: Date = Date()
    ) -> [BudgetProgress] {
        budgets
            .map { progress(for: $0, in: displayCurrency, usdToLbpRate: usdToLbpRate, referenceDate: referenceDate) }
            .sorted { $0.percentRaw > $1.percentRaw }
    }
}
