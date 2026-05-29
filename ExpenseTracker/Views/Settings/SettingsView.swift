//
//  SettingsView.swift
//  ExpenseTracker
//

import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: [SortDescriptor(\AppSettings.createdAt, order: .forward)])
    private var settingsList: [AppSettings]
    @Query(filter: #Predicate<Account> { !$0.isArchived },
           sort: [SortDescriptor(\Account.name)])
    private var accounts: [Account]

    @State private var rateInput: Decimal = 90_000
    @State private var defaultCurrency: Currency = .usd
    @State private var defaultAccountID: UUID?
    @State private var notificationStatusText: String = "Checking…"
    @State private var showingResetSheet: Bool = false
    @State private var lockEnabledLocal: Bool = false
    @State private var lockTimeoutLocal: LockTimeoutOption = .immediately
    @State private var biometricKind: BiometricKind = .none
    @State private var lockError: String?

    private var settings: AppSettings? { settingsList.first }

    var body: some View {
        Form {
            Section("Exchange rate") {
                HStack {
                    Text("1 USD =")
                    TextField("90000", value: $rateInput, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                    Text("LBP").foregroundStyle(.secondary)
                }
                Button("Save rate", action: saveRate)
                    .disabled(rateInput <= 0 || rateInput == settings?.usdToLbpRate)
            }

            Section("Defaults") {
                Picker("Default currency", selection: $defaultCurrency) {
                    ForEach(Currency.allCases) { c in
                        Text("\(c.displayCode) — \(c.fullName)").tag(c)
                    }
                }
                Picker("Default account", selection: $defaultAccountID) {
                    Text("None").tag(UUID?.none)
                    ForEach(accounts) { acc in
                        Text(acc.name).tag(Optional(acc.id))
                    }
                }
            }

            Section("Categories & tags") {
                NavigationLink {
                    CategoryManagementView()
                } label: {
                    Label("Manage Categories", systemImage: "tag.fill")
                }
                NavigationLink {
                    TagManagementView()
                } label: {
                    Label("Manage Tags", systemImage: "number")
                }
                NavigationLink {
                    TemplatesManagementView()
                } label: {
                    Label("Manage Templates", systemImage: "star.circle.fill")
                }
            }

            Section {
                Toggle(isOn: Binding(
                    get: { lockEnabledLocal },
                    set: { newValue in
                        Task { await handleLockToggle(newValue) }
                    }
                )) {
                    Label("Require \(biometricKind.settingsLabel)", systemImage: biometricKind.systemImage)
                }

                if lockEnabledLocal {
                    Picker("Lock when returning", selection: Binding(
                        get: { lockTimeoutLocal },
                        set: { newValue in
                            lockTimeoutLocal = newValue
                            settings?.lockTimeoutSeconds = newValue.rawValue
                            try? context.save()
                        }
                    )) {
                        ForEach(LockTimeoutOption.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                }

                if let lockError {
                    Text(lockError)
                        .font(.caption)
                        .foregroundStyle(Color(hex: "#FF3B30"))
                }
            } header: {
                Text("Privacy")
            } footer: {
                Text(lockEnabledLocal
                     ? "You'll be asked to authenticate when launching the app and after the chosen period of background time."
                     : "Lock the app behind \(biometricKind.settingsLabel) so anyone holding your phone can't see your finances.")
            }

            Section {
                HStack {
                    Text("System status")
                    Spacer()
                    Text(notificationStatusText).foregroundStyle(.secondary)
                }
                Button("Request permission") {
                    Task {
                        _ = await NotificationService.shared.requestAuthorizationIfNeeded()
                        await refreshNotificationStatus()
                    }
                }
                Button("Open iOS Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Toggle(isOn: Binding(
                    get: { settings?.notifyOnBudgetWarning ?? false },
                    set: { newValue in
                        settings?.notifyOnBudgetWarning = newValue
                        try? context.save()
                    }
                )) {
                    Label("Budget alerts", systemImage: "exclamationmark.triangle.fill")
                }
            } header: {
                Text("Notifications")
            } footer: {
                Text("Budget alerts fire once when any category crosses 80% and again at 100% of its monthly cap. Each budget re-arms at the start of the new month.")
            }

            Section("About") {
                LabeledContent("App", value: "ExpenseTracker")
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
            }

            Section {
                Button(role: .destructive) {
                    showingResetSheet = true
                } label: {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("Reset All Data")
                            .fontWeight(.semibold)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                            .font(.caption.weight(.semibold))
                    }
                }
            } header: {
                Text("Danger Zone")
            } footer: {
                Text("Permanently erases every account, expense, subscription, and setting. Default categories will be re-seeded.")
            }
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showingResetSheet) {
            ResetDataView()
        }
        .onAppear(perform: load)
        .onChange(of: defaultCurrency) { _, new in
            settings?.defaultCurrency = new
            try? context.save()
        }
        .onChange(of: defaultAccountID) { _, new in
            settings?.defaultAccountID = new
            try? context.save()
        }
        .task { await refreshNotificationStatus() }
    }

    private func load() {
        guard let s = settings else { return }
        rateInput = s.usdToLbpRate
        defaultCurrency = s.defaultCurrency
        defaultAccountID = s.defaultAccountID
        lockEnabledLocal = s.isLockEnabled
        lockTimeoutLocal = LockTimeoutOption.option(forStoredValue: s.lockTimeoutSeconds)
        biometricKind = BiometricAuthService.availableBiometric()
    }

    /// Verifies the user can actually authenticate before flipping the toggle ON,
    /// so they don't lock themselves out. Toggling OFF authenticates first too,
    /// to prevent a thief from disabling the lock if it's already on.
    @MainActor
    private func handleLockToggle(_ newValue: Bool) async {
        lockError = nil
        let reason = newValue
            ? "Enable lock on ExpenseTracker."
            : "Disable lock on ExpenseTracker."

        let success = await BiometricAuthService.authenticate(reason: reason)
        guard success else {
            lockError = "Authentication required to change this setting."
            return
        }
        lockEnabledLocal = newValue
        settings?.isLockEnabled = newValue
        try? context.save()
    }

    private func saveRate() {
        guard let s = settings else { return }
        s.usdToLbpRate = rateInput
        try? context.save()
    }

    private func refreshNotificationStatus() async {
        let status = await NotificationService.shared.authorizationStatus()
        notificationStatusText = {
            switch status {
            case .authorized:    return "Authorized"
            case .provisional:   return "Provisional"
            case .ephemeral:     return "Ephemeral"
            case .denied:        return "Denied"
            case .notDetermined: return "Not requested"
            @unknown default:    return "Unknown"
            }
        }()
    }
}
