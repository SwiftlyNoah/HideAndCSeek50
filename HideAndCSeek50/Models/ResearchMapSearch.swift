//
//  ResearchMapSearch.swift
//  HideAndCSeek50
//
//  Created by Ryan Eto on 11/25/25.
//

import Foundation
import MapKit
internal import Combine
import CoreLocation


@MainActor
class ResearchMapSearchViewModel: ObservableObject {
    private let locationManager = LocationManager.shared
    @Published var query: String = ""
    @Published var searchResults: [MKMapItem] = []
    @Published var selectedResult: MKMapItem?
    @Published var route: MKRoute?
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 42.3601, longitude: -71.0589),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    @Published var directionsError: String?
    @Published var isCalculatingDirections = false
    
    func search() {
        guard !query.isEmpty else { return }
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = region
        
        let search = MKLocalSearch(request: request)
        
        search.start { [weak self] response, error in
            guard let self = self,
                  let items = response?.mapItems,
                  error == nil else {
                print("Search error: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            Task { @MainActor in
                self.searchResults = items
            }
        }
    }
    
    func getDirections(
        to destination: MKMapItem,
        transportType: MKDirectionsTransportType,
        departureType: DepartureType
    ) {
        isCalculatingDirections = true
        directionsError = nil
        
        let request = MKDirections.Request()
        // Prefer a precise on-device location; fall back to map center
        let sourceItem: MKMapItem
        let auth = locationManager.authorizationStatus
        if (auth == .authorizedWhenInUse || auth == .authorizedAlways),
           let loc = locationManager.location?.coordinate {
            sourceItem = MKMapItem(placemark: MKPlacemark(coordinate: loc))
        } else {
            // Best-effort fallback to the visible region center
            sourceItem = MKMapItem(placemark: MKPlacemark(coordinate: region.center))
        }
        request.source = sourceItem
        request.destination = destination
        request.transportType = transportType
        
        // Request alternate routes for better options
        request.requestsAlternateRoutes = true
        
        switch departureType {
        case .leaveNow:
            // For transit, set departure date to now explicitly
            if transportType == .transit {
                request.departureDate = Date()
            }
        case .leaveAt(let date):
            request.departureDate = date
        case .arriveBy(let date):
            request.arrivalDate = date
        }
        
        print("🚗 Requesting directions:")
        print("  - Transport: \(transportType == .transit ? "Transit" : transportType == .walking ? "Walking" : "Driving")")
        if let srcCoord = request.source?.placemark.location?.coordinate {
            print("  - From: (lat: \(srcCoord.latitude), lon: \(srcCoord.longitude))")
        } else {
            print("  - From: (unknown)")
        }
        print("  - To: \(destination.name ?? "Unknown")")
        if let departure = request.departureDate {
            print("  - Departure: \(departure)")
        }
        if let arrival = request.arrivalDate {
            print("  - Arrival: \(arrival)")
        }
        
        let directions = MKDirections(request: request)
        directions.calculate { [weak self] response, error in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.isCalculatingDirections = false
                
                if let error = error {
                    // Detailed error logging
                    let nsError = error as NSError
                    print("❌ Directions error:")
                    print("  - Domain: \(nsError.domain)")
                    print("  - Code: \(nsError.code)")
                    print("  - Description: \(error.localizedDescription)")
                    print("  - UserInfo: \(nsError.userInfo)")
                    
                    // Check for specific transit errors
                    if nsError.domain == MKError.errorDomain {
                        let errorCode = MKError.Code(rawValue: UInt(exactly: nsError.code) ?? 0)
                        switch errorCode {
                        case .directionsNotFound:
                            self.directionsError = "No \(transportType == .transit ? "transit" : "driving") routes available for this destination. Transit may not be available in this area or at this time."
                        case .placemarkNotFound:
                            self.directionsError = "Unable to find directions to this location."
                        case .loadingThrottled:
                            self.directionsError = "Too many requests. Please wait a moment and try again."
                        case .serverFailure:
                            self.directionsError = "Apple Maps server error. Please try again later."
                        default:
                            self.directionsError = "Directions unavailable (Error \(nsError.code)): \(error.localizedDescription)"
                        }
                    } else {
                        self.directionsError = "Failed to calculate directions: \(error.localizedDescription)"
                    }
                    self.route = nil
                    return
                }
                
                guard let routes = response?.routes, !routes.isEmpty else {
                    print("⚠️ No routes found in response")
                    self.directionsError = "No routes found. \(transportType == .transit ? "Transit may not be available for this destination." : "Please try a different location.")"
                    self.route = nil
                    return
                }
                
                let route = routes[0]
                print("✅ Found \(routes.count) route(s)")
                print("  - Travel time: \(Int(route.expectedTravelTime / 60)) minutes")
                print("  - Distance: \(String(format: "%.1f", route.distance / 1609.34)) miles")
                print("  - Steps: \(route.steps.count)")
                
                self.route = route
                self.directionsError = nil
            }
        }
    }
    
    enum DepartureType {
        case leaveNow
        case leaveAt(Date)
        case arriveBy(Date)
    }
}
