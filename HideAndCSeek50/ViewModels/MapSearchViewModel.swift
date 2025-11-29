//
//  MapSearchViewModel.swift
//  HideAndCSeek50
//
//  Created by Ryan Eto on 11/25/25.
//

import Foundation
import MapKit
internal import Combine
import BottomSheet

@MainActor
class MapSearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var results: [MKMapItem] = []
    @Published var hasSearched = false
    @Published var isSearching = false
    @Published var errorMessage: String?
    @Published var selectedLandmark: MKMapItem?
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 42.3601, longitude: -71.0589),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    
    @Published var searchResultsBottomSheetPosition: BottomSheetPosition = .hidden
    @Published var transportSelectionBottomSheetPosition: BottomSheetPosition = .hidden
    @Published var directionsBottomSheetPosition: BottomSheetPosition = .hidden
    @Published var selectedDestination: MKMapItem?
    @Published var selectedTransportType: TransportType = .automobile
    @Published var contextItemForMapTools: MKMapItem? // Track item for map tools context
    
    // Directions Var's
    @Published var route: MKRoute?
    @Published var directionsError: String?
    @Published var isCalculatingDirections = false

    enum DepartureType {
        case leaveNow
        case leaveAt(Date)
        case arriveBy(Date)
    }

    func getDirections(
        to destination: MKMapItem,
        transportType: MKDirectionsTransportType,
        departureType: DepartureType
    ) {
        isCalculatingDirections = true
        directionsError = nil

        let request = MKDirections.Request()

        // Prefer user location; fallback to current map center
        if let userLoc = LocationManager.shared.location?.coordinate,
           [.authorizedAlways, .authorizedWhenInUse].contains(LocationManager.shared.authorizationStatus) {
            if #available(iOS 26.0, *) {
                request.source = MKMapItem(location: CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude), address: nil)
            } else {
                request.source = MKMapItem(placemark: MKPlacemark(coordinate: userLoc))
            }
        } else {
            if #available(iOS 26.0, *) {
                request.source = MKMapItem(location: CLLocation(latitude: region.center.latitude, longitude: region.center.longitude), address: nil)
            } else {
                request.source = MKMapItem(placemark: MKPlacemark(coordinate: region.center))
            }
        }

        request.destination = destination
        request.transportType = transportType
        request.requestsAlternateRoutes = true

        switch departureType {
        case .leaveNow:
            if transportType == .transit { request.departureDate = Date() }
        case .leaveAt(let date):
            request.departureDate = date
        case .arriveBy(let date):
            request.arrivalDate = date
        }

        let directions = MKDirections(request: request)
        directions.calculate { [weak self] response, error in
            guard let self = self else { return }
            Task { @MainActor in
                self.isCalculatingDirections = false
                if let error = error {
                    let nsError = error as NSError
                    if nsError.domain == MKError.errorDomain,
                       let code = MKError.Code(rawValue: UInt(exactly: nsError.code) ?? 0) {
                        switch code {
                        case .directionsNotFound:
                            self.directionsError = "No routes available. Transit may not operate here or at this time."
                        case .placemarkNotFound:
                            self.directionsError = "Destination location not found."
                        default:
                            self.directionsError = "Directions unavailable: \(error.localizedDescription)"
                        }
                    } else {
                        self.directionsError = "Directions failed: \(error.localizedDescription)"
                    }
                    self.route = nil
                    return
                }

                guard let route = response?.routes.first else {
                    self.directionsError = "No routes found."
                    self.route = nil
                    return
                }

                self.route = route
                self.directionsError = nil

                // Clear search results now that directions are chosen
                self.results.removeAll()
            }
        }
    }
    
    func search() {
        guard !query.isEmpty else {
            errorMessage = "Please enter a search query"
            return
        }

        isSearching = true
        errorMessage = nil

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query

        // Focus search on the currently visible map window
        request.region = region

        let search = MKLocalSearch(request: request)
        search.start { [weak self] response, error in
            guard let self = self else { return }
            Task { @MainActor in
                self.isSearching = false

                if let error = error {
                    self.errorMessage = "Search failed: \(error.localizedDescription)"
                    self.results = []
                    return
                }

                if let items = response?.mapItems {
                    self.results = items
                    if items.isEmpty {
                        self.errorMessage = "No results found"
                    }
                }
                
                self.hasSearched = true
            }
        }
    }
    
    func clearSearch() {
        searchResultsBottomSheetPosition = .hidden
        transportSelectionBottomSheetPosition = .hidden
        directionsBottomSheetPosition = .hidden
        selectedDestination = nil
        contextItemForMapTools = nil
        hasSearched = false
        query = ""
        results = []
        errorMessage = nil
        selectedLandmark = nil
        // Clear any rendered directions
        route = nil
        directionsError = nil
        isCalculatingDirections = false
    }
    
    func selectItem(_ item: MKMapItem) {
        selectedLandmark = item
        region.center = item.location.coordinate
        region.span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    }
    
    // MARK: - Bottom Sheet Management
    
    func showSearchResults() {
        searchResultsBottomSheetPosition = .relative(0.5)
    }
    
    func showTransportSelection(for destination: MKMapItem) {
        selectedDestination = destination
        searchResultsBottomSheetPosition = .hidden
        transportSelectionBottomSheetPosition = .dynamic
    }
    
    func openMapToolsForItem(_ item: MKMapItem) {
        // Clear all search results except the selected item, close all sheets
        searchResultsBottomSheetPosition = .hidden
        transportSelectionBottomSheetPosition = .hidden
        directionsBottomSheetPosition = .hidden
        selectedDestination = nil
        contextItemForMapTools = nil
        hasSearched = false
        query = ""
        results = []
        errorMessage = nil
        route = nil
        directionsError = nil
        isCalculatingDirections = false
        
        results = [item]
        selectedLandmark = item
        contextItemForMapTools = item
    }
    
    func showDirections() {
        transportSelectionBottomSheetPosition = .hidden
        directionsBottomSheetPosition = .relative(0.5)
    }
    
    func hideAllBottomSheets() {
        searchResultsBottomSheetPosition = .hidden
        transportSelectionBottomSheetPosition = .hidden
        directionsBottomSheetPosition = .hidden
    }
    
    func selectTransportAndShowDirections(_ transportType: TransportType) {
        selectedTransportType = transportType
        
        if let destination = selectedDestination {
            getDirections(
                to: destination,
                transportType: transportType.mkDirectionsType,
                departureType: .leaveNow
            )
            showDirections()
        }
    }
}
