//
//  BalanceService.swift
//  ExpenseTracker
//
//  Computes the running balance of an Account given its initial balance,
//  all related expenses (and any money returned), and transfers in/out.
//
//  All math in the account's own currency. Cross-currency expenses/transfers
//  are converted using the per-item rate override or the app default rate.
//

import Foundation

enum BalanceService {

    /// Current balance of the given account.
    static func currentBalance(
        for account: Account,
        usdToLbpRate: Decimal
    ) -> Decimal {
        var balance = account.initialBalance
        let accountCurrency = account.currency

        // Expenses where this account is the source: subtract the spent amount.
        // The returned amount only credits back here when no explicit
        // `returnedToAccount` was chosen (or when it points to this same account).
        for expense in account.expenses ?? [] {
            let rate = CurrencyService.effectiveRate(
                override: expense.exchangeRateOverride,
                settingsRate: usdToLbpRate
            )
            let spent = CurrencyService.convert(
                expense.amount,
                from: expense.currency,
                to: accountCurrency,
                usdToLbpRate: rate
            )
            balance -= spent

            // If the return goes back to *this* same account, credit here.
            // Otherwise the credit is applied to `returnedToAccount` in the loop below.
            if let returned = expense.amountReturned, returned > 0,
               expense.returnedToAccount == nil || expense.returnedToAccount?.id == account.id {
                let returnedCurrency = expense.returnedCurrency ?? expense.currency
                let returnRate = CurrencyService.effectiveRate(
                    override: expense.returnedExchangeRateOverride ?? expense.exchangeRateOverride,
                    settingsRate: usdToLbpRate
                )
                let returnedInAccount = CurrencyService.convert(
                    returned,
                    from: returnedCurrency,
                    to: accountCurrency,
                    usdToLbpRate: returnRate
                )
                balance += returnedInAccount
            }
        }

        // Additional payment legs (split-currency expenses) that draw from this account.
        for leg in account.paymentLegs ?? [] {
            let parentExpense = leg.expense
            let rate = CurrencyService.effectiveRate(
                override: parentExpense?.exchangeRateOverride,
                settingsRate: usdToLbpRate
            )
            let spent = CurrencyService.convert(
                leg.amount,
                from: leg.currency,
                to: accountCurrency,
                usdToLbpRate: rate
            )
            balance -= spent
        }

        // Expenses where this account RECEIVES the returned money (but isn't the source).
        for expense in account.expenseReturnsReceived ?? [] {
            // Guard against double-counting if source == return-to (handled above).
            if expense.account?.id == account.id { continue }
            guard let returned = expense.amountReturned, returned > 0 else { continue }
            let returnedCurrency = expense.returnedCurrency ?? expense.currency
            let returnRate = CurrencyService.effectiveRate(
                override: expense.returnedExchangeRateOverride ?? expense.exchangeRateOverride,
                settingsRate: usdToLbpRate
            )
            let returnedInAccount = CurrencyService.convert(
                returned,
                from: returnedCurrency,
                to: accountCurrency,
                usdToLbpRate: returnRate
            )
            balance += returnedInAccount
        }

        // Incomes credited to this account.
        for income in account.incomes ?? [] {
            let rate = CurrencyService.effectiveRate(
                override: income.exchangeRateOverride,
                settingsRate: usdToLbpRate
            )
            let credit = CurrencyService.convert(
                income.amount,
                from: income.currency,
                to: accountCurrency,
                usdToLbpRate: rate
            )
            balance += credit
        }

        // Additional return legs that credit this account.
        for leg in account.returnLegsReceived ?? [] {
            guard leg.amount > 0 else { continue }
            let parentExpense = leg.expense
            let returnRate = CurrencyService.effectiveRate(
                override: parentExpense?.returnedExchangeRateOverride ?? parentExpense?.exchangeRateOverride,
                settingsRate: usdToLbpRate
            )
            let creditedInAccount = CurrencyService.convert(
                leg.amount,
                from: leg.currency,
                to: accountCurrency,
                usdToLbpRate: returnRate
            )
            balance += creditedInAccount
        }

        // Transfers out subtract from source.
        for transfer in account.transfersOut ?? [] {
            balance -= transfer.amount
        }

        // Transfers in add to destination — use receivedAmount if set, else convert.
        for transfer in account.transfersIn ?? [] {
            if let received = transfer.receivedAmount {
                balance += received
            } else if let fromAcc = transfer.fromAccount {
                let rate = CurrencyService.effectiveRate(
                    override: transfer.exchangeRateOverride,
                    settingsRate: usdToLbpRate
                )
                let received = CurrencyService.convert(
                    transfer.amount,
                    from: fromAcc.currency,
                    to: accountCurrency,
                    usdToLbpRate: rate
                )
                balance += received
            } else {
                balance += transfer.amount
            }
        }

        return balance
    }

