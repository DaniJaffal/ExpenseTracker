//
//  PrivacyBlurView.swift
//  ExpenseTracker
//
//  Briefly shown when the app is transitioning to inactive/background, so
//  financial data doesn't appear in the App Switcher snapshot. Matches the
//  lock screen visually but without the unlock affordance.
//

import SwiftUI

struct PrivacyBlurView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#4F8EF7"), Color(hex: "#5856D6")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Text("ET")
                .font(.system(size: 88, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(.white.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }
}
