//
//  ModelContainerFactory.swift
//  ExpenseTracker
//
//  Produces the SwiftData ModelContainer used by both the main app and (later)
//  the Widget Extension. The store lives in a shared App Group container when
//  the App Group capability is configured; otherwise it falls back to the
//  default per-app sandbox location so the app keeps working as before.
//
//  On first launch with App Groups enabled, this also migrates the existing
//  default-location store into the shared container so no data is lost.
//

import Foundation
import SwiftData

enum ModelContainerFactory {

    /// App Group used to share the SwiftData store between the app and widgets.
    /// Must match the App Group identifier configured in Signing & Capabilities
    /// for BOTH the main app target and the Widget Extension target.
    static let appGroupID = "group.com.danijaffal.ExpenseTracker"

    /// All persisted models, in stable order. Update this when adding new @Model classes.
    static let allModelTypes: [any PersistentModel.Type] = [
        AppSettings.self,
        Account.self,
        Category.self,
        Expense.self,
        PaymentLeg.self,
        ReturnLeg.self,
        Transfer.self,
        Subscription.self,
        ExpectedExpense.self,
        Budget.self,
        Debt.self,
        SavingsGoal.self,
        Income.self,
        IncomeSource.self,
        Tag.self,
        ExpenseTemplate.self,
    ]

    /// Returns a ready-to-use ModelContainer. Tries the App Group container
    /// first (after migrating data from the default location if needed). Falls
    /// back to the default location if the App Group isn't configured yet —
    /// this keeps the app launchable before the user has added the App Group
    /// capability in Xcode.
    static func make() -> ModelContainer {
        let schema = Schema(allModelTypes)

        // 1. Try the App Group shared container.
        if let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) {
            let storeURL = groupURL.appendingPathComponent("ExpenseTracker.store")
            migrateLegacyStoreIfNeeded(to: storeURL)

            let config = ModelConfiguration(
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .none
            )
            do {
                let container = try ModelContainer(for: schema, configurations: [config])
                print("ModelContainerFactory: using App Group store at \(storeURL.path)")
                return container
            } catch {
                print("ModelContainerFactory: App Group container init failed (\(error)); falling back to default.")
                // Fall through to default location.
            }
        } else {
            print("ModelContainerFactory: App Group '\(appGroupID)' not available; using default container.")
        }

        // 2. Fall back to the default per-app store location.
        let defaultConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(for: schema, configurations: [defaultConfig])
        } catch {
            fatalError("Failed to initialize ModelContainer (default location): \(error)")
        }
    }

    // MARK: - Migration

    /// On first launch with App Groups enabled, copy the existing SwiftData
    /// store from the default per-app location into the shared container so
    /// the user's data (accounts, expenses, etc.) follows them.
    ///
    /// Idempotent: if the shared store already exists, this is a no-op.
    private static func migrateLegacyStoreIfNeeded(to newStoreURL: URL) {
        let fm = FileManager.default

        // If the shared store already has data, never overwrite it.
        if fm.fileExists(atPath: newStoreURL.path) {
            return
        }

        // SwiftData's default store lives in Application Support / default.store
        // (with -shm and -wal sidecar files for SQLite WAL mode).
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }
        let legacyStoreURL = appSupport.appendingPathComponent("default.store")
        guard fm.fileExists(atPath: legacyStoreURL.path) else {
            return  // Nothing to migrate.
        }

        do {
            // Ensure the destination parent directory exists.
            try fm.createDirectory(
                at: newStoreURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            // Copy the primary SQLite file.
            try fm.copyItem(at: legacyStoreURL, to: newStoreURL)

            // Copy the WAL sidecar files if present (they preserve in-flight transactions).
            for suffix in ["-shm", "-wal"] {
                let legacyAux = appSupport.appendingPathComponent("default.store\(suffix)")
                let newAux = URL(fileURLWithPath: newStoreURL.path + suffix)
                if fm.fileExists(atPath: legacyAux.path) {
                    try? fm.copyItem(at: legacyAux, to: newAux)
                }
            }

            print("ModelContainerFactory: migrated legacy store \(legacyStoreURL.path) → \(newStoreURL.path)")
        } catch {
            // If migration fails, the new container will be empty. We deliberately
            // do NOT delete the legacy store, so a future build can retry.
            print("ModelContainerFactory: migration failed (\(error)). Legacy store preserved at \(legacyStoreURL.path).")
        }
    }
}
