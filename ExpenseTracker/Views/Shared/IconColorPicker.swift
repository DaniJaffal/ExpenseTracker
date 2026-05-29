//
//  IconColorPicker.swift
//  ExpenseTracker
//
//  Reusable SF Symbol + color picker for accounts and custom categories.
//

import SwiftUI

struct IconColorPicker: View {
    @Binding var iconName: String
    @Binding var colorHex: String

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 6)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Color")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Palette.pickable, id: \.self) { hex in
                    Button {
                        colorHex = hex
                    } label: {
                        ZStack {
                            Circle().fill(Color(hex: hex))
                            if colorHex.lowercased() == hex.lowercased() {
                                Circle()
                                    .strokeBorder(Color.primary, lineWidth: 2)
                                    .padding(2)
                            }
                        }
                        .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("Icon")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Symbols.pickable, id: \.self) { symbol in
                    Button {
                        iconName = symbol
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(iconName == symbol ? Color(hex: colorHex).opacity(0.25) : Color.secondary.opacity(0.10))
                            Image(systemName: symbol)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(iconName == symbol ? Color(hex: colorHex) : .primary)
                        }
                        .frame(height: 38)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
