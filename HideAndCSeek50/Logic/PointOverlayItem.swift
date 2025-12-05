//
//  PointOverlayItem.swift
//  HideAndCSeek50
//
//  Created on 12/5/25.
//

import Foundation
import MapKit

struct PointOverlayItem: Identifiable, Equatable, Codable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    let colorIndex: Int
    let symbolIndex: Int // Index into an array of SF Symbol names
    
    init(
        id: UUID = UUID(),
        coordinate: CLLocationCoordinate2D,
        colorIndex: Int,
        symbolIndex: Int
    ) {
        self.id = id
        self.coordinate = coordinate
        self.colorIndex = colorIndex
        self.symbolIndex = symbolIndex
    }
    
    static func == (lhs: PointOverlayItem, rhs: PointOverlayItem) -> Bool {
        return lhs.id == rhs.id
            && lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
            && lhs.colorIndex == rhs.colorIndex
            && lhs.symbolIndex == rhs.symbolIndex
    }
    
    // Codable conformance
    enum CodingKeys: String, CodingKey {
        case id, latitude, longitude, colorIndex, symbolIndex
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        let lat = try container.decode(Double.self, forKey: .latitude)
        let lon = try container.decode(Double.self, forKey: .longitude)
        coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        colorIndex = try container.decode(Int.self, forKey: .colorIndex)
        symbolIndex = try container.decode(Int.self, forKey: .symbolIndex)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
        try container.encode(colorIndex, forKey: .colorIndex)
        try container.encode(symbolIndex, forKey: .symbolIndex)
    }
}

// Annotation class for displaying points on the map
class PointAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let id: UUID
    let colorIndex: Int
    let symbolIndex: Int
    
    init(item: PointOverlayItem) {
        self.coordinate = item.coordinate
        self.id = item.id
        self.colorIndex = item.colorIndex
        self.symbolIndex = item.symbolIndex
        super.init()
    }
}
