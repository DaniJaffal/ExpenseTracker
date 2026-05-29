//
//  Formatters.swift
//  ExpenseTracker
//
//  Currency, date, and number formatters. Always use these — never hand-format.
//

import Foundation

enum Formatters {

    /// Format a Decimal amount in the given currency. Uses sensible fraction digits per currency.
    static func currency(_ amount: Decimal, in currency: Currency, sign: Bool = false) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = currency.defaultFractionDigits
        formatter.maximumFractionDigits = currency.defaultFractionDigits
        formatter.groupingSeparator = ","
        formatter.usesGroupingSeparator = true

        let abs = amount < 0 ? -amount : amount
        let number = NSDecimalNumber(decimal: abs)
        let body = formatter.string(from: number) ?? "0"

        let symbol = currency.symbol
        let signPrefix: String = {
            if !sign { return amount < 0 ? "-" : "" }
            if amount > 0 { return "+" }
            if amount < 0 { return "-" }
            return ""
        }()

        switch currency {
        case .usd:
            return "\(signPrefix)\(symbol)\(body)"
        case .lbp:
            return "\(signPrefix)\(body) \(symbol)"
        }
    }

    /// Short date — e.g. "May 23, 2026"
    static func date(_ date: Date, style: DateFormatter.Style = .medium) -> String {
        let f = DateFormatter()
        f.dateStyle = style
        f.timeStyle = .none
        return f.string(from: date)
    }

    /// "Today", "Yesterday", or a short date.
    static func relativeDate(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        if cal.isDateInTomorrow(date) { return "Tomorrow" }
        let days = cal.dateComponents([.day], from: Date(), to: date).day ?? 0
        if days > 0 && days <= 7 { return "In \(days) day\(days == 1 ? "" : "s")" }
        if days < 0 && days >= -7 { return "\(-days) day\(days == -1 ? "" : "s") ago" }
        return self.date(date)
    }

    /// Month + year label, e.g. "May 2026"
    static func monthYear(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: date)
    }

    /// Plain decimal formatter for entering exchange rates.
    static func rate(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 4
        formatter.usesGroupingSeparator = true
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "0"
    }
}
