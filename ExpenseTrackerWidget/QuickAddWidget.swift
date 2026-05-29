//
//  QuickAddWidget.swift
//  ExpenseTrackerWidget
//
//  Tap target that deep-links into the app's New Expense screen.
//  Doesn't read any data — just renders a static tile.
//

import WidgetKit
import SwiftUI

// MARK: - Entry

struct QuickAddEntry: TimelineEntry {
    let date: Date
}

// MARK: - Provider

struct QuickAddProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickAddEntry { QuickAddEntry(date: Date()) }
    func getSnapshot(in context: Context, completion: @escaping (QuickAddEntry) -> Void) {
        completion(QuickAddEntry(date: Date()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickAddEntry>) -> Void) {
        // Static content — no need to refresh.
        completion(Timeline(entries: [QuickAddEntry(date: Date())], policy: .never))
    }
}

// MARK: - View

struct QuickAddWidgetView: View {
    let entry: QuickAddEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Link(destination: URL(string: "expensetracker://new-expense")!) {
            switch family {
            case .systemMedium:
                mediumBody
            default:
                smallBody
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color(hex: "#4F8EF7"), Color(hex: "#5856D6")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var smallBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(.white)
            Spacer(minLength: 4)
            Text("New\nExpense")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Text("Tap to log")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var mediumBody: some View {
        HStack(spacing: 14) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 4) {
                Text("New Expense")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                Text("Tap to open the editor with your default account and currency pre-filled.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Widget

struct QuickAddWidget: Widget {
    let kind: String = "QuickAddWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickAddProvider()) { entry in
            QuickAddWidgetView(entry: entry)
        }
        .configurationDisplayName("Quick Add Expense")
        .description("One tap to start logging a new expense in the app.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
