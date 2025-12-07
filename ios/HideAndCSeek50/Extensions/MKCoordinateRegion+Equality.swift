//
//  MKCoordinateRegion+Equality.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 12/7/25.
//

import MapKit

// Extension to compare regions
extension MKCoordinateRegion {
    func isApproximatelyEqual(to other: MKCoordinateRegion, threshold: Double = 0.001) -> Bool {
        abs(center.latitude - other.center.latitude) < threshold &&
        abs(center.longitude - other.center.longitude) < threshold &&
        abs(span.latitudeDelta - other.span.latitudeDelta) < threshold &&
        abs(span.longitudeDelta - other.span.longitudeDelta) < threshold
    }
}

extension MKCoordinateRegion: @retroactive Equatable {
    public static func == (lhs: MKCoordinateRegion, rhs: MKCoordinateRegion) -> Bool {
        lhs.center.latitude == rhs.center.latitude &&
        lhs.center.longitude == rhs.center.longitude &&
        lhs.span.latitudeDelta == rhs.span.latitudeDelta &&
        lhs.span.longitudeDelta == rhs.span.longitudeDelta
    }
}
