//
//  ResetDataView.swift
//  ExpenseTracker
//
//  Confirmation sheet for the "Reset All Data" action.
//  Uses a type-to-confirm pattern: the destructive button stays disabled
//  until the user types RESET exactly. Prevents accidental taps.
//

import SwiftUI
import SwiftData

struct ResetDataView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var typed: String = ""
    @State private var isResetting: Bool = false
    @FocusState private var fieldFocused: Bool

    private let confirmationWord = "RESET"

    private var canReset: Bool {
        typed.trimmingCharacters(in: .whitespaces) == confirmationWord && !isResetting
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerCard

                    VStack(alignment: .leading, spacing: 12) {
                        Text("What this deletes")
                            .font(.subheadline.weight(.semibold))
                        VStack(alignment: .leading, spacing: 8) {
                            bulletRow("All accounts and their balances")
                            bulletRow("All expenses (with splits and returns)")
                            bulletRow("All transfers")
                            bulletRow("All subscriptions and expected expenses")
                            bulletRow("Custom categories (default categories will be re-seeded)")
                            bulletRow("Your exchange rate and default-currency settings")
                            bulletRow("All scheduled notifications")
                        }
                    }
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Type \(confirmationWord) to confirm")
                            .font(.subheadline.weight(.semibold))
                        TextField(confirmationWord, text: $typed)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .focused($fieldFocused)
                            .padding(12)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(canReset ? Color(hex: "#FF3B30") : Color.secondary.opacity(0.25),
                                                  lineWidth: 1)
                            )
                            .font(.body.monospaced())
                    }

                    Button(role: .destructive, action: performReset) {
                        HStack {
                            if isResetting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "trash.fill")
                            }
                            Text(isResetting ? "Resetting…" : "Reset All Data")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(canReset ? Color(hex: "#FF3B30") : Color.secondary.opacity(0.2))
                        .foregroundStyle(canReset ? .white : .secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canReset)

                    Text("This action cannot be undone. There is no backup.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Reset Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isResetting)
                }
            }
            .onAppear {
                // Slight delay so the sheet animation finishes before focus.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    fieldFocused = true
                }
            }
        }
        .interactiveDismissDisabled(isResetting)
    }

    // MARK: - Pieces

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.white.opacity(0.2))
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Danger Zone")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Erase everything and start fresh")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))
                }
                Spacer()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color(hex: "#FF6B6B"), Color(hex: "#FF3B30")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func bulletRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "minus")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.top, 5)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Action

    private func performReset() {
        guard canReset else { return }
        isResetting = true

        // Brief delay so the spinner is visible — the actual reset is fast.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            DataResetService.wipeAndReseed(in: context)
            isResetting = false
            dismiss()
        }
    }
}
