//
//  AccountsListView.swift
//  ExpenseTracker
//

import SwiftUI
import SwiftData

struct AccountsListView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: [SortDescriptor(\Account.sortOrder), SortDescriptor(\Account.name)])
    private var accounts: [Account]

    @Query(sort: [SortDescriptor(\AppSettings.createdAt, order: .forward)])
    private var settingsList: [AppSettings]

    @State private var showingAdd = false
    @State private var showingTransfer = false

    private var rate: Decimal { settingsList.first?.usdToLbpRate ?? 90_000 }

    private var active: [Account] { accounts.filter { !$0.isArchived } }
    private var archived: [Account] { accounts.filter { $0.isArchived } }

    var body: some View {
        Group {
            if accounts.isEmpty {
                EmptyStateView(
                    symbol: "creditcard",
                    title: "No accounts yet",
                    message: "Add a cash, card, or savings account to start tracking.",
                    actionTitle: "Add Account",
                    action: { showingAdd = true }
                )
            } else {
                List {
                    Section {
                        ForEach(active) { account in
                            NavigationLink {
                                AccountDetailView(account: account)
                            } label: {
                                AccountListRow(account: account, rate: rate)
                            }
                        }
                    }
                    if !archived.isEmpty {
                        Section("Archived") {
                            ForEach(archived) { account in
                                NavigationLink {
                                    AccountDetailView(account: account)
                                } label: {
                                    AccountListRow(account: account, rate: rate)
                                        .opacity(0.65)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Accounts")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showingAdd = true
                    } label: {
                        Label("New Account", systemImage: "plus")
                    }
                    Button {
                        showingTransfer = true
                    } label: {
                        Label("Transfer", systemImage: "arrow.left.arrow.right")
                    }
                    .disabled(active.count < 2)
                } label: {
                    Image(systemName: "plus.circle.fill").font(.title3)
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            NavigationStack { AccountEditorView(account: nil) }
        }
        .sheet(isPresented: $showingTransfer) {
            TransferEditorView()
        }
    }
}

private struct AccountListRow: View {
    let account: Account
    let rate: Decimal

    var body: some View {
        let balance = BalanceService.currentBalance(for: account, usdToLbpRate: rate)
        HStack(spacing: 12) {
            IconBadge(symbol: account.iconName, color: Color(hex: account.colorHex))
            VStack(alignment: .leading, spacing: 2) {
                Text(account.name).font(.subheadline.weight(.semibold))
                Text("\(account.type.displayName) · \(account.currency.displayCode)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(Formatters.currency(balance, in: account.currency))
                .font(.subheadline.weight(.semibold).monospacedDigit())
        }
        .padding(.vertical, 4)
    }
}
