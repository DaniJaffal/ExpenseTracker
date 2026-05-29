//
//  InsightService.swift
//  ExpenseTracker
//
//  Generates presentation-ready insight cards for the dashboard. Each Insight
//  is just a struct of strings + an icon + a hex color, so the view layer
//  doesn't need to do any business logic at render time.
//

import Foundation

struct Insight: Identifiable {
    let id = UUID()
    let icon: String
    let iconColorHex: String
    let title: String
    let subtitle: String
    let trailingText: String?
}

enum InsightService {

    /// Build a priority-sorted list of insights for the current month, capped
    /// at `maxCount`. Higher priority = more urgent / more useful.
    static func generate(
        expenses: [Expense],
        incomes: [Income],
        budgets: [Budget],
        subscriptions: [Subscription],
        displayCurrency: Currency,
        usdToLbpRate: Decimal,
        maxCount: Int = 4
    ) -> [Insight] {

        var scored: [(priority: Int, insight: Insight)] = []
        let cal = Calendar.current
        let now = Date()

        guard let monthStart = cal.dateInterval(of: .month, for: now)?.start,
              let lastMonthStart = cal.date(byAdding: .month, value: -1, to: monthStart) else {
            return []
        }

        let thisMonthExpenses = expenses.filter { $0.date >= monthStart }
        let lastMonthExpenses = expenses.filter { $0.date >= lastMonthStart && $0.date < monthStart }
        let thisMonthIncomes  = incomes.filter { $0.date >= monthStart }

        let thisSpend = thisMonthExpenses.reduce(Decimal(0)) { acc, exp in
            acc + BalanceService.netCost(of: exp, in: displayCurrency, usdToLbpRate: usdToLbpRate)
        }
        let lastSpend = lastMonthExpenses.reduce(Decimal(0)) { acc, exp in
            acc + BalanceService.netCost(of: exp, in: displayCurrency, usdToLbpRate: usdToLbpRate)
        }
        let thisIncome = thisMonthIncomes.reduce(Decimal(0)) { acc, inc in
            acc + CurrencyService.convert(inc.amount,
                                          from: inc.currency,
                                          to: displayCurrency,
                                          usdToLbpRate: usdToLbpRate)
        }

        // 1. Budget warnings — most urgent first.
        let progress = BudgetService.progressList(
            budgets: budgets,
            in: displayCurrency,
            usdToLbpRate: usdToLbpRate
        )
        for p in progress where p.percentRaw >= 80 {
            let percent = Int(p.percentRaw.rounded())
            let isOver = p.status == .over
            let title = isOver
                ? "\(p.categoryName) is over budget"
                : "\(p.categoryName) at \(percent)%"
            let subtitle = "\(Formatters.currency(p.spent, in: displayCurrency)) of \(Formatters.currency(p.cap, in: displayCurrency))"
            let priority = isOver ? 100 : 80
            scored.append((priority, Insight(
                icon: "exclamationmark.triangle.fill",
                iconColorHex: isOver ? "#FF3B30" : "#FF9500",
                title: title,
                subtitle: subtitle,
                trailingText: "\(percent)%"
            )))
        }

        // 2. Net flow this month.
        if thisSpend > 0 || thisIncome > 0 {
            let net = thisIncome - thisSpend
            let isPositive = net >= 0
            let title = isPositive
                ? "Net +\(Formatters.currency(net, in: displayCurrency)) this month"
                : "Net \(Formatters.currency(net, in: displayCurrency)) this month"
            let subtitle = "\(Formatters.currency(thisIncome, in: displayCurrency)) earned · \(Formatters.currency(thisSpend, in: displayCurrency)) spent"
            scored.append((isPositive ? 30 : 60, Insight(
                icon: isPositive ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill",
                iconColorHex: isPositive ? "#34C759" : "#FF3B30",
                title: title,
                subtitle: subtitle,
                trailingText: nil
            )))
        }

        // 3. Top spending category this month.
        if !thisMonthExpenses.isEmpty {
            var sums: [UUID: (total: Decimal, name: String, icon: String, color: String)] = [:]
            for exp in thisMonthExpenses {
                guard let cat = exp.category else { continue }
                let val = BalanceService.netCost(of: exp,
                                                 in: displayCurrency,
                                                 usdToLbpRate: usdToLbpRate)
                let existing = sums[cat.id] ?? (0, cat.name, cat.iconName, cat.colorHex)
                sums[cat.id] = (existing.total + val, existing.name, existing.icon, existing.color)
            }
            if let top = sums.values.max(by: { $0.total < $1.total }), top.total > 0 {
                scored.append((40, Insight(
                    icon: top.icon,
                    iconColorHex: top.color,
                    title: "\(top.name) is your top category",
                    subtitle: "\(Formatters.currency(top.total, in: displayCurrency)) this month",
                    trailingText: nil
                )))
            }
        }

        // 4. Month-over-month spending change (only when meaningful).
        if lastSpend > 0 {
            let pctDecimal = (thisSpend - lastSpend) / lastSpend * 100
            let pct = NSDecimalNumber(decimal: pctDecimal).doubleValue
            let absPct = abs(Int(pct.rounded()))
            if absPct >= 5 {
                let isUp = pct > 0
                let title = isUp
                    ? "Spending up \(absPct)% vs last month"
                    : "Spending down \(absPct)% vs last month"
                let subtitle = "\(Formatters.currency(thisSpend, in: displayCurrency)) vs \(Formatters.currency(lastSpend, in: displayCurrency))"
                scored.append((25, Insight(
                    icon: isUp ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis",
                    iconColorHex: isUp ? "#FF3B30" : "#34C759",
                    title: title,
                    subtitle: subtitle,
                    trailingText: nil
                )))
            }
        }

        // 5. Subscriptions renewing in the next 14 days.
        if let cutoff = cal.date(byAdding: .day, value: 14, to: now) {
            let renewing = subscriptions.filter {
                $0.isActive
                && $0.nextRenewalDate >= now
                && $0.nextRenewalDate <= cutoff
            }
            if !renewing.isEmpty {
                let total = renewing.reduce(Decimal(0)) { acc, sub in
                    acc + CurrencyService.convert(sub.amount,
                                                  from: sub.currency,
                                                  to: displayCurrency,
                                                  usdToLbpRate: usdToLbpRate)
                }
                let title = "\(renewing.count) subscription\(renewing.count == 1 ? "" : "s") renewing soon"
                let subtitle = "\(Formatters.currency(total, in: displayCurrency)) in the next 14 days"
                scored.append((20, Insight(
                    icon: "repeat.circle.fill",
                    iconColorHex: "#5856D6",
                    title: title,
                    subtitle: subtitle,
                    trailingText: nil
                )))
            }
        }

        // Sort by priority desc, cap.
        return scored
            .sorted { $0.priority > $1.priority }
            .prefix(maxCount)
            .map(\.insight)
    }
}
