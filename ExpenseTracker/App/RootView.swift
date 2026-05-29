//
//  RootView.swift
//  ExpenseTracker
//
//  Root tab bar + global deep-link handling + biometric lock overlay.
//

import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase

    @Query(sort: [SortDescriptor(\AppSettings.createdAt, order: .forward)])
    private var settingsList: [AppSettings]

    @State private var selectedTab: RootTab = .overview
    @State private var pendingNewExpense: Bool = false

    // Lock state.
    @State private var isLocked: Bool = false
    @State private var hasDoneInitialEvaluation: Bool = false
    @State private var lastInactiveAt: Date?

    private var settings: AppSettings? { settingsList.first }
    private var lockEnabled: Bool { settings?.isLockEnabled ?? false }

    enum RootTab: Hashable {
        case overview, transactions, accounts, planning, settings
    }

    var body: some View {
        ZStack {
            mainTabs
                .onOpenURL { url in handleDeepLink(url) }
                .sheet(isPresented: $pendingNewExpense) {
                    ExpenseEditorView(expense: nil)
                }

            // Privacy blur during inactive / background transitions when unlocked.
            if scenePhase != .active && lockEnabled && !isLocked {
                PrivacyBlurView()
                    .transition(.opacity)
            }

            if isLocked {
                LockedScreenView(onUnlock: unlock)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isLocked)
        .animation(.easeInOut(duration: 0.15), value: scenePhase)
        .onChange(of: scenePhase, initial: true) { _, newPhase in
            handleScenePhase(newPhase)
        }
    }

    private var mainTabs: some View {
        TabView(selection: $selectedTab) {
            Tab("Overview", systemImage: "rectangle.grid.2x2.fill", value: RootTab.overview) {
                DashboardView()
            }
            Tab("Transactions", systemImage: "list.bullet.rectangle.fill", value: RootTab.transactions) {
                NavigationStack { TransactionsListView() }
            }
            Tab("Accounts", systemImage: "creditcard.fill", value: RootTab.accounts) {
                NavigationStack { AccountsListView() }
            }
            Tab("Planning", systemImage: "calendar.badge.clock", value: RootTab.planning) {
                NavigationStack { PlanningHubView() }
            }
            Tab("Settings", systemImage: "gearshape.fill", value: RootTab.settings) {
                NavigationStack { SettingsView() }
            }
        }
    }

    // MARK: - Deep link

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "expensetracker" else { return }
        switch url.host {
        case "new-expense":
            selectedTab = .overview
            pendingNewExpense = true
        default:
            break
        }
    }

    // MARK: - Lock evaluation

    private func handleScenePhase(_ phase: ScenePhase) {
        guard lockEnabled else {
            isLocked = false
            return
        }

        switch phase {
        case .active:
            if !hasDoneInitialEvaluation {
                hasDoneInitialEvaluation = true
                // Lock the app on initial launch when the feature is enabled.
                isLocked = true
                return
            }
            // Returning to foreground — decide based on background elapsed time.
            evaluateOnForeground()
        case .inactive, .background:
            lastInactiveAt = Date()
        @unknown default:
            break
        }
    }

    private func evaluateOnForeground() {
        guard let settings else { return }
        let timeout = settings.lockTimeoutSeconds

        // Special: "Only at launch" means we don't re-lock on foreground return.
        if timeout == LockTimeoutOption.launchOnly.rawValue {
            return
        }

        guard let backgrounded = lastInactiveAt else {
            // First time foregrounding without a background timestamp — leave as-is.
            return
        }
        let elapsed = Date().timeIntervalSince(backgrounded)
        if elapsed >= TimeInterval(max(0, timeout)) {
            isLocked = true
        }
    }

    private func unlock() {
        isLocked = false
        lastInactiveAt = nil
    }
}

/// Combined screen for Subscriptions, Expected Expenses, and Analytics.
struct PlanningHubView: View {
    var body: some View {
        List {
            Section("Recurring & upcoming") {
                NavigationLink {
                    SubscriptionsListView()
                } label: {
                    Label("Subscriptions", systemImage: "repeat.circle.fill")
                }
                NavigationLink {
                    ExpectedExpensesListView()
                } label: {
                    Label("Expected Expenses", systemImage: "calendar.badge.clock")
                }
            }

            Section("Targets") {
                NavigationLink {
                    BudgetsListView()
                } label: {
                    Label("Budgets", systemImage: "chart.bar.doc.horizontal")
                }
                NavigationLink {
                    SavingsGoalsListView()
                } label: {
                    Label("Savings Goals", systemImage: "star.circle.fill")
                }
            }

            Section("Relationships") {
                NavigationLink {
                    DebtsListView()
                } label: {
                    Label("Debts", systemImage: "person.2.fill")
                }
            }

            Section("Insights") {
                NavigationLink {
                    AnalyticsView()
                } label: {
                    Label("Analytics", systemImage: "chart.pie.fill")
                }
                NavigationLink {
                    AnnualSummaryView()
                } label: {
                    Label("Year in Review", systemImage: "calendar.circle.fill")
                }
            }
        }
        .navigationTitle("Planning")
    }
}
