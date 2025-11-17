//
//  CityRegions.swift
//  HideAndCSeek50
//
//  Created by Assistant on 11/17/25.
//

import Foundation
import MapKit
import CoreLocation

struct BostonRegions {
    static let hidableAreas: [MKPolygon] = [
        // Boston Common and Public Garden
        createPolygon(coordinates: [
            CLLocationCoordinate2D(latitude: 42.3541, longitude: -71.0662),
            CLLocationCoordinate2D(latitude: 42.3541, longitude: -71.0628),
            CLLocationCoordinate2D(latitude: 42.3581, longitude: -71.0628),
            CLLocationCoordinate2D(latitude: 42.3581, longitude: -71.0662)
        ]),
        
        // Harvard Yard area
        createPolygon(coordinates: [
            CLLocationCoordinate2D(latitude: 42.3744, longitude: -71.1169),
            CLLocationCoordinate2D(latitude: 42.3744, longitude: -71.1140),
            CLLocationCoordinate2D(latitude: 42.3770, longitude: -71.1140),
            CLLocationCoordinate2D(latitude: 42.3770, longitude: -71.1169)
        ]),
        
        // Faneuil Hall/Quincy Market area
        createPolygon(coordinates: [
            CLLocationCoordinate2D(latitude: 42.3598, longitude: -71.0572),
            CLLocationCoordinate2D(latitude: 42.3598, longitude: -71.0542),
            CLLocationCoordinate2D(latitude: 42.3608, longitude: -71.0542),
            CLLocationCoordinate2D(latitude: 42.3608, longitude: -71.0572)
        ]),
        
        // Copley Square
        createPolygon(coordinates: [
            CLLocationCoordinate2D(latitude: 42.3496, longitude: -71.0782),
            CLLocationCoordinate2D(latitude: 42.3496, longitude: -71.0752),
            CLLocationCoordinate2D(latitude: 42.3506, longitude: -71.0752),
            CLLocationCoordinate2D(latitude: 42.3506, longitude: -71.0782)
        ]),
        
        // MIT Campus
        createPolygon(coordinates: [
            CLLocationCoordinate2D(latitude: 42.3590, longitude: -71.0935),
            CLLocationCoordinate2D(latitude: 42.3590, longitude: -71.0885),
            CLLocationCoordinate2D(latitude: 42.3620, longitude: -71.0885),
            CLLocationCoordinate2D(latitude: 42.3620, longitude: -71.0935)
        ])
    ]
}

struct NewYorkRegions {
    static let hidableAreas: [MKPolygon] = [
        // Central Park
        createPolygon(coordinates: [
            CLLocationCoordinate2D(latitude: 40.7648, longitude: -73.9808),
            CLLocationCoordinate2D(latitude: 40.7648, longitude: -73.9588),
            CLLocationCoordinate2D(latitude: 40.8006, longitude: -73.9588),
            CLLocationCoordinate2D(latitude: 40.8006, longitude: -73.9808)
        ]),
        
        // Washington Square Park
        createPolygon(coordinates: [
            CLLocationCoordinate2D(latitude: 40.7308, longitude: -73.9973),
            CLLocationCoordinate2D(latitude: 40.7308, longitude: -73.9953),
            CLLocationCoordinate2D(latitude: 40.7318, longitude: -73.9953),
            CLLocationCoordinate2D(latitude: 40.7318, longitude: -73.9973)
        ]),
        
        // Bryant Park
        createPolygon(coordinates: [
            CLLocationCoordinate2D(latitude: 40.7536, longitude: -73.9832),
            CLLocationCoordinate2D(latitude: 40.7536, longitude: -73.9822),
            CLLocationCoordinate2D(latitude: 40.7546, longitude: -73.9822),
            CLLocationCoordinate2D(latitude: 40.7546, longitude: -73.9832)
        ]),
        
        // Times Square area
        createPolygon(coordinates: [
            CLLocationCoordinate2D(latitude: 40.7580, longitude: -73.9862),
            CLLocationCoordinate2D(latitude: 40.7580, longitude: -73.9842),
            CLLocationCoordinate2D(latitude: 40.7590, longitude: -73.9842),
            CLLocationCoordinate2D(latitude: 40.7590, longitude: -73.9862)
        ]),
        
        // Brooklyn Bridge Park
        createPolygon(coordinates: [
            CLLocationCoordinate2D(latitude: 40.7022, longitude: -73.9978),
            CLLocationCoordinate2D(latitude: 40.7022, longitude: -73.9958),
            CLLocationCoordinate2D(latitude: 40.7042, longitude: -73.9958),
            CLLocationCoordinate2D(latitude: 40.7042, longitude: -73.9978)
        ]),
        
        // High Line
        createPolygon(coordinates: [
            CLLocationCoordinate2D(latitude: 40.7480, longitude: -74.0048),
            CLLocationCoordinate2D(latitude: 40.7480, longitude: -74.0028),
            CLLocationCoordinate2D(latitude: 40.7520, longitude: -74.0028),
            CLLocationCoordinate2D(latitude: 40.7520, longitude: -74.0048)
        ])
    ]
}

private func createPolygon(coordinates: [CLLocationCoordinate2D]) -> MKPolygon {
    return MKPolygon(coordinates: coordinates, count: coordinates.count)
}