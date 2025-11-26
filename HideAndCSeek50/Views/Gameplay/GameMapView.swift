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

class CircleAnnotation: NSObject, MKAnnotation {
    let circleID: UUID
    let coordinate: CLLocationCoordinate2D
    let isRed: Bool
    
    var title: String? {
        return "Circle Center"
    }
    
    init(circleID: UUID, coordinate: CLLocationCoordinate2D, isRed: Bool) {
        self.circleID = circleID
        self.coordinate = coordinate
        self.isRed = isRed
        super.init()
    }
}

struct GameMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    let playerLocations: [String: CLLocation]
    let playerTeams: [String: Team]
    let playerNames: [String: String]
    let currentUserUID: String
    let currentUserTeam: Team
    let hidableRegions: [MKPolygon]
    let circleItems: [CircleOverlayItem]
    let selectedRegions: Set<String>
    let regionColors: [String: Bool] // true = red, false = green
    
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
        mapView.mapType = .mutedStandard
        
        // Always-on overlays: MBTA linework
        // Add thin white halos first for contrast, then colored lines on top
        let mbtaLines = MassachusettsRegions.mbtaLineOverlays
        var haloOverlays: [MKPolyline] = []
        for line in mbtaLines {
            var coords = Array(repeating: kCLLocationCoordinate2DInvalid, count: Int(line.pointCount))
            line.getCoordinates(&coords, range: NSRange(location: 0, length: Int(line.pointCount)))
            let halo = MKPolyline(coordinates: coords, count: coords.count)
            halo.title = line.title // preserve route_id for reference if needed
            halo.subtitle = "halo"   // mark as halo for renderer
            haloOverlays.append(halo)
        }
        if !haloOverlays.isEmpty { mapView.addOverlays(haloOverlays) }
        mapView.addOverlays(mbtaLines)
        
        // Don't add municipality overlays at startup - they'll be added via updateUIView based on selectedRegions
        // This ensures map starts with no visible regions

        // Add any user-defined circle overlays
        for item in circleItems {
            let circle = MKCircle(center: item.center, radius: item.radiusMeters)
            circle.title = "userCircle:\(item.id.uuidString)"
            mapView.addOverlay(circle)
        }
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Keep coordinator's parent reference up-to-date so delegate callbacks
        // see the latest `circleItems` / `selectedRegions` state.
        context.coordinator.parent = self

        // Update region if significantly different
        if !mapView.region.isApproximatelyEqual(to: region) {
            mapView.setRegion(region, animated: true)
        }
        
        // Sync municipality overlays with selectedRegions
        syncMunicipalityOverlays(mapView)
        // Ensure existing polygon renderers reflect latest colors
        updateMunicipalityRendererColors(mapView)
        
        // Update player annotations
        updatePlayerAnnotations(mapView)
        
        // Update circle center annotations
        updateCircleAnnotations(mapView)

        // Update circle overlays: remove existing user circles and add current ones
        let existingUserCircles = mapView.overlays.compactMap { overlay -> MKOverlay? in
            if let c = overlay as? MKCircle, let t = c.title, t.hasPrefix("userCircle:") {
                return c
            }
            return nil
        }
        if !existingUserCircles.isEmpty {
            mapView.removeOverlays(existingUserCircles)
        }

        for item in circleItems {
            let circle = MKCircle(center: item.center, radius: item.radiusMeters)
            circle.title = "userCircle:\(item.id.uuidString)"
            mapView.addOverlay(circle)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    private func syncMunicipalityOverlays(_ mapView: MKMapView) {
        // Get current municipality polygons on the map (exclude circles)
        let currentPolygons = mapView.overlays.compactMap { overlay -> MKPolygon? in
            guard let polygon = overlay as? MKPolygon,
                  let title = polygon.title as String?,
                  !title.hasPrefix("userCircle:") else { return nil }
            return polygon
        }
        
        let currentRegionNames = Set(currentPolygons.compactMap { $0.title as String? })
        
        // Remove polygons that are no longer selected
        let toRemove = currentPolygons.filter { polygon in
            guard let name = polygon.title as String? else { return false }
            return !selectedRegions.contains(name)
        }
        if !toRemove.isEmpty {
            mapView.removeOverlays(toRemove)
        }
        
        // Add polygons for newly selected regions
        let toAdd = selectedRegions.filter { !currentRegionNames.contains($0) }
        for regionName in toAdd {
            if let polygon = hidableRegions.first(where: { ($0.title as String?) == regionName }) {
                mapView.addOverlay(polygon)
            }
        }
    }
    
    // Ensure existing MKPolygonRenderers reflect the latest red/green colors
    private func updateMunicipalityRendererColors(_ mapView: MKMapView) {
        for overlay in mapView.overlays {
            guard let polygon = overlay as? MKPolygon,
                  let title = polygon.title as String? else { continue }
            if let renderer = mapView.renderer(for: overlay) as? MKPolygonRenderer {
                let isRed = regionColors[title] ?? false
                let fillAlpha: CGFloat = isRed ? 0.25 : 0.20
                renderer.fillColor = (isRed ? UIColor.systemRed : UIColor.systemGreen).withAlphaComponent(fillAlpha)
                renderer.strokeColor = (isRed ? UIColor.systemRed : UIColor.systemGreen)
                renderer.lineWidth = 2.0
                renderer.setNeedsDisplay()
            }
        }
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
    
    private func updateCircleAnnotations(_ mapView: MKMapView) {
        // Remove existing circle annotations
        let existingCircleAnnotations = mapView.annotations.filter { annotation in
            annotation is CircleAnnotation
        }
        mapView.removeAnnotations(existingCircleAnnotations)
        
        // Add new circle center annotations
        for item in circleItems {
            let annotation = CircleAnnotation(
                circleID: item.id,
                coordinate: item.center,
                isRed: item.isRed
            )
            mapView.addAnnotation(annotation)
        }
    }
    
    private func determinePlayerTeam(for playerUID: String) -> Team {
        return playerTeams[playerUID] ?? .hiders
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: GameMapView

        init(parent: GameMapView) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // Handle circle center annotations
            if let circleAnnotation = annotation as? CircleAnnotation {
                let identifier = "CircleCenter"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                
                if annotationView == nil {
                    annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = false
                    annotationView?.isDraggable = false
                } else {
                    annotationView?.annotation = annotation
                }
                
                annotationView?.markerTintColor = circleAnnotation.isRed ? .red : .green
                annotationView?.glyphImage = UIImage(systemName: "circle.fill")
                annotationView?.displayPriority = .defaultLow
                
                return annotationView
            }
            
            // Handle player annotations
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
            // Handle circles
            if let circle = overlay as? MKCircle, let title = circle.title, title.starts(with: "userCircle:") {
                let circleRenderer = MKCircleRenderer(circle: circle)
                if let item = parent.circleItems.first(where: { "userCircle:\($0.id)" == title }) {
                    circleRenderer.fillColor = item.isRed ? UIColor.red.withAlphaComponent(0.35) : UIColor.green.withAlphaComponent(0.35)
                    circleRenderer.strokeColor = item.isRed ? UIColor.red : UIColor.green
                    circleRenderer.lineWidth = 2
                }
                return circleRenderer
            }

            // Handle MBTA polylines with route-based coloring and halo
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.lineJoin = .round
                renderer.lineCap = .round
                let isHalo = (polyline.subtitle as String?) == "halo"
                if isHalo {
                    renderer.strokeColor = UIColor.white
                    renderer.lineWidth = 5.0
                    renderer.alpha = 0.9
                    return renderer
                } else {
                    let routeID = (polyline.title as String?)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    func colorForRoute(_ id: String) -> UIColor {
                        let rid = id.lowercased()
                        if rid == "red" || rid == "mattapan" { return UIColor(red: 0.80, green: 0.00, blue: 0.10, alpha: 1.0) }
                        if rid == "orange" { return UIColor.systemOrange }
                        if rid == "blue" { return UIColor(red: 0.00, green: 0.45, blue: 0.80, alpha: 1.0) }
                        if rid.hasPrefix("green") { return UIColor(red: 0.00, green: 0.45, blue: 0.25, alpha: 1.0) }
                        return UIColor.systemTeal
                    }
                    renderer.strokeColor = colorForRoute(routeID)
                    renderer.lineWidth = 3.0
                    renderer.alpha = 0.95
                    return renderer
                }
            }

            // Handle municipality polygons - use system colors and prior alpha
            if let polygon = overlay as? MKPolygon, let title = polygon.title as String? {
                let polygonRenderer = MKPolygonRenderer(polygon: polygon)
                let isRed = parent.regionColors[title] ?? false
                let fillAlpha: CGFloat = isRed ? 0.25 : 0.20
                polygonRenderer.fillColor = (isRed ? UIColor.systemRed : UIColor.systemGreen).withAlphaComponent(fillAlpha)
                polygonRenderer.strokeColor = (isRed ? UIColor.systemRed : UIColor.systemGreen)
                polygonRenderer.lineWidth = 2.0
                return polygonRenderer
            }

            return MKOverlayRenderer(overlay: overlay)
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
