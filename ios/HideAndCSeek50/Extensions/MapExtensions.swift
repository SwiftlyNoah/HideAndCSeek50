//
//  MapExtensions.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 11/28/25.
//

import MapKit

extension MKMapItem {
    var address: String? {
        // For iOS 26.0+, use MKMapItem's addressRepresentations
        if #available(iOS 26.0, *) {
            return addressRepresentations?.fullAddress(includingRegion: false, singleLine: true)
        } else {
            // Fallback for older iOS versions using deprecated MKPlacemark
            var components: [String] = []
            
            if let street = placemark.thoroughfare {
                components.append(street)
            }
            if let city = placemark.locality {
                components.append(city)
            }
            if let state = placemark.administrativeArea {
                components.append(state)
            }
            
            return components.isEmpty ? nil : components.joined(separator: ", ")
        }
    }
}

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
