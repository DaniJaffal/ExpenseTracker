//
//  TotalBalanceWidget.swift
//  ExpenseTrackerWidget
//
//  Small widget showing the user's total balance across all active accounts,
//  converted into their default currency.
//

import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Entry

struct TotalBalanceEntry: TimelineEntry {
    let date: Date
    let total: Decimal
    let currency: Currency
    let accountCount: Int
}

// MARK: - Provider

struct TotalBalanceProvider: TimelineProvider {

    func placeholder(in context: Context) -> TotalBalanceEntry {
        TotalBalanceEntry(date: Date(), total: Decimal(1_234), currency: .usd, accountCount: 3)
    }

    func getSnapshot(in context: Context, completion: @escaping (TotalBalanceEntry) -> Void) {
        Task { @MainActor in
            completion(load())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TotalBalanceEntry>) -> Void) {
        Task { @MainActor in
            let entry = load()
            // Refresh once an hour as a safety net; explicit reloads from the app
            // will update it sooner when data actually changes.
            let next = Calendar.current.date(byAdding: .hour, value: 1, to: entry.date) ?? entry.date
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    @MainActor
    private func load() -> TotalBalanceEntry {
        WidgetData.read(
            defaultValue: TotalBalanceEntry(date: Date(), total: 0, currency: .usd, accountCount: 0)
        ) { context in
            let settings = (try? context.fetch(FetchDescriptor<AppSettings>()))?.first
            let currency = settings?.defaultCurrency ?? .usd
            let rate = settings?.usdToLbpRate ?? Decimal(90_000)

            let accountsDescriptor = FetchDescriptor<Account>(
                predicate: #Predicate { !$0.isArchived },
                sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.name)]
            )
            let accounts = (try? context.fetch(accountsDescriptor)) ?? []
            let total = BalanceService.totalBalance(
                accounts: accounts,
                in: currency,
                usdToLbpRate: rate
            )
            return TotalBalanceEntry(
                date: Date(),
                total: total,
                currency: currency,
                accountCount: accounts.count
            )
        }
    }
}

// MARK: - View

struct TotalBalanceWidgetView: View {
    let entry: TotalBalanceEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "wallet.bifold.fill")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
                Text("Total")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                Text(entry.currency.displayCode)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.white.opacity(0.18))
                    .clipShape(Capsule())
            }

            Spacer(minLength: 4)

            Text(Formatters.currency(entry.total, in: entry.currency))
                .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            if entry.accountCount > 0 {
                Text("\(entry.accountCount) account\(entry.accountCount == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.75))
            } else {
                Text("No accounts yet")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color(hex: "#4F8EF7"), Color(hex: "#5856D6")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Widget

struct TotalBalanceWidget: Widget {
    let kind: String = "TotalBalanceWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TotalBalanceProvider()) { entry in
            TotalBalanceWidgetView(entry: entry)
        }
        .configurationDisplayName("Total Balance")
        .description("Your combined balance across all accounts, in your default currency.")
        .supportedFamilies([.systemSmall])
    }
}
