//
//  PolygonVertexAnnotation.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 12/7/25.
//

import MapKit

final class PolygonVertexAnnotation: NSObject, MKAnnotation {
    let vertexIndex: Int
    dynamic var coordinate: CLLocationCoordinate2D
    var title: String? { "Vertex \(vertexIndex + 1)" }
    init(vertexIndex: Int, coordinate: CLLocationCoordinate2D) {
        self.vertexIndex = vertexIndex
        self.coordinate = coordinate
        super.init()
    }
}
