//
//  BisectorOverlayItem.swift
//  HideAndCSeek50
//
//  Created by Ryan Eto on 11/28/25.
//

import Foundation
import MapKit

struct BisectorOverlayItem: Identifiable, Equatable {
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
}
