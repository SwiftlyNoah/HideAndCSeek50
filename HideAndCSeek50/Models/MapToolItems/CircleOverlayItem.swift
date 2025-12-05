//
//  MapToolsView.swift
//  HideAndCSeek50
//
//  Created by Jack Ploof on 11/24/25.
//

import Foundation
import MapKit
import SwiftUI

struct CircleOverlayItem: Identifiable, Equatable, Codable {
    let id: UUID
    let center: CLLocationCoordinate2D
    let radiusMeters: CLLocationDistance
    let colorIndex: Int
    let shadeOutside: Bool

    init(id: UUID = UUID(), center: CLLocationCoordinate2D, radiusMeters: CLLocationDistance, colorIndex: Int = 2, shadeOutside: Bool = false) { // Default to yellow
        self.id = id
        self.center = center
        self.radiusMeters = radiusMeters
        self.colorIndex = colorIndex
        self.shadeOutside = shadeOutside
    }

    static func == (lhs: CircleOverlayItem, rhs: CircleOverlayItem) -> Bool {
        return lhs.id == rhs.id
            && lhs.center.latitude == rhs.center.latitude
            && lhs.center.longitude == rhs.center.longitude
            && lhs.radiusMeters == rhs.radiusMeters
            && lhs.colorIndex == rhs.colorIndex
    }

    // Codable conformance
    enum CodingKeys: String, CodingKey {
        case id, centerLat, centerLon, radiusMeters, colorIndex, shadeOutside
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        let lat = try container.decode(Double.self, forKey: .centerLat)
        let lon = try container.decode(Double.self, forKey: .centerLon)
        center = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        radiusMeters = try container.decode(Double.self, forKey: .radiusMeters)
        colorIndex = try container.decode(Int.self, forKey: .colorIndex)
        shadeOutside = try container.decode(Bool.self, forKey: .shadeOutside)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(center.latitude, forKey: .centerLat)
        try container.encode(center.longitude, forKey: .centerLon)
        try container.encode(radiusMeters, forKey: .radiusMeters)
        try container.encode(colorIndex, forKey: .colorIndex)
        try container.encode(shadeOutside, forKey: .shadeOutside)
    }
}
