//
//  ContributeSheet.swift
//  ExpenseTracker
//
//  Quick "+ Contribute" sheet — adds a positive amount to the goal's
//  contributedAmount. No transfer, no expense — informational only.
//

import SwiftUI
import SwiftData

struct ContributeSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let goal: SavingsGoal

    @State private var amount: Decimal = 0
    @FocusState private var fieldFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                headerCard

                VStack(alignment: .leading, spacing: 8) {
                    Text("Add to this goal")
                        .font(.subheadline.weight(.semibold))
                    HStack {
                        TextField("0", value: $amount, format: .number)
                            .keyboardType(.decimalPad)
                            .focused($fieldFocused)
                            .font(.largeTitle.weight(.bold).monospacedDigit())
                            .multilineTextAlignment(.leading)
                        Text(goal.currency.displayCode)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                Text("This is for tracking only — it doesn't change your account balance. If you actually moved money into this account, log it as a Transfer separately.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button(action: contribute) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Contribution")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(amount > 0 ? Color(hex: goal.colorHex) : Color.secondary.opacity(0.2))
                    .foregroundStyle(amount > 0 ? .white : .secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(amount <= 0)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Contribute")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    fieldFocused = true
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var headerCard: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.white.opacity(0.2))
                Image(systemName: goal.iconName)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(goal.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("\(Formatters.currency(goal.contributedAmount, in: goal.currency)) of \(Formatters.currency(goal.targetAmount, in: goal.currency))")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
            }
            Spacer()
            Text("\(goal.percent)%")
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(.white)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color(hex: goal.colorHex), Color(hex: goal.colorHex).opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func contribute() {
        guard amount > 0 else { return }
        let wasComplete = goal.isComplete
        goal.contributedAmount += amount
        if !wasComplete && goal.isComplete {
            goal.completedDate = Date()
        }
        try? context.save()
        dismiss()
    }
}
