//
//  TagChip.swift
//  ExpenseTracker
//
//  Tag rendering. Two variants: a small read-only pill (for rows) and a
//  larger selectable chip (for editors and pickers).
//

import SwiftUI

/// Small read-only tag pill shown on rows.
struct TagPill: View {
    let name: String
    let colorHex: String

    var body: some View {
        let color = Color(hex: colorHex)
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(name)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(color.opacity(0.14))
        .foregroundStyle(color)
        .clipShape(Capsule())
    }
}

/// Editable chip with an optional trailing remove (×) button.
struct TagChip: View {
    let name: String
    let colorHex: String
    var isSelected: Bool = true
    var showRemove: Bool = false
    var onRemove: (() -> Void)? = nil

    var body: some View {
        let color = Color(hex: colorHex)
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(name)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
            if showRemove {
                Button {
                    onRemove?()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(color.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isSelected ? color.opacity(0.16) : Color.secondary.opacity(0.10))
        .foregroundStyle(isSelected ? color : .primary)
        .overlay(
            Capsule()
                .strokeBorder(
                    isSelected ? color.opacity(0.5) : Color.secondary.opacity(0.2),
                    lineWidth: 1
                )
        )
        .clipShape(Capsule())
    }
}
