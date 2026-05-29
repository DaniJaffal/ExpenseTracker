//
//  WidgetData.swift
//  ExpenseTrackerWidget
//
//  Shared helpers for widgets that need to read from the SwiftData store.
//  All widgets use the same App Group container as the main app.
//

import Foundation
import SwiftData

enum WidgetData {

    /// Build a one-shot ModelContainer for reading inside a TimelineProvider.
    /// Returns nil if the store isn't available (e.g. App Group not set up).
    static func makeContainer() -> ModelContainer? {
        let schema = Schema(ModelContainerFactory.allModelTypes)

        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: ModelContainerFactory.appGroupID
        ) else {
            return nil
        }
        let storeURL = groupURL.appendingPathComponent("ExpenseTracker.store")
        let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            return nil
        }
    }

    /// Run a closure with a fresh ModelContext.
    /// Returns `defaultValue` if the store can't be opened.
    @MainActor
    static func read<T>(
        defaultValue: T,
        _ body: (ModelContext) throws -> T
    ) -> T {
        guard let container = makeContainer() else { return defaultValue }
        let context = ModelContext(container)
        do {
            return try body(context)
        } catch {
            return defaultValue
        }
    }
}
