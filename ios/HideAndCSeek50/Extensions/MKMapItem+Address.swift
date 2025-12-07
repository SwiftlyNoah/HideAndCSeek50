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
