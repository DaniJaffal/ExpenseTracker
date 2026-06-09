//
//  SubscriptionsListView.swift
//  ExpenseTracker
//

import SwiftUI
import SwiftData

struct SubscriptionsListView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: [SortDescriptor(\Subscription.nextRenewalDate, order: .forward)])
    private var subscriptions: [Subscription]

    @State private var showingAdd = false

    private var active: [Subscription] { subscriptions.filter { $0.isActive } }
    private var inactive: [Subscription] { subscriptions.filter { !$0.isActive } }

    var body: some View {
        Group {
            if subscriptions.isEmpty {
                EmptyStateView(
                    symbol: "repeat.circle",
                    title: "No subscriptions",
                    message: "Track recurring services and memberships here.",
                    actionTitle: "Add Subscription",
                    action: { showingAdd = true }
                )
            } else {
                List {
                    Section {
                        ForEach(active) { sub in
                            NavigationLink {
                                SubscriptionEditorView(subscription: sub)
                            } label: {
                                SubscriptionRow(subscription: sub)
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    Task { await chargeNow(sub) }
                                } label: {
                                    Label("Charge Now", systemImage: "creditcard.circle.fill")
                                }
                                .tint(.blue)
                            }
                        }
                    }
                    if !inactive.isEmpty {
                        Section("Paused") {
                            ForEach(inactive) { sub in
                                NavigationLink {
                                    SubscriptionEditorView(subscription: sub)
                                } label: {
                                    SubscriptionRow(subscription: sub)
                                        .opacity(0.6)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Subscriptions")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingAdd = true } label: {
                    Image(systemName: "plus.circle.fill").font(.title3)
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            NavigationStack { SubscriptionEditorView(subscription: nil) }
        }
    }

    private func chargeNow(_ sub: Subscription) async {
        _ = RecurringService.chargeNow(sub, in: context)
        await NotificationService.shared.scheduleNotification(for: sub)
        WidgetRefresh.bump()
    }
}

private struct SubscriptionRow: View {
    let subscription: Subscription

    var body: some View {
        HStack(spacing: 12) {
            IconBadge(
                symbol: subscription.category?.iconName ?? "repeat.circle.fill",
                color: Color(hex: subscription.category?.colorHex ?? "#5856D6")
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(subscription.name).font(.subheadline.weight(.semibold))
                Text("\(subscription.billingCycle.displayName) · Renews \(Formatters.relativeDate(subscription.nextRenewalDate))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(Formatters.currency(subscription.amount, in: subscription.currency))
                .font(.subheadline.weight(.semibold).monospacedDigit())
        }
        .padding(.vertical, 4)
    }
}
