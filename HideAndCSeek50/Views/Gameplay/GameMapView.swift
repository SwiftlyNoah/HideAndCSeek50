//
//  GameMapView.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 11/17/25.
//

import SwiftUI
import MapKit
import CoreLocation

struct GameMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    let game: Game?
    let currentUserUID: String
    let currentUserTeam: Team

    // Region shading
    let hidableRegions: [MKPolygon]
    let circleItems: [CircleOverlayItem]
    let selectedRegions: Set<String>
    let regionColors: [String: Bool] // true = red, false = green
    
    // Map tools settings
    let showTrainLines: Bool
    
    // Color options for circles (matching the bottom sheet)
    // Using static reference from MapToolsViewModel
    
    // Search/directions
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
        mapView.mapType = .mutedStandard
        
        // Conditionally add MBTA linework if enabled
        if showTrainLines {
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
        }
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // If the user is interacting, don't force-set the region
        if !context.coordinator.userIsInteracting {
            if !mapView.region.isApproximatelyEqual(to: region) {
                mapView.setRegion(region, animated: true)
            }
        }
        
        // Sync municipality overlays with selectedRegions
        syncMunicipalityOverlays(mapView)
        
        // Sync train line overlays with showTrainLines setting
        syncTrainLineOverlays(mapView)
        
        // Ensure existing polygon renderers reflect latest colors
        updateMunicipalityRendererColors(mapView)

        // Update player annotations
        updatePlayerAnnotations(mapView)

        // Update search result annotations
        updateSearchAnnotations(mapView)
        
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
            circle.title = "userCircle:\(item.id.uuidString):\(item.colorIndex)"
            mapView.addOverlay(circle)
        }
        
        // Update route overlay: remove existing route and add new one if present
        let existingRoutes = mapView.overlays.compactMap { overlay -> MKOverlay? in
            if let polyline = overlay as? MKPolyline,
               let title = polyline.title,
               title == "directions_route" {
                return polyline
            }
            return nil
        }
        if !existingRoutes.isEmpty {
            mapView.removeOverlays(existingRoutes)
        }
        
        if let route = route {
            let routePolyline = route.polyline
            routePolyline.title = "directions_route" // Mark this as a route overlay
            mapView.addOverlay(routePolyline)

            // Auto-zoom to the route only once per new route
            if context.coordinator.lastRoutedPolyline !== routePolyline {
                context.coordinator.hasZoomedToRoute = false
                context.coordinator.lastRoutedPolyline = routePolyline
            }
            if !context.coordinator.hasZoomedToRoute && !context.coordinator.userIsInteracting {
                mapView.setVisibleMapRect(
                    routePolyline.boundingMapRect,
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
    
    private func syncTrainLineOverlays(_ mapView: MKMapView) {
        // Get current MBTA line overlays
        let currentMBTAOverlays = mapView.overlays.filter { overlay in
            if let polyline = overlay as? MKPolyline,
               let title = polyline.title as String? {
                // Check if it's an MBTA line (has route_id) or halo
                return title.contains("Red") || title.contains("Blue") || title.contains("Orange") || title.contains("Green") || polyline.subtitle == "halo"
            }
            return false
        }
        
        if showTrainLines && currentMBTAOverlays.isEmpty {
            // Add train lines
            let mbtaLines = MassachusettsRegions.mbtaLineOverlays
            var haloOverlays: [MKPolyline] = []
            for line in mbtaLines {
                var coords = Array(repeating: kCLLocationCoordinate2DInvalid, count: Int(line.pointCount))
                line.getCoordinates(&coords, range: NSRange(location: 0, length: Int(line.pointCount)))
                let halo = MKPolyline(coordinates: coords, count: coords.count)
                halo.title = line.title
                halo.subtitle = "halo"
                haloOverlays.append(halo)
            }
            if !haloOverlays.isEmpty { mapView.addOverlays(haloOverlays) }
            mapView.addOverlays(mbtaLines)
        } else if !showTrainLines && !currentMBTAOverlays.isEmpty {
            // Remove train lines
            mapView.removeOverlays(currentMBTAOverlays)
        }
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
            // TODO: This code does not function :(
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
                
                // Extract color index from title if it's a user circle
                if let title = circle.title as String?, title.hasPrefix("userCircle:") {
                    let components = title.components(separatedBy: ":")
                    if components.count >= 3, let colorIndex = Int(components[2]) {
                        let safeColorIndex = min(max(colorIndex, 0), MapToolsViewModel.colorOptionsUIKit.count - 1)
                        let color = MapToolsViewModel.colorOptionsUIKit[safeColorIndex]
                        renderer.fillColor = color.withAlphaComponent(0.2)
                        renderer.strokeColor = color
                    } else {
                        // Fallback to blue if parsing fails
                        renderer.fillColor = UIColor.systemBlue.withAlphaComponent(0.2)
                        renderer.strokeColor = UIColor.systemBlue
                    }
                } else {
                    // Default circle styling for non-user circles
                    renderer.fillColor = UIColor.systemBlue.withAlphaComponent(0.2)
                    renderer.strokeColor = UIColor.systemBlue
                }
                
                renderer.lineWidth = 2.0
                return renderer
            }
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                
                // Check if this is a directions route
                if polyline.title == "directions_route" {
                    renderer.strokeColor = UIColor.systemBlue
                    renderer.lineWidth = 5.0
                } else if polyline.subtitle == "halo" {
                    // MBTA line halo (white outline for contrast)
                    renderer.strokeColor = UIColor.white
                    renderer.lineWidth = 4.0
                } else {
                    // Regular MBTA line - use route_id from title to determine color
                    let routeID = polyline.title ?? ""
                    renderer.strokeColor = colorForMBTARoute(routeID)
                    renderer.lineWidth = 2.0
                }
                
                return renderer
            }
            return MKOverlayRenderer()
        }
        
        private func colorForMBTARoute(_ routeID: String) -> UIColor {
            // Return appropriate colors for MBTA routes
            switch routeID {
            case let id where id.contains("Red"):
                return UIColor.systemRed
            case let id where id.contains("Blue"):
                return UIColor.systemBlue
            case let id where id.contains("Orange"):
                return UIColor.systemOrange
            case let id where id.contains("Green"):
                return UIColor.systemGreen
            default:
                return UIColor.systemGray
            }
        }
    }
}

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

class CircleAnnotation: NSObject, MKAnnotation {
    let circleID: UUID
    let coordinate: CLLocationCoordinate2D
    let colorIndex: Int

    var title: String? {
        return "Circle Center"
    }

    init(circleID: UUID, coordinate: CLLocationCoordinate2D, colorIndex: Int) {
        self.circleID = circleID
        self.coordinate = coordinate
        self.colorIndex = colorIndex
        super.init()
    }
}
