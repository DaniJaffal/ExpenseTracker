//
//  QuickLogWidget.swift
//  ExpenseTrackerWidget
//
//  Interactive widget (iOS 17+): user configures a template (amount + currency
//  + account + category), then a single tap on the widget logs that expense
//  with one tap — no app launch needed.
//
//  Useful for predictable recurring small expenses (e.g. "morning coffee").
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Configuration intent

struct ConfigureQuickLogIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Quick Log"
    static var description = IntentDescription("Configure the expense template to log with one tap.")

    @Parameter(title: "Amount", default: 5.0)
    var amount: Double

    @Parameter(title: "Currency", default: .usd)
    var currency: CurrencyAppEnum

    @Parameter(title: "Account")
    var account: AccountEntity?

    @Parameter(title: "Category")
    var category: CategoryEntity?

    @Parameter(title: "Label", default: "Coffee")
    var label: String
}

// MARK: - Entry

struct QuickLogEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigureQuickLogIntent
}

// MARK: - Provider

struct QuickLogProvider: AppIntentTimelineProvider {

    func placeholder(in context: Context) -> QuickLogEntry {
        QuickLogEntry(date: Date(), configuration: ConfigureQuickLogIntent())
    }

    func snapshot(for configuration: ConfigureQuickLogIntent, in context: Context) async -> QuickLogEntry {
        QuickLogEntry(date: Date(), configuration: configuration)
    }

    func timeline(for configuration: ConfigureQuickLogIntent, in context: Context) async -> Timeline<QuickLogEntry> {
        Timeline(entries: [QuickLogEntry(date: Date(), configuration: configuration)], policy: .never)
    }
}

// MARK: - View

struct QuickLogWidgetView: View {
    let entry: QuickLogEntry

    private var hasAccount: Bool { entry.configuration.account != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "bolt.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color(hex: "#5856D6"))
                Text(entry.configuration.label)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Spacer()
            }

            Spacer(minLength: 0)

            Text(Formatters.currency(Decimal(entry.configuration.amount), in: entry.configuration.currency.modelCurrency))
                .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            if let acc = entry.configuration.account {
                Text("From \(acc.name)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if hasAccount, let accountID = entry.configuration.account?.id {
                Button(intent: LogExpenseIntent(
                    amount: entry.configuration.amount,
                    currency: entry.configuration.currency,
                    accountID: accountID,
                    categoryID: entry.configuration.category?.id,
                    note: entry.configuration.label
                )) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Log").font(.caption.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color(hex: "#5856D6"))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                Text("Tap & hold → Edit Widget to set up.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.background, for: .widget)
    }
}

// MARK: - Widget

struct QuickLogWidget: Widget {
    let kind: String = "QuickLogWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ConfigureQuickLogIntent.self,
            provider: QuickLogProvider()
        ) { entry in
            QuickLogWidgetView(entry: entry)
        }
        .configurationDisplayName("Quick Log")
        .description("One tap to log a recurring expense (e.g. morning coffee). Configure the amount, account, and category in widget settings.")
        .supportedFamilies([.systemSmall])
    }
}
