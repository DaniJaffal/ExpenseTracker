//
//  DebtsListView.swift
//  ExpenseTracker
//
//  Two-sided ledger of who owes you and who you owe. Settled debts collapse
//  into a "History" section at the bottom.
//

import SwiftUI
import SwiftData

struct DebtsListView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: [SortDescriptor(\Debt.createdAt, order: .reverse)])
    private var allDebts: [Debt]

    @Query(sort: [SortDescriptor(\AppSettings.createdAt, order: .forward)])
    private var settingsList: [AppSettings]

    @State private var editing: Debt?
    @State private var showingAdd = false
    @State private var showHistory = false

    private var displayCurrency: Currency { settingsList.first?.defaultCurrency ?? .usd }
    private var rate: Decimal { settingsList.first?.usdToLbpRate ?? 90_000 }

    private var owedToMe: [Debt] {
        allDebts.filter { $0.direction == .owedToMe && !$0.isSettled }
    }

    private var iOwe: [Debt] {
        allDebts.filter { $0.direction == .iOwe && !$0.isSettled }
    }

    private var settled: [Debt] {
        allDebts.filter { $0.isSettled }
    }

    private var totalOwedToMe: Decimal {
        owedToMe.reduce(Decimal(0)) { acc, debt in
            acc + CurrencyService.convert(debt.amount, from: debt.currency, to: displayCurrency, usdToLbpRate: rate)
        }
    }

    private var totalIOwe: Decimal {
        iOwe.reduce(Decimal(0)) { acc, debt in
            acc + CurrencyService.convert(debt.amount, from: debt.currency, to: displayCurrency, usdToLbpRate: rate)
        }
    }

    var body: some View {
        Group {
            if allDebts.isEmpty {
                EmptyStateView(
                    symbol: "person.2",
                    title: "No debts tracked",
                    message: "Keep tabs on who owes you and who you owe. Informational only — your accounts aren't affected.",
                    actionTitle: "Add Debt",
                    action: { showingAdd = true }
                )
            } else {
                List {
                    Section {
                        summaryRow
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowBackground(Color.clear)
                    }

                    if !owedToMe.isEmpty {
                        Section("Owed to me") {
                            ForEach(owedToMe) { debt in
                                Button { editing = debt } label: {
                                    DebtRow(debt: debt)
                                }
                                .buttonStyle(.plain)
                                .swipeActions(edge: .leading) {
                                    Button {
                                        settle(debt)
                                    } label: {
                                        Label("Settle", systemImage: "checkmark.circle.fill")
                                    }
                                    .tint(Color(hex: "#34C759"))
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        delete(debt)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }

                    if !iOwe.isEmpty {
                        Section("I owe") {
                            ForEach(iOwe) { debt in
                                Button { editing = debt } label: {
                                    DebtRow(debt: debt)
                                }
                                .buttonStyle(.plain)
                                .swipeActions(edge: .leading) {
                                    Button {
                                        settle(debt)
                                    } label: {
                                        Label("Settle", systemImage: "checkmark.circle.fill")
                                    }
                                    .tint(Color(hex: "#34C759"))
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        delete(debt)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }

                    if !settled.isEmpty {
                        Section {
                            DisclosureGroup(isExpanded: $showHistory) {
                                ForEach(settled) { debt in
                                    Button { editing = debt } label: {
                                        DebtRow(debt: debt, dimmed: true)
                                    }
                                    .buttonStyle(.plain)
                                    .swipeActions(edge: .leading) {
                                        Button {
                                            unsettle(debt)
                                        } label: {
                                            Label("Reopen", systemImage: "arrow.uturn.left.circle.fill")
                                        }
                                        .tint(Color(hex: "#FF9500"))
                                    }
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            delete(debt)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Text("History")
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Text("\(settled.count) settled")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Debts")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingAdd = true } label: {
                    Image(systemName: "plus.circle.fill").font(.title3)
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            NavigationStack { DebtEditorView(debt: nil) }
        }
        .sheet(item: $editing) { debt in
            NavigationStack { DebtEditorView(debt: debt) }
        }
    }

    private var summaryRow: some View {
        HStack(spacing: 12) {
            summaryTile(
                title: "Owed to me",
                value: Formatters.currency(totalOwedToMe, in: displayCurrency),
                count: owedToMe.count,
                tint: Color(hex: "#34C759"),
                symbol: "arrow.down.left.circle.fill"
            )
            summaryTile(
                title: "I owe",
                value: Formatters.currency(totalIOwe, in: displayCurrency),
                count: iOwe.count,
                tint: Color(hex: "#FF6B6B"),
                symbol: "arrow.up.right.circle.fill"
            )
        }
    }

    private func summaryTile(title: String, value: String, count: Int, tint: Color, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: symbol).foregroundStyle(tint)
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
            Text(value)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text("\(count) open")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func settle(_ debt: Debt) {
        debt.isSettled = true
        debt.settledDate = Date()
        try? context.save()
    }

    private func unsettle(_ debt: Debt) {
        debt.isSettled = false
        debt.settledDate = nil
        try? context.save()
    }

    private func delete(_ debt: Debt) {
        context.delete(debt)
        try? context.save()
    }
}

// MARK: - Row

private struct DebtRow: View {
    let debt: Debt
    var dimmed: Bool = false

    private var tint: Color {
        debt.direction == .owedToMe ? Color(hex: "#34C759") : Color(hex: "#FF6B6B")
    }

    private var symbol: String {
        debt.direction == .owedToMe ? "arrow.down.left.circle.fill" : "arrow.up.right.circle.fill"
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tint.opacity(0.18))
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text(debt.personName.isEmpty ? "Unnamed" : debt.personName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    if let due = debt.dueDate, !debt.isSettled {
                        Text("Due \(Formatters.relativeDate(due))")
                    } else if debt.isSettled, let settledDate = debt.settledDate {
                        Text("Settled \(Formatters.relativeDate(settledDate))")
                    } else if !debt.note.isEmpty {
                        Text(debt.note).lineLimit(1)
                    } else {
                        Text("No due date")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text(Formatters.currency(debt.amount, in: debt.currency))
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 4)
        .opacity(dimmed ? 0.55 : 1)
    }
}
