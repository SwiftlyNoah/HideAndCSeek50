//
//  TransportType.swift
//  HideAndCSeek50
//
//  Created by Assistant on 11/27/25.
//

import Foundation
import MapKit

// Transport Type Enum with descriptions
enum TransportType: String, CaseIterable, Identifiable {
    case automobile
    case walking
    case transit
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .automobile: return "Driving"
        case .walking: return "Walking"
        case .transit: return "Transit"
        }
    }
    
    var iconName: String {
        switch self {
        case .automobile: return "car.fill"
        case .walking: return "figure.walk"
        case .transit: return "tram.fill"
        }
    }
    
    var description: String {
        switch self {
        case .automobile: return "Fastest route by car"
        case .walking: return "Walking directions"
        case .transit: return "Public transportation"
        }
    }
    
    var mkDirectionsType: MKDirectionsTransportType {
        switch self {
        case .automobile: return .automobile
        case .walking: return .walking
        case .transit: return .transit
        }
    }
}