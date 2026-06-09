//
//  DeleteConfirmPopover.swift
//  ExpenseTracker
//
//  Small destructive-confirmation popover meant to anchor directly to a
//  "Delete X" button so the confirmation appears right next to the action,
//  not as a screen-wide action sheet.
//
//  Used with `.popover(isPresented:)` + `.presentationCompactAdaptation(.popover)`
//  so the popover form is preserved even on iPhone.
//

import SwiftUI

struct DeleteConfirmPopover: View {
    let title: String
    var message: String? = nil
    let onDelete: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            if let message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Button(role: .cancel, action: onCancel) {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button(role: .destructive, action: onDelete) {
                    Text("Delete")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
        .padding(16)
        .frame(minWidth: 260)
    }
}
