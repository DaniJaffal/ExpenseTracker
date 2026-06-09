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
    /// Loosely grouped by theme so the grid reads coherently when scrolled.
    static let pickable: [String] = [
        // Money / payment
        "banknote.fill", "creditcard.fill", "building.columns.fill",
        "wallet.bifold.fill", "dollarsign.circle.fill", "centsign.circle.fill",
        "eurosign.circle.fill", "sterlingsign.circle.fill", "yensign.circle.fill",
        "bitcoinsign.circle.fill", "coloncurrencysign.circle.fill",
        "chart.line.uptrend.xyaxis", "chart.pie.fill", "chart.bar.fill",
        "arrow.left.arrow.right.circle.fill", "scalemass.fill",

        // Food & drink
        "cart.fill", "basket.fill", "fork.knife", "fork.knife.circle.fill",
        "takeoutbag.and.cup.and.straw.fill", "cup.and.saucer.fill",
        "mug.fill", "wineglass.fill", "waterbottle.fill",
        "carrot.fill", "birthday.cake.fill", "popcorn.fill",
        "frying.pan.fill", "oven.fill", "refrigerator.fill",

        // Transport & travel
        "car.fill", "car.2.fill", "bus.fill", "tram.fill", "bicycle",
        "scooter", "motorcycle.fill", "fuelpump.fill", "ev.charger.fill",
        "parkingsign.circle.fill", "road.lanes", "ferry.fill",
        "airplane", "airplane.departure", "tray.and.arrow.down.fill",
        "suitcase.fill", "suitcase.rolling.fill", "globe.americas.fill",
        "globe.europe.africa.fill", "mappin.circle.fill", "map.fill",
        "location.fill", "binoculars.fill",

        // Home & utilities
        "house.fill", "house.lodge.fill", "building.fill", "building.2.fill",
        "bed.double.fill", "sofa.fill", "lamp.table.fill", "lamp.floor.fill",
        "shower.fill", "bathtub.fill", "toilet.fill", "washer.fill",
        "dryer.fill", "dishwasher.fill", "stove.fill", "sink.fill",
        "lightbulb.fill", "bolt.fill", "drop.fill", "flame.fill",
        "thermometer.medium", "wrench.adjustable.fill", "hammer.fill",
        "screwdriver.fill", "paintbrush.fill", "paintpalette.fill",
        "key.fill", "lock.fill",

        // Tech & communication
        "tv.fill", "display", "desktopcomputer", "laptopcomputer",
        "ipad", "iphone", "applewatch", "airpods", "headphones",
        "speaker.wave.3.fill", "gamecontroller.fill", "antenna.radiowaves.left.and.right",
        "wifi", "network", "phone.fill", "envelope.fill",
        "message.fill", "bubble.left.and.bubble.right.fill",
        "camera.fill", "video.fill", "printer.fill", "externaldrive.fill",
        "icloud.fill",

        // Shopping & lifestyle
        "bag.fill", "bag.badge.plus", "handbag.fill", "shippingbox.fill",
        "tag.fill", "tags.fill", "gift.fill", "balloon.fill",
        "party.popper.fill", "tshirt.fill", "shoe.fill", "hanger",
        "comb.fill", "scissors", "eyeglasses", "watch.analog",
        "crown.fill", "sparkles",

        // Health & wellness
        "cross.case.fill", "cross.fill", "pills.fill", "syringe.fill",
        "stethoscope", "heart.fill", "heart.text.square.fill",
        "bandage.fill", "facemask.fill", "lungs.fill", "brain.head.profile",
        "figure.run", "figure.walk", "figure.strengthtraining.traditional",
        "figure.yoga", "figure.pool.swim", "figure.outdoor.cycle",
        "dumbbell.fill", "tennis.racket", "soccerball", "basketball.fill",
        "football.fill", "baseball.fill", "trophy.fill",

        // Education & work
        "book.fill", "books.vertical.fill", "bookmark.fill",
        "graduationcap.fill", "pencil", "highlighter", "paperclip",
        "doc.text.fill", "doc.on.doc.fill", "folder.fill", "tray.full.fill",
        "calendar", "calendar.badge.clock", "clock.fill", "alarm.fill",
        "briefcase.fill", "case.fill", "person.fill.badge.plus",
        "person.crop.rectangle.fill", "building.2.crop.circle.fill",

        // People & relationships
        "person.fill", "person.2.fill", "person.3.fill", "person.crop.circle.fill",
        "figure.and.child.holdinghands", "figure.2.and.child.holdinghands",
        "heart.circle.fill", "hands.sparkles.fill",

        // Pets, nature & weather
        "pawprint.fill", "dog.fill", "cat.fill", "bird.fill", "fish.fill",
        "leaf.fill", "tree.fill", "mountain.2.fill", "sun.max.fill",
        "moon.stars.fill", "cloud.rain.fill", "snowflake", "tornado",

        // Misc / catch-all
        "doc.plaintext.fill", "doc.richtext.fill", "newspaper.fill",
        "ticket.fill", "music.note", "music.mic", "film.fill",
        "theatermasks.fill", "paintbrush.pointed.fill", "puzzlepiece.fill",
        "die.face.5.fill", "guitars.fill", "camera.macro",
        "repeat.circle.fill", "arrow.triangle.2.circlepath",
        "checkmark.seal.fill", "exclamationmark.triangle.fill",
        "questionmark.circle.fill", "ellipsis.circle.fill",
        "star.fill", "flag.fill", "bell.fill", "shield.fill",
    ]
}
