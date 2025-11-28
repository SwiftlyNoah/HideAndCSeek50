//
//  GameMapView.swift
//  HideAndCSeek50
//
//  Created by Assistant on 11/17/25.
//

import SwiftUI
import MapKit
import CoreLocation

class PlayerAnnotation: NSObject, MKAnnotation {
    let displayName: String
    let coordinate: CLLocationCoordinate2D
    let team: Team
    
    var title: String? {
        return displayName
    }
    
    var subtitle: String? {
        return team.displayName
    }
    
    init(displayName: String, coordinate: CLLocationCoordinate2D, team: Team) {
        self.displayName = displayName
        self.coordinate = coordinate
        self.team = team
        super.init()
    }
}

struct GameMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    let game: Game?
    let currentUserUID: String
    let currentUserTeam: Team
    let hidableRegions: [MKPolygon]
    var searchResults: [MKMapItem] = []
    var selectedLandmark: MKMapItem?
    var route: MKRoute?
    var onSearchAnnotationSelected: ((MKMapItem) -> Void)?
    
    private var visiblePlayerLocations: [(String, CLLocation, Team, String)] {
        guard let game = game else { return [] }
        
        var visiblePlayers: [(String, CLLocation, Team, String)] = []
        
        // Get all players with their teams and names
        for (uid, player) in game.teams.hiders {
            if uid != currentUserUID, // Don't show current user
               let location = player.location {
                let clLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
                visiblePlayers.append((uid, clLocation, .hiders, player.displayName))
            }
        }
        
        for (uid, player) in game.teams.seekers {
            if uid != currentUserUID, // Don't show current user
               let location = player.location {
                let clLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
                visiblePlayers.append((uid, clLocation, .seekers, player.displayName))
            }
        }
        
        // Apply visibility rules: seekers can't see hiders
        if currentUserTeam == .seekers {
            visiblePlayers = visiblePlayers.filter { $0.2 == .seekers }
        }
        
        return visiblePlayers
    }
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none
        mapView.mapType = .standard
        
        // Add hidable regions as overlays
        mapView.addOverlays(hidableRegions)
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // If the user is interacting, don't force-set the region
        if !context.coordinator.userIsInteracting {
            if !mapView.region.isApproximatelyEqual(to: region) {
                mapView.setRegion(region, animated: true)
            }
        }

        // Update player annotations
        updatePlayerAnnotations(mapView)

        // Update search result annotations
        updateSearchAnnotations(mapView)

        // Update overlays: keep city polygons/circles, replace polylines
        mapView.removeOverlays(mapView.overlays.filter { !($0 is MKPolygon) && !($0 is MKCircle) })
        if let route = route {
            mapView.addOverlay(route.polyline)

            // Auto-zoom to the route only once per new route
            if context.coordinator.lastRoutedPolyline !== route.polyline {
                context.coordinator.hasZoomedToRoute = false
                context.coordinator.lastRoutedPolyline = route.polyline
            }
            if !context.coordinator.hasZoomedToRoute && !context.coordinator.userIsInteracting {
                mapView.setVisibleMapRect(
                    route.polyline.boundingMapRect,
                    edgePadding: UIEdgeInsets(top: 80, left: 40, bottom: 80, right: 40),
                    animated: true
                )
                context.coordinator.hasZoomedToRoute = true
            }
        } else {
            // Reset flags when route is cleared
            context.coordinator.hasZoomedToRoute = false
            context.coordinator.lastRoutedPolyline = nil
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func updatePlayerAnnotations(_ mapView: MKMapView) {
        // Remove existing player annotations
        let existingAnnotations = mapView.annotations.filter { annotation in
            annotation is PlayerAnnotation
        }
        mapView.removeAnnotations(existingAnnotations)
        
        // Add new player annotations based on visibility rules
        for (_, location, team, displayName) in visiblePlayerLocations {
            let annotation = PlayerAnnotation(
                displayName: displayName,
                coordinate: location.coordinate,
                team: team
            )
            mapView.addAnnotation(annotation)
        }
    }
    
    private func updateSearchAnnotations(_ mapView: MKMapView) {
        // Remove existing search annotations
        let existingSearchAnnotations = mapView.annotations.filter { annotation in
            annotation is SearchResultAnnotation
        }
        mapView.removeAnnotations(existingSearchAnnotations)
        
        // Add new search result annotations
        for item in searchResults {
            let coordinate = item.location.coordinate
            let isSelected = selectedLandmark == item
            let annotation = SearchResultAnnotation(
                name: item.name ?? "Unknown",
                coordinate: coordinate,
                isSelected: isSelected
            )
            mapView.addAnnotation(annotation)
            
            // If this annotation should be selected, select it on the map
            if isSelected {
                mapView.selectAnnotation(annotation, animated: false)
            }
        }
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        let parent: GameMapView
        var userIsInteracting = false
        var hasZoomedToRoute = false
        var lastRoutedPolyline: MKPolyline?

        init(_ parent: GameMapView) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            // Mark that the user started interacting (pinch/pan)
            userIsInteracting = true
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // Sync binding to reflect the new visible region
            // Allow programmatic updates again after the gesture ends
            DispatchQueue.main.async {
                self.parent.region = mapView.region
                self.userIsInteracting = false
            }
        }
        
        func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {
            // Handle search result annotation selection
            print("did select annotation", annotation.coordinate)
            // Find the corresponding MKMapItem by coordinate and name
            if let mapItem = parent.searchResults.first(where: { item in
                let itemCoordinate = item.location
                let distance = CLLocation(latitude: annotation.coordinate.latitude, longitude: annotation.coordinate.longitude)
                    .distance(from: itemCoordinate)
                return distance < 10
            }) {
                print("map item found", mapItem.address ?? "addy")
                parent.onSearchAnnotationSelected?(mapItem)
            }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.3)
                renderer.strokeColor = UIColor.systemGreen
                renderer.lineWidth = 2.0
                return renderer
            }
            if let circle = overlay as? MKCircle {
                let renderer = MKCircleRenderer(circle: circle)
                renderer.fillColor = UIColor.systemBlue.withAlphaComponent(0.2)
                renderer.strokeColor = UIColor.systemBlue
                renderer.lineWidth = 2.0
                return renderer
            }
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor.systemBlue
                renderer.lineWidth = 5.0
                return renderer
            }
            return MKOverlayRenderer()
        }
    }
}

class SearchResultAnnotation: NSObject, MKAnnotation {
    let name: String
    let coordinate: CLLocationCoordinate2D
    let isSelected: Bool
    
    var title: String? {
        return name
    }
    
    init(name: String, coordinate: CLLocationCoordinate2D, isSelected: Bool) {
        self.name = name
        self.coordinate = coordinate
        self.isSelected = isSelected
        super.init()
    }
}
