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
    let shadeOutside: Bool
    let polygon: MKPolygon
    
    init(
        id: UUID = UUID(),
        vertices: [CLLocationCoordinate2D],
        colorIndex: Int,
        shadeOutside: Bool = false,
        polygon: MKPolygon
    ) {
        self.id = id
        self.vertices = vertices
        self.colorIndex = colorIndex
        self.shadeOutside = shadeOutside
        self.polygon = polygon
    }
    
    static func == (lhs: PolygonOverlayItem, rhs: PolygonOverlayItem) -> Bool {
        lhs.id == rhs.id
    }
}
