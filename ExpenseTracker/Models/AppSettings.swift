//
//  AppSettings.swift
//  ExpenseTracker
//
//  Single-row settings table. Created by SeedService on first launch.
//

import Foundation
import SwiftData

@Model
final class AppSettings {
    /// USD → LBP conversion rate. Stored as Decimal. Default 90 000.
    var usdToLbpRate: Decimal = Decimal(90_000)

    /// Default currency for new expenses when no account is preselected.
    var defaultCurrencyRaw: String = Currency.usd.rawValue

    /// Optional default account picked when adding an expense.
    var defaultAccountID: UUID?

    /// Whether the user has been asked for notification permission yet.
    var hasRequestedNotificationPermission: Bool = false

    /// When true, the app requires biometric (Face ID / Touch ID) or device
    /// passcode authentication before showing financial data.
    var isLockEnabled: Bool = false

    /// Seconds of background time before re-lock is required when returning
    /// to the foreground. Special values: 0 = immediate, -1 = only at launch.
    var lockTimeoutSeconds: Int = 0

    /// When true, the app fires a local notification the first time each
    /// month that a budget crosses 80% or 100% of its cap.
    var notifyOnBudgetWarning: Bool = false

    var createdAt: Date = Date()

    init(
        usdToLbpRate: Decimal = Decimal(90_000),
        defaultCurrency: Currency = .usd,
        defaultAccountID: UUID? = nil
    ) {
        self.usdToLbpRate = usdToLbpRate
        self.defaultCurrencyRaw = defaultCurrency.rawValue
        self.defaultAccountID = defaultAccountID
        self.hasRequestedNotificationPermission = false
        self.createdAt = Date()
    }

    var defaultCurrency: Currency {
        get { Currency(rawValue: defaultCurrencyRaw) ?? .usd }
        set { defaultCurrencyRaw = newValue.rawValue }
    }
}
