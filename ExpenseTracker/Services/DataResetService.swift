//
//  DataResetService.swift
//  ExpenseTracker
//
//  Wipes every persisted entity and re-seeds defaults. Used by the
//  "Reset All Data" button in Settings (Danger Zone).
//
//  This is irreversible — the caller is responsible for any user confirmation.
//

import Foundation
import SwiftData

@MainActor
enum DataResetService {

    /// Deletes every row of every `@Model` type, cancels all scheduled
    /// notifications, then re-runs first-launch seeding so the app boots
    /// to a clean state with default categories and a fresh `AppSettings`.
    static func wipeAndReseed(in context: ModelContext) {
        // Delete dependents first to avoid relationship cascade surprises.
        try? context.delete(model: PaymentLeg.self)
        try? context.delete(model: ReturnLeg.self)
        try? context.delete(model: Expense.self)
        try? context.delete(model: Income.self)
        try? context.delete(model: Transfer.self)
        try? context.delete(model: Subscription.self)
        try? context.delete(model: ExpectedExpense.self)
        try? context.delete(model: Budget.self)
        try? context.delete(model: Debt.self)
        try? context.delete(model: SavingsGoal.self)
        try? context.delete(model: Tag.self)
        try? context.delete(model: ExpenseTemplate.self)
        try? context.delete(model: Category.self)
        try? context.delete(model: IncomeSource.self)
        try? context.delete(model: Account.self)
        try? context.delete(model: AppSettings.self)

        // Drop any scheduled local notifications.
        NotificationService.shared.cancelAll()

        // Remove every stored receipt image from disk.
        ReceiptStore.deleteAll()

        do {
            try context.save()
        } catch {
            print("DataResetService: save after wipe failed: \(error)")
        }

        // Re-seed defaults (creates AppSettings + default categories).
        SeedService.bootstrap(in: context)

        // Refresh widgets so they reflect the empty state.
        WidgetRefresh.bump()
    }
}
