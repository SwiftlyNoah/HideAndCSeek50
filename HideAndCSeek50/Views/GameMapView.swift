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
    let playerLocations: [String: CLLocation]
    let playerTeams: [String: Team]
    let playerNames: [String: String] // Add player names mapping
    let currentUserUID: String
    let currentUserTeam: Team
    let hidableRegions: [MKPolygon]
    
    private var visiblePlayerLocations: [String: CLLocation] {
        // Filter out current user from annotations and apply team visibility rules
        var filteredLocations = playerLocations.filter { playerUID, _ in
            playerUID != currentUserUID // Don't show annotation for current user
        }
        
        // Team visibility rules:
        // - Seekers can't see hiders
        if currentUserTeam == .seekers {
            // Seekers can see other seekers
            filteredLocations = filteredLocations.filter { (playerUID, _) in
                playerTeams[playerUID] == .seekers
            }
        }
        
        return filteredLocations
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
        // Update region if significantly different
        if !mapView.region.isApproximatelyEqual(to: region) {
            mapView.setRegion(region, animated: true)
        }
        
        // Update player annotations
        updatePlayerAnnotations(mapView)
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
        
        // Add new player annotations based on visibility rules (excludes current user)
        for (playerUID, location) in visiblePlayerLocations {
            let team = playerTeams[playerUID] ?? .hiders
            let displayName = playerNames[playerUID] ?? "Unknown Player"
            let annotation = PlayerAnnotation(
                displayName: displayName,
                coordinate: location.coordinate,
                team: team
            )
            mapView.addAnnotation(annotation)
        }
    }
    
    private func determinePlayerTeam(for playerUID: String) -> Team {
        return playerTeams[playerUID] ?? .hiders
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        let parent: GameMapView
        
        init(_ parent: GameMapView) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let playerAnnotation = annotation as? PlayerAnnotation else {
                return nil
            }
            
            let identifier = "PlayerPin"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
                annotationView?.isDraggable = false
            } else {
                annotationView?.annotation = annotation
            }
            
            // Customize based on team using Team enum properties
            annotationView?.markerTintColor = playerAnnotation.team.color
            annotationView?.glyphImage = UIImage(systemName: playerAnnotation.team.iconName)
            
            return annotationView
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                
                // Style hidable areas
                renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.3)
                renderer.strokeColor = UIColor.systemGreen
                renderer.lineWidth = 2.0
                
                return renderer
            }
            
            return MKOverlayRenderer()
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.region = mapView.region
        }
    }
}

// Extension to compare regions
extension MKCoordinateRegion {
    func isApproximatelyEqual(to other: MKCoordinateRegion, threshold: Double = 0.001) -> Bool {
        return abs(center.latitude - other.center.latitude) < threshold &&
               abs(center.longitude - other.center.longitude) < threshold &&
               abs(span.latitudeDelta - other.span.latitudeDelta) < threshold &&
               abs(span.longitudeDelta - other.span.longitudeDelta) < threshold
    }
}
