//
//  MapToolsView.swift
//  HideAndCSeek50
//
//  Created by Jack Ploof on 11/24/25.
//

import Foundation
import MapKit

struct CircleOverlayItem: Identifiable, Equatable {
    let id: UUID
    let center: CLLocationCoordinate2D
    let radiusMeters: CLLocationDistance
    let isRed: Bool

    init(id: UUID = UUID(), center: CLLocationCoordinate2D, radiusMeters: CLLocationDistance, isRed: Bool) {
        self.id = id
        self.center = center
        self.radiusMeters = radiusMeters
        self.isRed = isRed
    }

    static func == (lhs: CircleOverlayItem, rhs: CircleOverlayItem) -> Bool {
        return lhs.id == rhs.id
            && lhs.center.latitude == rhs.center.latitude
            && lhs.center.longitude == rhs.center.longitude
            && lhs.radiusMeters == rhs.radiusMeters
            && lhs.isRed == rhs.isRed
    }
}
