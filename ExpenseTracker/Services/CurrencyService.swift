//
//  CurrencyService.swift
//  ExpenseTracker
//
//  Currency conversion using AppSettings rate (or a per-item override).
//  All math uses Decimal to avoid float rounding errors.
//

import Foundation

enum CurrencyService {

    /// Convert `amount` from `source` to `target` using the supplied USD→LBP rate.
    /// - Parameters:
    ///   - amount: source amount
    ///   - source: source currency
    ///   - target: target currency
    ///   - usdToLbpRate: USD→LBP rate (e.g. 90_000)
    /// - Returns: converted amount as Decimal
    static func convert(
        _ amount: Decimal,
        from source: Currency,
        to target: Currency,
        usdToLbpRate: Decimal
    ) -> Decimal {
        guard source != target else { return amount }
        guard usdToLbpRate > 0 else { return amount }

        switch (source, target) {
        case (.usd, .lbp):
            return amount * usdToLbpRate
        case (.lbp, .usd):
            return amount / usdToLbpRate
        case (.usd, .usd), (.lbp, .lbp):
            return amount
        }
    }

    /// Effective rate for an expense: use override if present, else the app default.
    static func effectiveRate(override: Decimal?, settingsRate: Decimal) -> Decimal {
        if let o = override, o > 0 { return o }
        return settingsRate
    }
}
