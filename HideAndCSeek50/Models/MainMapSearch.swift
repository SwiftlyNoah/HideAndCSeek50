//
//  SearchTest.swift
//  HideAndCSeek50
//
//  Created by Ryan Eto on 11/25/25.
//

import Foundation
import MapKit
internal import Combine

@MainActor
class MapSearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var results: [MKMapItem] = []
    @Published var isSearching = false
    @Published var errorMessage: String?
    @Published var selectedItem: MKMapItem?
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 42.3601, longitude: -71.0589),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )

    func search() {
        guard !query.isEmpty else { 
            errorMessage = "Please enter a search query"
            return 
        }

        isSearching = true
        errorMessage = nil

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query

        // Optionally restrict to visible region
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

                    // zoom to first result
                    if let first = items.first?.placemark.location?.coordinate {
                        self.region.center = first
                        self.region.span = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                    }
                }
            }
        }
    }
    
    func clearSearch() {
        query = ""
        results = []
        errorMessage = nil
        selectedItem = nil
    }
    
    func selectItem(_ item: MKMapItem) {
        selectedItem = item
        if let coord = item.placemark.location?.coordinate {
            region.center = coord
            region.span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        }
    }
}
