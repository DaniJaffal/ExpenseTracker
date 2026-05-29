//
//  AccountBalanceWidget.swift
//  ExpenseTrackerWidget
//
//  Configurable widget: pick which account(s) to show.
//  - Small  → 1 account
//  - Medium → up to 3 accounts
//  - Large  → up to 8 accounts
//

import WidgetKit
import SwiftUI
import SwiftData
import AppIntents

// MARK: - Configuration intent

struct ConfigureAccountBalanceIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Account Balance"
    static var description = IntentDescription("Pick which accounts to show.")

    @Parameter(title: "Accounts")
    var accounts: [AccountEntity]?
}

// MARK: - Entry

struct AccountBalanceEntry: TimelineEntry {
    let date: Date
    let items: [Item]

    struct Item: Identifiable {
        let id: UUID
        let name: String
        let typeName: String
        let iconName: String
        let colorHex: String
        let balance: Decimal
        let currency: Currency
    }
}

// MARK: - Provider

struct AccountBalanceProvider: AppIntentTimelineProvider {

    func placeholder(in context: Context) -> AccountBalanceEntry {
        AccountBalanceEntry(date: Date(), items: [
            .init(id: UUID(), name: "Cash USD", typeName: "Cash",
                  iconName: "banknote.fill", colorHex: "#34C759",
                  balance: 320, currency: .usd)
        ])
    }

    func snapshot(for configuration: ConfigureAccountBalanceIntent, in context: Context) async -> AccountBalanceEntry {
        await load(configuration: configuration, maxItems: maxItems(for: context.family))
    }

    func timeline(for configuration: ConfigureAccountBalanceIntent, in context: Context) async -> Timeline<AccountBalanceEntry> {
        let entry = await load(configuration: configuration, maxItems: maxItems(for: context.family))
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: entry.date) ?? entry.date
        return Timeline(entries: [entry], policy: .after(next))
    }

    private func maxItems(for family: WidgetFamily) -> Int {
        switch family {
        case .systemSmall:  return 1
        case .systemMedium: return 3
        case .systemLarge:  return 8
        default:            return 1
        }
    }

    @MainActor
    private func load(configuration: ConfigureAccountBalanceIntent, maxItems: Int) async -> AccountBalanceEntry {
        WidgetData.read(defaultValue: AccountBalanceEntry(date: Date(), items: [])) { context in
            let settings = (try? context.fetch(FetchDescriptor<AppSettings>()))?.first
            let rate = settings?.usdToLbpRate ?? Decimal(90_000)

            // Pull all active accounts so we can resolve the configured IDs.
            let descriptor = FetchDescriptor<Account>(
                predicate: #Predicate { !$0.isArchived },
                sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.name)]
            )
            let allAccounts = (try? context.fetch(descriptor)) ?? []

            // Filter to configured selection if present; otherwise fall back to all.
            let chosen: [Account]
            if let configured = configuration.accounts, !configured.isEmpty {
                let configuredIDs = Set(configured.map(\.id))
                chosen = allAccounts.filter { configuredIDs.contains($0.id) }
            } else {
                chosen = allAccounts
            }

            let items = chosen.prefix(maxItems).map { acc in
                AccountBalanceEntry.Item(
                    id: acc.id,
                    name: acc.name,
                    typeName: acc.type.displayName,
                    iconName: acc.iconName,
                    colorHex: acc.colorHex,
                    balance: BalanceService.currentBalance(for: acc, usdToLbpRate: rate),
                    currency: acc.currency
                )
            }
            return AccountBalanceEntry(date: Date(), items: Array(items))
        }
    }
}

// MARK: - View

struct AccountBalanceWidgetView: View {
    let entry: AccountBalanceEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall:
            singleView
        default:
            gridView
        }
    }

    private var singleView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let item = entry.items.first {
                HStack(spacing: 8) {
                    iconBadge(symbol: item.iconName, color: Color(hex: item.colorHex))
                    Text(item.name)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Text(Formatters.currency(item.balance, in: item.currency))
                    .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(item.typeName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.background, for: .widget)
    }

    private var gridView: some View {
        let columns = family == .systemMedium
            ? [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
            : [GridItem(.flexible()), GridItem(.flexible())]
        return Group {
            if entry.items.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(entry.items) { item in
                        accountTile(item)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.background, for: .widget)
    }

    private func accountTile(_ item: AccountBalanceEntry.Item) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                iconBadge(symbol: item.iconName, color: Color(hex: item.colorHex), size: 22)
                Text(item.currency.displayCode)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text(item.name)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            Text(Formatters.currency(item.balance, in: item.currency))
                .font(.subheadline.weight(.bold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .padding(8)
        .background(Color.secondary.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "creditcard")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Tap to pick accounts")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func iconBadge(symbol: String, color: Color, size: CGFloat = 26) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(color.opacity(0.18))
            Image(systemName: symbol)
                .font(.system(size: size * 0.48, weight: .semibold))
                .foregroundStyle(color)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Widget

struct AccountBalanceWidget: Widget {
    let kind: String = "AccountBalanceWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ConfigureAccountBalanceIntent.self,
            provider: AccountBalanceProvider()
        ) { entry in
            AccountBalanceWidgetView(entry: entry)
        }
        .configurationDisplayName("Account Balance")
        .description("Pick one or more accounts and see their balances at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
