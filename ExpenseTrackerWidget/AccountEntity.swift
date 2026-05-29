//
//  AccountEntity.swift
//  ExpenseTrackerWidget
//
//  AppEntity that lets the user pick accounts in widget configuration
//  and App Intents (e.g. Quick-Log).
//

import Foundation
import AppIntents
import SwiftData

struct AccountEntity: AppEntity, Identifiable {
    var id: UUID
    var name: String
    var currencyCode: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Account"

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name) (\(currencyCode))")
    }

    static var defaultQuery = AccountEntityQuery()
}

struct AccountEntityQuery: EntityQuery {

    func entities(for identifiers: [AccountEntity.ID]) async throws -> [AccountEntity] {
        await fetchAll().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [AccountEntity] {
        await fetchAll()
    }

    func defaultResult() async -> AccountEntity? {
        await fetchAll().first
    }

    @MainActor
    private func fetchAll() -> [AccountEntity] {
        WidgetData.read(defaultValue: [AccountEntity]()) { context in
            let descriptor = FetchDescriptor<Account>(
                predicate: #Predicate { !$0.isArchived },
                sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.name)]
            )
            let accounts = (try? context.fetch(descriptor)) ?? []
            return accounts.map {
                AccountEntity(id: $0.id, name: $0.name, currencyCode: $0.currency.displayCode)
            }
        }
    }
}