    /// Balance of `account` as of the end of `date` (inclusive). Mirrors
    /// `currentBalance` but only counts activities dated on or before the
    /// cutoff. Used by the trend chart.
    static func balance(
        for account: Account,
        on cutoff: Date,
        usdToLbpRate: Decimal
    ) -> Decimal {
        var balance = account.initialBalance
        let accountCurrency = account.currency

        // Expenses sourced from this account.
        for expense in account.expenses ?? [] where expense.date <= cutoff {
            let rate = CurrencyService.effectiveRate(
                override: expense.exchangeRateOverride,
                settingsRate: usdToLbpRate
            )
            let spent = CurrencyService.convert(
                expense.amount,
                from: expense.currency,
                to: accountCurrency,
                usdToLbpRate: rate
            )
            balance -= spent

            if let returned = expense.amountReturned, returned > 0,
               expense.returnedToAccount == nil || expense.returnedToAccount?.id == account.id {
                let returnedCurrency = expense.returnedCurrency ?? expense.currency
                let returnRate = CurrencyService.effectiveRate(
                    override: expense.returnedExchangeRateOverride ?? expense.exchangeRateOverride,
                    settingsRate: usdToLbpRate
                )
                let returnedInAccount = CurrencyService.convert(
                    returned,
                    from: returnedCurrency,
                    to: accountCurrency,
                    usdToLbpRate: returnRate
                )
                balance += returnedInAccount
            }
        }

        // Payment legs drawing from this account (dated by parent expense).
        for leg in account.paymentLegs ?? [] {
            guard let parent = leg.expense, parent.date <= cutoff else { continue }
            let rate = CurrencyService.effectiveRate(
                override: parent.exchangeRateOverride,
                settingsRate: usdToLbpRate
            )
            let spent = CurrencyService.convert(
                leg.amount,
                from: leg.currency,
                to: accountCurrency,
                usdToLbpRate: rate
            )
            balance -= spent
        }

        // Incomes credited to this account.
        for income in account.incomes ?? [] where income.date <= cutoff {
            let rate = CurrencyService.effectiveRate(
                override: income.exchangeRateOverride,
                settingsRate: usdToLbpRate
            )
            let credit = CurrencyService.convert(
                income.amount,
                from: income.currency,
                to: accountCurrency,
                usdToLbpRate: rate
            )
            balance += credit
        }

        // Expense returns this account *received* (but is not the source).
        for expense in account.expenseReturnsReceived ?? [] where expense.date <= cutoff {
            if expense.account?.id == account.id { continue }
            guard let returned = expense.amountReturned, returned > 0 else { continue }
            let returnedCurrency = expense.returnedCurrency ?? expense.currency
            let returnRate = CurrencyService.effectiveRate(
                override: expense.returnedExchangeRateOverride ?? expense.exchangeRateOverride,
                settingsRate: usdToLbpRate
            )
            let returnedInAccount = CurrencyService.convert(
                returned,
                from: returnedCurrency,
                to: accountCurrency,
                usdToLbpRate: returnRate
            )
            balance += returnedInAccount
        }

        // Return legs received (dated by parent expense).
        for leg in account.returnLegsReceived ?? [] {
            guard let parent = leg.expense, parent.date <= cutoff else { continue }
            guard leg.amount > 0 else { continue }
            let returnRate = CurrencyService.effectiveRate(
                override: parent.returnedExchangeRateOverride ?? parent.exchangeRateOverride,
                settingsRate: usdToLbpRate
            )
            let credited = CurrencyService.convert(
                leg.amount,
                from: leg.currency,
                to: accountCurrency,
                usdToLbpRate: returnRate
            )
            balance += credited
        }

        // Transfers out.
        for transfer in account.transfersOut ?? [] where transfer.date <= cutoff {
            balance -= transfer.amount
        }

        // Transfers in.
        for transfer in account.transfersIn ?? [] where transfer.date <= cutoff {
            if let received = transfer.receivedAmount {
                balance += received
            } else if let from = transfer.fromAccount {
                let rate = CurrencyService.effectiveRate(
                    override: transfer.exchangeRateOverride,
                    settingsRate: usdToLbpRate
                )
                let received = CurrencyService.convert(
                    transfer.amount,
                    from: from.currency,
                    to: accountCurrency,
                    usdToLbpRate: rate
                )
                balance += received
            } else {
                balance += transfer.amount
            }
        }

        return balance
    }

    /// Sum of balances across many accounts, converted to a target currency.
    static func totalBalance(
        accounts: [Account],
        in target: Currency,
        usdToLbpRate: Decimal
    ) -> Decimal {
        var total: Decimal = 0
        for account in accounts where !account.isArchived {
            let bal = currentBalance(for: account, usdToLbpRate: usdToLbpRate)
            total += CurrencyService.convert(
                bal,
                from: account.currency,
                to: target,
                usdToLbpRate: usdToLbpRate
            )
        }
        return total
    }

    /// Net amount of an expense in a specified currency.
    /// Sum of the primary payment + all additional legs, minus any returned amount.
    static func netCost(
        of expense: Expense,
        in target: Currency,
        usdToLbpRate: Decimal
    ) -> Decimal {
        let rate = CurrencyService.effectiveRate(
            override: expense.exchangeRateOverride,
            settingsRate: usdToLbpRate
        )

        // Primary payment.
        var net = CurrencyService.convert(
            expense.amount,
            from: expense.currency,
            to: target,
            usdToLbpRate: rate
        )

        // Additional payment legs.
        for leg in expense.additionalPayments ?? [] {
            net += CurrencyService.convert(
                leg.amount,
                from: leg.currency,
                to: target,
                usdToLbpRate: rate
            )
        }

        // Money returned reduces the total — primary return.
        let returnRate = CurrencyService.effectiveRate(
            override: expense.returnedExchangeRateOverride ?? expense.exchangeRateOverride,
            settingsRate: usdToLbpRate
        )
        if let returned = expense.amountReturned, returned > 0 {
            let returnedCurrency = expense.returnedCurrency ?? expense.currency
            let r = CurrencyService.convert(
                returned,
                from: returnedCurrency,
                to: target,
                usdToLbpRate: returnRate
            )
            net -= r
        }

        // Additional return legs also reduce the total.
        for leg in expense.additionalReturns ?? [] {
            guard leg.amount > 0 else { continue }
            let r = CurrencyService.convert(
                leg.amount,
                from: leg.currency,
                to: target,
                usdToLbpRate: returnRate
            )
            net -= r
        }

        return net
    }
}
