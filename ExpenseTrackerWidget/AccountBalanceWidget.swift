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
        Group {
            if let item = entry.items.first {
                let tint = Color(hex: item.colorHex)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top) {
                        Text(item.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary.opacity(0.85))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Spacer(minLength: 4)
                        Text(item.currency.displayCode)
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .tracking(0.5)
                            .foregroundStyle(.primary.opacity(0.9))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule(style: .continuous).fill(.ultraThinMaterial))
                    }
                    Spacer(minLength: 0)
                    Text(Formatters.currency(item.balance, in: item.currency))
                        .font(.system(size: 30, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                    Text(item.typeName.uppercased())
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .tracking(0.6)
                        .foregroundStyle(.primary.opacity(0.55))
                }
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [tint.opacity(0.30), tint.opacity(0.62)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            } else {
                emptyState
                    .containerBackground(.background, for: .widget)
            }
        }
    }

    private var gridView: some View {
        // Fixed-shape grid (columns × rows) so every cell ends up the same
        // size regardless of how short or long its label is. We deliberately
        // avoid LazyVGrid here — it sizes rows/cells to content and produces
        // uneven tiles when balances have very different widths.
        let columns = family == .systemMedium ? 3 : 2
        let rows = family == .systemMedium ? 1 : 4 // systemLarge → up to 8 tiles
        return Group {
            if entry.items.isEmpty {
                emptyState
            } else {
                VStack(spacing: 10) {
                    ForEach(0..<rows, id: \.self) { row in
                        HStack(spacing: 10) {
                            ForEach(0..<columns, id: \.self) { col in
                                let idx = row * columns + col
                                if idx < entry.items.count {
                                    accountTile(entry.items[idx])
                                } else {
                                    // Invisible spacer cell keeps the columns
                                    // aligned when the final row is partially
                                    // filled (e.g. 7 of 8 large-widget slots).
                                    Color.clear
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.background, for: .widget)
    }

    private func accountTile(_ item: AccountBalanceEntry.Item) -> some View {
        let tint = Color(hex: item.colorHex)
        return VStack(alignment: .leading, spacing: 2) {
            // Top row: account name on the left, currency pill on the right.
            HStack(alignment: .top, spacing: 4) {
                Text(item.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 4)
                Text(item.currency.displayCode)
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .tracking(0.4)
                    .foregroundStyle(.primary.opacity(0.9))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule(style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
            }

            Spacer(minLength: 2)

            // Hero: the balance.
            Text(Formatters.currency(item.balance, in: item.currency))
                .font(.system(size: 18, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        // Fill the cell — without this the background tracks the content's
        // intrinsic width, so a "$327.38" tile ends up visibly narrower than
        // a "ل.ل 8,000,000" tile in the same row.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [tint.opacity(0.28), tint.opacity(0.58)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            // Thin inner border for definition on busy wallpapers.
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
