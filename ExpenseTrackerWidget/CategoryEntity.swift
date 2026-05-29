//
//  CategoryEntity.swift
//  ExpenseTrackerWidget
//
//  AppEntity for categories, used as a parameter in Quick-Log configuration.
//

import Foundation
import AppIntents
import SwiftData

struct CategoryEntity: AppEntity, Identifiable {
    var id: UUID
    var name: String
    var iconName: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Category"

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    static var defaultQuery = CategoryEntityQuery()
}

struct CategoryEntityQuery: EntityQuery {

    func entities(for identifiers: [CategoryEntity.ID]) async throws -> [CategoryEntity] {
        await fetchAll().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [CategoryEntity] {
        await fetchAll()
    }

    func defaultResult() async -> CategoryEntity? {
        await fetchAll().first
    }

    @MainActor
    private func fetchAll() -> [CategoryEntity] {
        WidgetData.read(defaultValue: [CategoryEntity]()) { context in
            let descriptor = FetchDescriptor<Category>(
                sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.name)]
            )
            let categories = (try? context.fetch(descriptor)) ?? []
            return categories.map {
                CategoryEntity(id: $0.id, name: $0.name, iconName: $0.iconName)
            }
        }
    }
}

/// Currency value enum exposed to App Intents.
enum CurrencyAppEnum: String, AppEnum {
    case usd = "USD"
    case lbp = "LBP"

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Currency"
    static var caseDisplayRepresentations: [CurrencyAppEnum: DisplayRepresentation] = [
        .usd: "US Dollar",
        .lbp: "Lebanese Pound"
    ]

    var modelCurrency: Currency {
        switch self {
        case .usd: return .usd
        case .lbp: return .lbp
        }
    }
}
