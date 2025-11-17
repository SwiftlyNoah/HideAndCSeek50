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
    let playerUID: String
    let coordinate: CLLocationCoordinate2D
    let team: Team
    
    var title: String? {
        return team == .hiders ? "Hider" : "Seeker"
    }
    
    var subtitle: String? {
        return playerUID
    }
    
    init(playerUID: String, coordinate: CLLocationCoordinate2D, team: Team) {
        self.playerUID = playerUID
        self.coordinate = coordinate
        self.team = team
        super.init()
    }
}

struct GameMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    let playerLocations: [String: CLLocation]
    let currentUserTeam: Team
    let hidableRegions: [MKPolygon]
    let showAllPlayers: Bool
    
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
        
        // Add new player annotations
        for (playerUID, location) in playerLocations {
            let annotation = PlayerAnnotation(
                playerUID: playerUID,
                coordinate: location.coordinate,
                team: determinePlayerTeam(for: playerUID)
            )
            mapView.addAnnotation(annotation)
        }
    }
    
    private func determinePlayerTeam(for playerUID: String) -> Team {
        // This would ideally come from game data, but for now we'll use a simple approach
        // In a real implementation, you'd pass player team information
        return .hiders // Placeholder - should be determined from game data
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
                annotationView?.canShowCallout = false
                annotationView?.isDraggable = false
            } else {
                annotationView?.annotation = annotation
            }
            
            // Customize based on team
            switch playerAnnotation.team {
            case .hiders:
                annotationView?.markerTintColor = .systemBlue
                annotationView?.glyphImage = UIImage(systemName: "eye.slash.fill")
            case .seekers:
                annotationView?.markerTintColor = .systemRed
                annotationView?.glyphImage = UIImage(systemName: "eye.fill")
            }
            
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
