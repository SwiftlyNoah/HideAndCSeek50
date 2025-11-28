//
//  DistanceOverlayItem.swift
//  HideAndCSeek50
//
//  Created by Ryan Eto on 11/28/25.
//

import Foundation
import MapKit
import CoreLocation

struct DistanceOverlayItem: Identifiable {
    let id: UUID
    let pointA: CLLocationCoordinate2D
    let pointB: CLLocationCoordinate2D
    let colorIndex: Int
    let distanceMeters: Double
    let polyline: MKPolyline
}
