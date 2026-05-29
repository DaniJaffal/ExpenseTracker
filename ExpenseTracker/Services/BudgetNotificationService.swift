//
//  BudgetNotificationService.swift
//  ExpenseTracker
//
//  Checks every budget after an expense changes and schedules a one-shot
//  warning notification when it crosses 80% or 100% of its cap. Per-budget
//  date stamps prevent re-notifying within the same calendar month.
//

import Foundation
import SwiftData

@MainActor
enum BudgetNotificationService {

    /// Recompute every budget's month-to-date progress and schedule warning
    /// notifications for any that just crossed a threshold. Safe to call from
    /// expense save / delete sites — no-op when the user has the feature off
    /// or when notifications aren't authorized.
    static func checkAndNotify(in context: ModelContext) {
        let settingsDescriptor = FetchDescriptor<AppSettings>()
        guard let settings = (try? context.fetch(settingsDescriptor))?.first,
              settings.notifyOnBudgetWarning else {
            return
        }

        let budgetsDescriptor = FetchDescriptor<Budget>()
        guard let budgets = try? context.fetch(budgetsDescriptor), !budgets.isEmpty else {
            return
        }

        let displayCurrency = settings.defaultCurrency
        let rate = settings.usdToLbpRate
        let progressList = BudgetService.progressList(
            budgets: budgets,
            in: displayCurrency,
            usdToLbpRate: rate
        )

        for progress in progressList {
            evaluate(progress: progress)
        }

        try? context.save()
    }

    private static func evaluate(progress: BudgetProgress) {
        let budget = progress.budget

        // OVER budget (100%+) — highest priority. Notify first.
        if progress.percentRaw >= 100 {
            if !alreadyNotifiedThisMonth(budget.lastNotifiedAt100) {
                Task {
                    await NotificationService.shared.scheduleBudgetWarning(
                        categoryName: progress.categoryName,
                        percent: Int(progress.percentRaw.rounded()),
                        isOver: true
                    )
                }
                budget.lastNotifiedAt100 = Date()
                // Also stamp the 80% one so we don't double-fire when the user
                // briefly drops back below 100% and crosses 80% again.
                if budget.lastNotifiedAt80 == nil {
                    budget.lastNotifiedAt80 = Date()
                }
            }
            return
        }

        // 80%–99% warning band.
        if progress.percentRaw >= 80 {
            if !alreadyNotifiedThisMonth(budget.lastNotifiedAt80) {
                Task {
                    await NotificationService.shared.scheduleBudgetWarning(
                        categoryName: progress.categoryName,
                        percent: Int(progress.percentRaw.rounded()),
                        isOver: false
                    )
                }
                budget.lastNotifiedAt80 = Date()
            }
        }
    }

    private static func alreadyNotifiedThisMonth(_ date: Date?) -> Bool {
        guard let date else { return false }
        return Calendar.current.isDate(date, equalTo: Date(), toGranularity: .month)
    }
}
