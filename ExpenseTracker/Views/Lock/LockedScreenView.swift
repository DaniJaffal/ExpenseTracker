//
//  LockedScreenView.swift
//  ExpenseTracker
//
//  Full-screen lock overlay. Auto-triggers biometric/passcode auth on
//  appearance; if the user cancels they can re-trigger with the Unlock
//  button.
//

import SwiftUI

struct LockedScreenView: View {
    /// Called when authentication succeeds.
    let onUnlock: () -> Void

    @State private var isAuthenticating = false
    @State private var failedAttempts = 0
    @State private var biometric: BiometricKind = .none

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#4F8EF7"), Color(hex: "#5856D6")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                // App "logo"
                Text("ET")
                    .font(.system(size: 88, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.white.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                VStack(spacing: 6) {
                    Text("ExpenseTracker")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("Locked")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.75))
                }

                Spacer()

                Button(action: triggerAuth) {
                    HStack(spacing: 8) {
                        if isAuthenticating {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: biometric.systemImage)
                                .font(.title3.weight(.semibold))
                        }
                        Text(isAuthenticating ? "Authenticating…" : "Unlock with \(biometric.settingsLabel)")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(Color(hex: "#5856D6"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isAuthenticating)
                .padding(.horizontal, 24)

                if failedAttempts > 0 {
                    Text("Authentication failed. Tap to try again.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                }

                Spacer().frame(height: 20)
            }
            .padding(.horizontal)
        }
        .task {
            biometric = BiometricAuthService.availableBiometric()
            triggerAuth()
        }
    }

    private func triggerAuth() {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        Task {
            let success = await BiometricAuthService.authenticate(
                reason: "Unlock ExpenseTracker to see your accounts and transactions."
            )
            isAuthenticating = false
            if success {
                failedAttempts = 0
                onUnlock()
            } else {
                failedAttempts += 1
            }
        }
    }
}
