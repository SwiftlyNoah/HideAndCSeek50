//
//  PolygonOverlayItem.swift
//  HideAndCSeek50
//
//  Created by Assistant on 12/2/25.
//

import Foundation
import MapKit

struct PolygonOverlayItem: Identifiable, Equatable {
    let id: UUID
    let vertices: [CLLocationCoordinate2D]
    let colorIndex: Int
    let polygon: MKPolygon
    
    init(
        id: UUID = UUID(),
        vertices: [CLLocationCoordinate2D],
        colorIndex: Int,
        polygon: MKPolygon
    ) {
        self.id = id
        self.vertices = vertices
        self.colorIndex = colorIndex
        self.polygon = polygon
    }
    
    static func == (lhs: PolygonOverlayItem, rhs: PolygonOverlayItem) -> Bool {
        lhs.id == rhs.id
    }
}
