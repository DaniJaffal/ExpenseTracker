//
//  Theme.swift
//  ExpenseTracker
//
//  Color & style helpers.
//

import SwiftUI

extension Color {
    /// Initialize from "#RRGGBB" or "#RRGGBBAA".
    init(hex: String) {
        var hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }

        var rgba: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgba)

        let r, g, b, a: Double
        switch hex.count {
        case 6:
            r = Double((rgba & 0xFF0000) >> 16) / 255.0
            g = Double((rgba & 0x00FF00) >> 8) / 255.0
            b = Double(rgba & 0x0000FF) / 255.0
            a = 1.0
        case 8:
            r = Double((rgba & 0xFF000000) >> 24) / 255.0
            g = Double((rgba & 0x00FF0000) >> 16) / 255.0
            b = Double((rgba & 0x0000FF00) >> 8) / 255.0
            a = Double(rgba & 0x000000FF) / 255.0
        default:
            r = 0; g = 0; b = 0; a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

enum Palette {
    /// Curated picker palette for accounts and custom categories.
    static let pickable: [String] = [
        "#FF3B30", "#FF6B6B", "#FF9500", "#FF8C42", "#FFCC00",
        "#34C759", "#30D158", "#5AC8FA", "#0A84FF", "#4F8EF7",
        "#5856D6", "#AF52DE", "#FF2D55", "#A2845E", "#8E8E93",
    ]
}

enum Symbols {
    /// Curated SF Symbol picker set for accounts and custom categories.
    static let pickable: [String] = [
        "banknote.fill", "creditcard.fill", "building.columns.fill",
        "wallet.bifold.fill", "dollarsign.circle.fill", "centsign.circle.fill",
        "cart.fill", "fork.knife", "car.fill", "tram.fill", "fuelpump.fill",
        "house.fill", "bed.double.fill", "tv.fill", "gamecontroller.fill",
        "bag.fill", "gift.fill", "tshirt.fill", "scissors",
        "cross.case.fill", "pills.fill", "stethoscope",
        "book.fill", "graduationcap.fill", "pencil",
        "airplane", "globe.americas.fill", "mappin.circle.fill",
        "phone.fill", "wifi", "bolt.fill", "drop.fill",
        "pawprint.fill", "leaf.fill", "sparkles",
        "doc.text.fill", "repeat.circle.fill", "calendar.badge.clock",
        "ellipsis.circle.fill", "tag.fill", "star.fill", "heart.fill",
    ]
}
