//
//  RecurringService.swift
//  ExpenseTracker
//
//  Turns Subscriptions and ExpectedExpenses into real Expense entries when
//  their date arrives. Account balances are derived from Expenses by
//  BalanceService, so creating an Expense is what makes the money move.
//

import Foundation
import SwiftData

@MainActor
enum RecurringService {

    // MARK: - Subscriptions

    /// Walk every active subscription. For each one whose `nextRenewalDate`
    /// is on or before `referenceDate`, log an Expense, advance the renewal
    /// date by one cycle, and repeat until the next renewal is in the future
    /// (catches up multi-cycle backlogs after the app was unused for a while).
    ///
    /// Returns the number of Expenses created. Caller is responsible for
    /// rescheduling notifications on the affected subscriptions.
    @discardableResult
    static func processDueSubscriptions(
        in context: ModelContext,
        referenceDate: Date = Date()
    ) -> [Subscription] {
        let descriptor = FetchDescriptor<Subscription>(
            predicate: #Predicate { $0.isActive }
        )
        guard let subs = try? context.fetch(descriptor) else { return [] }

        var charged: [Subscription] = []
        let cal = Calendar.current
        let cutoff = cal.startOfDay(for: referenceDate).addingTimeInterval(86_400 - 1)

        for sub in subs {
            var didCharge = false
            while sub.nextRenewalDate <= cutoff {
                createExpense(for: sub, on: sub.nextRenewalDate, in: context)
                sub.lastChargedDate = sub.nextRenewalDate
                guard let advanced = advance(sub.nextRenewalDate, by: sub.billingCycle) else { break }
                sub.nextRenewalDate = advanced
                didCharge = true
            }
            if didCharge { charged.append(sub) }
        }

        if !charged.isEmpty {
            try? context.save()
        }
        return charged
    }

    /// Charge a subscription immediately (used by the "Charge now" affordance).
    /// Creates an Expense dated today and advances `nextRenewalDate` one cycle
    /// from the later of (current next renewal, today) so the user doesn't end
    /// up double-charged on the original date.
    @discardableResult
    static func chargeNow(
        _ sub: Subscription,
        in context: ModelContext,
        referenceDate: Date = Date()
    ) -> Expense {
        let expense = createExpense(for: sub, on: referenceDate, in: context)
        sub.lastChargedDate = referenceDate

        let base = max(sub.nextRenewalDate, referenceDate)
        if let advanced = advance(base, by: sub.billingCycle) {
            sub.nextRenewalDate = advanced
        }

        try? context.save()
        return expense
    }

    @discardableResult
    private static func createExpense(
        for sub: Subscription,
        on date: Date,
        in context: ModelContext
    ) -> Expense {
        let note = sub.note.isEmpty
            ? "\(sub.name) — \(sub.billingCycle.displayName.lowercased()) subscription"
            : sub.note
        let expense = Expense(
            date: date,
            amount: sub.amount,
            currency: sub.currency,
            note: note,
            account: sub.account,
            category: sub.category,
            subscription: sub
        )
        context.insert(expense)
        return expense
    }

    // MARK: - Expected expenses

    /// Mark an expected expense paid: create a real Expense linked to it.
    /// If the expected expense is recurring, advance `dueDate` to the next
    /// occurrence and leave `isPaid` false so it reappears as upcoming.
    /// If it's one-off, mark `isPaid = true` and stamp `paidDate`.
    ///
    /// Returns the created Expense.
    @discardableResult
    static func markPaid(
        _ expected: ExpectedExpense,
        in context: ModelContext,
        on date: Date = Date()
    ) -> Expense {
        let expense = Expense(
            date: date,
            amount: expected.amount,
            currency: expected.currency,
            note: expected.note.isEmpty ? expected.name : expected.note,
            account: expected.account,
            category: expected.category,
            expectedExpense: expected
        )
        context.insert(expense)

        if let advanced = advanceExpected(expected.dueDate, by: expected.recurrence) {
            // Recurring — roll forward, stay upcoming.
            expected.dueDate = advanced
            expected.isPaid = false
            expected.paidDate = nil
        } else {
            // One-off — done.
            expected.isPaid = true
            expected.paidDate = date
        }

        try? context.save()
        return expense
    }

    // MARK: - Date advancement

    private static func advance(_ date: Date, by cycle: BillingCycle) -> Date? {
        let (component, value) = cycle.dateComponent
        return Calendar.current.date(byAdding: component, value: value, to: date)
    }

    private static func advanceExpected(_ date: Date, by recurrence: ExpectedRecurrence) -> Date? {
        guard let (component, value) = recurrence.dateComponent else { return nil }
        return Calendar.current.date(byAdding: component, value: value, to: date)
    }
}
