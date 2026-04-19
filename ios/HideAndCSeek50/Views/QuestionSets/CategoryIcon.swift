//
//  CategoryIcon.swift
//  HideAndCSeek50
//
//  Curated SF Symbol list for the category icon picker. Keeping this
//  closed (no free-text entry) avoids broken-icon bugs from typos and
//  keeps the visual style consistent across user-authored sets.
//

import Foundation

enum CategoryIcon {
    static let all: [String] = [
        // Defaults — used by the seeded "Default" set
        "questionmark.circle.fill",
        "ruler.fill",
        "thermometer.medium",
        "dot.radiowaves.left.and.right",
        "figure.walk",
        "camera.fill",
        // Search / location / vision
        "magnifyingglass",
        "eye.fill",
        "binoculars.fill",
        "scope",
        "location.fill",
        "map.fill",
        "compass.drawing",
        "flag.fill",
        // Places
        "house.fill",
        "building.2.fill",
        "tree.fill",
        "leaf.fill",
        // People / motion
        "person.fill",
        "person.2.fill",
        "figure.run",
        // Transit
        "car.fill",
        "tram.fill",
        "bicycle",
        // Lifestyle / things
        "fork.knife",
        "cup.and.saucer.fill",
        "music.note",
        "book.fill",
        "paintbrush.fill",
        "graduationcap.fill",
        // Indicators / vibes
        "star.fill",
        "heart.fill",
        "bolt.fill",
        "flame.fill",
        "drop.fill",
        "snowflake",
        "sun.max.fill",
        "moon.fill",
        "clock.fill",
        "timer",
        "exclamationmark.triangle.fill"
    ]

    static let fallback: String = "questionmark.circle.fill"
}
