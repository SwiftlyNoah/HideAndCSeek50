//
//  DistanceOverlayItem.swift
//  HideAndCSeek50
//
//  Created by Ryan Eto on 11/28/25.
//

import Foundation
import MapKit
import CoreLocation

struct DistanceOverlayItem: Identifiable, Codable {
    let id: UUID
    let pointA: CLLocationCoordinate2D
    let pointB: CLLocationCoordinate2D
    let colorIndex: Int
    let distanceMeters: Double
    let polyline: MKPolyline

    // Regular initializer for creating instances
    init(id: UUID, pointA: CLLocationCoordinate2D, pointB: CLLocationCoordinate2D, 
         colorIndex: Int, distanceMeters: Double, polyline: MKPolyline) {
        self.id = id
        self.pointA = pointA
        self.pointB = pointB
        self.colorIndex = colorIndex
        self.distanceMeters = distanceMeters
        self.polyline = polyline
    }

    // Codable conformance
    enum CodingKeys: String, CodingKey {
        case id, pointALat, pointALon, pointBLat, pointBLon, colorIndex, distanceMeters
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        let aLat = try container.decode(Double.self, forKey: .pointALat)
        let aLon = try container.decode(Double.self, forKey: .pointALon)
        pointA = CLLocationCoordinate2D(latitude: aLat, longitude: aLon)
        let bLat = try container.decode(Double.self, forKey: .pointBLat)
        let bLon = try container.decode(Double.self, forKey: .pointBLon)
        pointB = CLLocationCoordinate2D(latitude: bLat, longitude: bLon)
        colorIndex = try container.decode(Int.self, forKey: .colorIndex)
        distanceMeters = try container.decode(Double.self, forKey: .distanceMeters)

        // Recreate polyline from coordinates
        polyline = MKPolyline(coordinates: [pointA, pointB], count: 2)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(pointA.latitude, forKey: .pointALat)
        try container.encode(pointA.longitude, forKey: .pointALon)
        try container.encode(pointB.latitude, forKey: .pointBLat)
        try container.encode(pointB.longitude, forKey: .pointBLon)
        try container.encode(colorIndex, forKey: .colorIndex)
        try container.encode(distanceMeters, forKey: .distanceMeters)
    }
}
