//
//  MapToolsView.swift
//  HideAndCSeek50
//
//  Created by Jack Ploof on 11/24/25.
//

import Foundation
import MapKit
import SwiftUI

struct CircleOverlayItem: Identifiable, Equatable {
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
}
