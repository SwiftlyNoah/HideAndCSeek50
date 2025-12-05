//
//  BisectorOverlayItem.swift
//  HideAndCSeek50
//
//  Created by Ryan Eto on 11/28/25.
//

import Foundation
import MapKit

struct BisectorOverlayItem: Identifiable, Equatable, Codable {
    let id: UUID
    let pointA: CLLocationCoordinate2D
    let pointB: CLLocationCoordinate2D
    let fillPositiveSide: Bool
    let colorIndex: Int
    // Geometry snapshots
    let halfPlanePolygon: MKPolygon
    let bisectorPolyline: MKPolyline

    init(
        id: UUID = UUID(),
        pointA: CLLocationCoordinate2D,
        pointB: CLLocationCoordinate2D,
        fillPositiveSide: Bool,
        colorIndex: Int,
        halfPlanePolygon: MKPolygon,
        bisectorPolyline: MKPolyline
    ) {
        self.id = id
        self.pointA = pointA
        self.pointB = pointB
        self.fillPositiveSide = fillPositiveSide
        self.colorIndex = colorIndex
        self.halfPlanePolygon = halfPlanePolygon
        self.bisectorPolyline = bisectorPolyline
    }

    static func == (lhs: BisectorOverlayItem, rhs: BisectorOverlayItem) -> Bool {
        lhs.id == rhs.id
    }

    // Codable conformance
    enum CodingKeys: String, CodingKey {
        case id, pointALat, pointALon, pointBLat, pointBLon, fillPositiveSide, colorIndex
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
        fillPositiveSide = try container.decode(Bool.self, forKey: .fillPositiveSide)
        colorIndex = try container.decode(Int.self, forKey: .colorIndex)

        // Recreate geometry from coordinates
        let (polygon, polyline) = BisectorOverlayItem.createGeometry(pointA: pointA, pointB: pointB, fillPositiveSide: fillPositiveSide)
        halfPlanePolygon = polygon
        bisectorPolyline = polyline
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(pointA.latitude, forKey: .pointALat)
        try container.encode(pointA.longitude, forKey: .pointALon)
        try container.encode(pointB.latitude, forKey: .pointBLat)
        try container.encode(pointB.longitude, forKey: .pointBLon)
        try container.encode(fillPositiveSide, forKey: .fillPositiveSide)
        try container.encode(colorIndex, forKey: .colorIndex)
    }

    // Helper to recreate geometry
    static func createGeometry(pointA: CLLocationCoordinate2D, pointB: CLLocationCoordinate2D, fillPositiveSide: Bool) -> (MKPolygon, MKPolyline) {
        let midpoint = CLLocationCoordinate2D(
            latitude: (pointA.latitude + pointB.latitude) / 2,
            longitude: (pointA.longitude + pointB.longitude) / 2
        )

        let dx = pointB.longitude - pointA.longitude
        let dy = pointB.latitude - pointA.latitude

        let perpDx = -dy
        let perpDy = dx

        let extendFactor = 10.0
        let bisectorStart = CLLocationCoordinate2D(
            latitude: midpoint.latitude - perpDy * extendFactor,
            longitude: midpoint.longitude - perpDx * extendFactor
        )
        let bisectorEnd = CLLocationCoordinate2D(
            latitude: midpoint.latitude + perpDy * extendFactor,
            longitude: midpoint.longitude + perpDx * extendFactor
        )

        let bisectorPolyline = MKPolyline(coordinates: [bisectorStart, bisectorEnd], count: 2)

        let bounds = [pointA, pointB, bisectorStart, bisectorEnd]
        let minLat = bounds.map { $0.latitude }.min()! - 1.0
        let maxLat = bounds.map { $0.latitude }.max()! + 1.0
        let minLon = bounds.map { $0.longitude }.min()! - 1.0
        let maxLon = bounds.map { $0.longitude }.max()! + 1.0

        var halfPlaneCoords: [CLLocationCoordinate2D]
        if fillPositiveSide {
            halfPlaneCoords = [
                bisectorStart,
                bisectorEnd,
                CLLocationCoordinate2D(latitude: maxLat, longitude: maxLon),
                CLLocationCoordinate2D(latitude: maxLat, longitude: minLon)
            ]
        } else {
            halfPlaneCoords = [
                bisectorStart,
                bisectorEnd,
                CLLocationCoordinate2D(latitude: minLat, longitude: maxLon),
                CLLocationCoordinate2D(latitude: minLat, longitude: minLon)
            ]
        }

        let halfPlanePolygon = MKPolygon(coordinates: halfPlaneCoords, count: halfPlaneCoords.count)

        return (halfPlanePolygon, bisectorPolyline)
    }
}
