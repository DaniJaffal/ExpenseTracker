//
//  ExpenseTrackerApp.swift
//  ExpenseTracker
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct ExpenseTrackerApp: App {

    init() {
        // Show notification banners + play sounds even while the app is in
        // the foreground (budget alerts, sub renewals, expected expense due).
        UNUserNotificationCenter.current().delegate = ForegroundNotificationDelegate.shared
    }


    // The container lives in the App Group shared container so the Widget
    // Extension can read it. If the App Group capability isn't configured yet,
    // ModelContainerFactory falls back to the default location automatically.
    let modelContainer: ModelContainer = ModelContainerFactory.make()

    var body: some Scene {
        WindowGroup {
            RootView()
                .task {
                    SeedService.bootstrap(in: modelContainer.mainContext)
                }
        }
        .modelContainer(modelContainer)
    }
}
