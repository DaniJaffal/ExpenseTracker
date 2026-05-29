//
//  LogExpenseIntent.swift
//  ExpenseTrackerWidget
//
//  Interactive intent triggered by a tap on the Quick-Log widget. Creates an
//  Expense in the shared SwiftData store using the template the user configured
//  on the widget, then triggers a widget timeline reload so balances update.
//

import Foundation
import AppIntents
import SwiftData
import WidgetKit

struct LogExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Expense"
    static var description = IntentDescription("Records a quick expense from the widget template.")

    /// Amount in the template's currency.
    @Parameter(title: "Amount")
    var amount: Double

    @Parameter(title: "Currency")
    var currency: CurrencyAppEnum

    /// ID of the account the expense draws from.
    @Parameter(title: "Account ID")
    var accountID: String

    /// ID of the category, if any.
    @Parameter(title: "Category ID")
    var categoryID: String?

    /// Optional note appended to the expense.
    @Parameter(title: "Note")
    var note: String?

    init() {}

    init(amount: Double, currency: CurrencyAppEnum, accountID: UUID, categoryID: UUID?, note: String?) {
        self.amount = amount
        self.currency = currency
        self.accountID = accountID.uuidString
        self.categoryID = categoryID?.uuidString
        self.note = note
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let container = WidgetData.makeContainer() else {
            return .result()
        }
        let context = ModelContext(container)

        // Resolve the account.
        guard let accountUUID = UUID(uuidString: accountID) else {
            return .result()
        }
        let accountsDescriptor = FetchDescriptor<Account>(
            predicate: #Predicate { $0.id == accountUUID }
        )
        guard let account = (try? context.fetch(accountsDescriptor))?.first else {
            return .result()
        }

        // Resolve the category if provided.
        var category: Category?
        if let categoryIDString = categoryID, let categoryUUID = UUID(uuidString: categoryIDString) {
            let descriptor = FetchDescriptor<Category>(
                predicate: #Predicate { $0.id == categoryUUID }
            )
            category = (try? context.fetch(descriptor))?.first
        }

        let expense = Expense(
            date: Date(),
            amount: Decimal(amount),
            currency: currency.modelCurrency,
            note: note ?? "",
            account: account,
            category: category
        )
        context.insert(expense)
        try? context.save()

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
