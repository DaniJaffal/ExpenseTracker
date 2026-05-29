//
//  SavingsGoalsListView.swift
//  ExpenseTracker
//
//  Full list of savings goals as colorful cards. Tap to edit, swipe to delete,
//  "+ Contribute" button on each card for one-tap progress updates.
//

import SwiftUI
import SwiftData

struct SavingsGoalsListView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: [SortDescriptor(\SavingsGoal.sortOrder), SortDescriptor(\SavingsGoal.createdAt)])
    private var goals: [SavingsGoal]

    @State private var editing: SavingsGoal?
    @State private var contributing: SavingsGoal?
    @State private var showingAdd = false

    private var active: [SavingsGoal] { goals.filter { !$0.isComplete } }
    private var completed: [SavingsGoal] { goals.filter { $0.isComplete } }

    var body: some View {
        Group {
            if goals.isEmpty {
                EmptyStateView(
                    symbol: "star.circle",
                    title: "No goals yet",
                    message: "Set a target, link an account, and track your way there.",
                    actionTitle: "Add Goal",
                    action: { showingAdd = true }
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if !active.isEmpty {
                            sectionHeader("Active")
                            VStack(spacing: 12) {
                                ForEach(active) { goal in
                                    SavingsGoalCard(goal: goal) {
                                        contributing = goal
                                    }
                                    .onTapGesture { editing = goal }
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            delete(goal)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                        if !completed.isEmpty {
                            sectionHeader("Completed")
                            VStack(spacing: 12) {
                                ForEach(completed) { goal in
                                    SavingsGoalCard(goal: goal, onContribute: nil)
                                        .onTapGesture { editing = goal }
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                delete(goal)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .background(Color(.systemGroupedBackground))
            }
        }
        .navigationTitle("Goals")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingAdd = true } label: {
                    Image(systemName: "plus.circle.fill").font(.title3)
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            NavigationStack { SavingsGoalEditorView(goal: nil) }
        }
        .sheet(item: $editing) { goal in
            NavigationStack { SavingsGoalEditorView(goal: goal) }
        }
        .sheet(item: $contributing) { goal in
            ContributeSheet(goal: goal)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .padding(.top, 4)
            .padding(.horizontal, 4)
    }

    private func delete(_ goal: SavingsGoal) {
        context.delete(goal)
        try? context.save()
    }
}

// MARK: - Goal card

struct SavingsGoalCard: View {
    let goal: SavingsGoal
    /// nil disables the contribute button (e.g. for completed goals).
    let onContribute: (() -> Void)?

    private var tint: Color { Color(hex: goal.colorHex) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.white.opacity(0.22))
                    Image(systemName: goal.iconName)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if let acc = goal.account {
                        Text("In \(acc.name)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(1)
                    }
                }
                Spacer()
                Text("\(goal.percent)%")
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 6) {
                BudgetProgressBar(fraction: goal.fraction, tint: .white.opacity(0.95), height: 10)
                HStack {
                    Text(Formatters.currency(goal.contributedAmount, in: goal.currency))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text(Formatters.currency(goal.targetAmount, in: goal.currency))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }

            HStack {
                if let deadline = goal.deadline {
                    Label(Formatters.relativeDate(deadline), systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.9))
                } else {
                    Text("No deadline")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                if let onContribute {
                    Button(action: onContribute) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text("Contribute")
                        }
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(.white.opacity(0.22))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                } else if let completed = goal.completedDate {
                    Label("Completed \(Formatters.relativeDate(completed))", systemImage: "checkmark.seal.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [tint, tint.opacity(0.65)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
    }
}
