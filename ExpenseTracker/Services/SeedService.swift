//
//  SeedService.swift
//  ExpenseTracker
//
//  Bootstraps the data store on first launch: AppSettings row + default categories.
//

import Foundation
import SwiftData

@MainActor
enum SeedService {

    /// Run on app launch. Idempotent — won't duplicate seed data.
    static func bootstrap(in context: ModelContext) {
        ensureAppSettings(in: context)
        ensureSeedCategories(in: context)
        ensureSeedIncomeSources(in: context)

        do {
            try context.save()
        } catch {
            print("SeedService: save failed: \(error)")
        }
    }

    @discardableResult
    static func ensureAppSettings(in context: ModelContext) -> AppSettings {
        let descriptor = FetchDescriptor<AppSettings>()
        if let existing = (try? context.fetch(descriptor))?.first {
            return existing
        }
        let new = AppSettings()
        context.insert(new)
        return new
    }

    static func ensureSeedCategories(in context: ModelContext) {
        let descriptor = FetchDescriptor<Category>()
        let existing = (try? context.fetch(descriptor)) ?? []
        if !existing.isEmpty { return }   // assume user already has their list

        for (index, seed) in SeedCategories.all.enumerated() {
            let category = Category(
                name: seed.name,
                iconName: seed.icon,
                colorHex: seed.color,
                isCustom: false,
                sortOrder: index
            )
            context.insert(category)
        }
    }

    static func ensureSeedIncomeSources(in context: ModelContext) {
        let descriptor = FetchDescriptor<IncomeSource>()
        let existing = (try? context.fetch(descriptor)) ?? []
        if !existing.isEmpty { return }

        for (index, seed) in SeedIncomeSources.all.enumerated() {
            let source = IncomeSource(
                name: seed.name,
                iconName: seed.icon,
                colorHex: seed.color,
                isCustom: false,
                sortOrder: index
            )
            context.insert(source)
        }
    }

    /// Fetches the singleton AppSettings — creates one if missing.
    static func settings(in context: ModelContext) -> AppSettings {
        ensureAppSettings(in: context)
    }
}
