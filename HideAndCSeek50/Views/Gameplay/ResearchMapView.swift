//
//  ResearchMapView.swift
//  HideAndCSeek50
//
//  Created by Ryan Eto on 11/25/25.
//
import SwiftUI
import MapKit
import CoreLocation

// ...existing code...

struct ResearchMapView: View {
    @StateObject private var viewModel = ResearchMapSearchViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showDirectionsSheet = false
    @State private var selectedSearchResult: MKMapItem?
    @State private var hasActiveRoute = false // Track if route is being displayed
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Map View
                MapViewWithRoute(
                    region: $viewModel.region,
                    searchResults: viewModel.searchResults,
                    selectedResult: viewModel.selectedResult,
                    route: viewModel.route,
                    onSelectResult: { item in
                        viewModel.selectedResult = item
                        if let coord = item.placemark.location?.coordinate {
                            viewModel.region.center = coord
                            viewModel.region.span = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                        }
                    }
                )
                .ignoresSafeArea()
                
                VStack {
                    // Search Bar - only show if no active route
                    if !hasActiveRoute {
                        VStack(spacing: 0) {
                            HStack(spacing: 12) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.secondary)
                                
                                TextField("Search for places", text: $viewModel.query)
                                    .textFieldStyle(.plain)
                                    .submitLabel(.search)
                                    .onSubmit {
                                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                        viewModel.search()
                                    }
                                
                                if !viewModel.query.isEmpty {
                                    Button(action: {
                                        viewModel.query = ""
                                        viewModel.searchResults = []
                                        viewModel.selectedResult = nil
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Button("Search") {
                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                    viewModel.search()
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(viewModel.query.isEmpty)
                            }
                            .padding()
                            .background(.regularMaterial)
                            
                            // Search Results List
                            if !viewModel.searchResults.isEmpty && viewModel.selectedResult == nil {
                                ScrollView {
                                    VStack(spacing: 0) {
                                        ForEach(viewModel.searchResults, id: \.self) { item in
                                            Button(action: {
                                                selectedSearchResult = item
                                                viewModel.selectedResult = item
                                                if let coord = item.placemark.location?.coordinate {
                                                    viewModel.region.center = coord
                                                    viewModel.region.span = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                                                }
                                            }) {
                                                HStack {
                                                    VStack(alignment: .leading, spacing: 4) {
                                                        Text(item.name ?? "Unknown")
                                                            .font(.headline)
                                                            .foregroundColor(.primary)
                                                        
                                                        if let address = formatAddress(item.placemark) {
                                                            Text(address)
                                                                .font(.subheadline)
                                                                .foregroundColor(.secondary)
                                                        }
                                                        
                                                        if let category = item.pointOfInterestCategory {
                                                            Text(category.rawValue)
                                                                .font(.caption)
                                                                .foregroundColor(.blue)
                                                        }
                                                    }
                                                    
                                                    Spacer()
                                                    
                                                    Image(systemName: "chevron.right")
                                                        .foregroundColor(.secondary)
                                                }
                                                .padding()
                                                .background(Color(.systemBackground))
                                            }
                                            
                                            Divider()
                                        }
                                    }
                                }
                                .frame(maxHeight: 300)
                                .background(.regularMaterial)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)
                    }
                    
                    Spacer()
                    
                    // Bottom UI - changes based on state
                    if hasActiveRoute {
                        // Route is active - show compact info with clear button
                        routeActiveUI
                    } else if viewModel.selectedResult != nil {
                        // Location selected - show get directions button
                        locationSelectedUI
                    }
                }
            }
            .onAppear {
                // Ensure we have permission and a fresh fix for directions
                LocationManager.shared.requestLocationPermission()
            }
            .navigationTitle(hasActiveRoute ? "Directions" : "Research Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(hasActiveRoute ? "Cancel" : "Done") {
                        if hasActiveRoute {
                            // Clear route and return to map
                            clearRoute()
                        } else {
                            dismiss()
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !hasActiveRoute {
                        Button(action: {
                            // Recenter to current location
                            viewModel.region = MKCoordinateRegion(
                                center: CLLocationCoordinate2D(latitude: 42.3601, longitude: -71.0589),
                                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                            )
                        }) {
                            Image(systemName: "location.fill")
                        }
                    } else {
                        // Show options menu when route is active
                        Menu {
                            Button(action: {
                                showDirectionsSheet = true
                            }) {
                                Label("View Details", systemImage: "list.bullet")
                            }
                            
                            Button(role: .destructive, action: {
                                clearRoute()
                            }) {
                                Label("Clear Route", systemImage: "xmark")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .sheet(isPresented: $showDirectionsSheet) {
                if let destination = viewModel.selectedResult {
                    DirectionsSheet(
                        destination: destination,
                        viewModel: viewModel,
                        onRouteCalculated: {
                            hasActiveRoute = true
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Route Active UI
    
    private var routeActiveUI: some View {
        VStack(spacing: 12) {
            if let result = viewModel.selectedResult, let route = viewModel.route {
                VStack(spacing: 8) {
                    // Destination info
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(result.name ?? "Unknown")
                                .font(.headline)
                            
                            if let address = formatAddress(result.placemark) {
                                Text(address)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    // Route summary with ETA
                    HStack(spacing: 20) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(formatDuration(route.expectedTravelTime))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                // ETA - Calculate from current time
                                let eta = Date().addingTimeInterval(route.expectedTravelTime)
                                Text("ETA: \(eta, style: .time)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.left.and.right")
                                .foregroundColor(.blue)
                            Text(formatDistance(route.distance))
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            showDirectionsSheet = true
                        }) {
                            Text("Details")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 12)
                .background(.regularMaterial)
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
        }
    }
    
    // MARK: - Location Selected UI
    
    private var locationSelectedUI: some View {
        VStack(spacing: 12) {
            if let result = viewModel.selectedResult {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.name ?? "Unknown")
                            .font(.headline)
                        
                        if let address = formatAddress(result.placemark) {
                            Text(address)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        viewModel.selectedResult = nil
                        viewModel.route = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(.regularMaterial)
                .cornerRadius(12)
            }
            
            Button(action: {
                showDirectionsSheet = true
            }) {
                HStack {
                    Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                    Text("Get Directions")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }
    
    // MARK: - Helper Methods
    
    private func clearRoute() {
        withAnimation {
            hasActiveRoute = false
            viewModel.route = nil
            viewModel.selectedResult = nil
            viewModel.searchResults = []
            viewModel.query = ""
        }
    }
    
    private func formatAddress(_ placemark: MKPlacemark) -> String? {
        var components: [String] = []
        
        if let street = placemark.thoroughfare {
            components.append(street)
        }
        if let city = placemark.locality {
            components.append(city)
        }
        if let state = placemark.administrativeArea {
            components.append(state)
        }
        
        return components.isEmpty ? nil : components.joined(separator: ", ")
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes) min"
        }
    }
    
    private func formatDistance(_ meters: CLLocationDistance) -> String {
        let miles = meters / 1609.34
        if miles < 0.1 {
            let feet = meters * 3.28084
            return String(format: "%.0f ft", feet)
        } else {
            return String(format: "%.1f mi", miles)
        }
    }
}

// MARK: - Map View with Route

struct MapViewWithRoute: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    let searchResults: [MKMapItem]
    let selectedResult: MKMapItem?
    let route: MKRoute?
    let onSelectResult: (MKMapItem) -> Void
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Only set region if user hasn't manually interacted with the map
        if !context.coordinator.userHasInteractedWithMap {
            mapView.setRegion(region, animated: true)
        }
        
        // Remove existing annotations and overlays
        mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })
        mapView.removeOverlays(mapView.overlays)
        
        // Add search result annotations
        for item in searchResults {
            if let coordinate = item.placemark.location?.coordinate {
                let annotation = SearchAnnotation(
                    title: item.name ?? "Unknown",
                    subtitle: formatAddress(item.placemark),
                    coordinate: coordinate,
                    isSelected: item == selectedResult
                )
                mapView.addAnnotation(annotation)
            }
        }
        
        // Add route overlay if available
        if let route = route {
            mapView.addOverlay(route.polyline)
            
            // Only auto-zoom to route if it's a new route
            if !context.coordinator.hasZoomedToRoute {
                mapView.setVisibleMapRect(
                    route.polyline.boundingMapRect,
                    edgePadding: UIEdgeInsets(top: 100, left: 50, bottom: 100, right: 50),
                    animated: true
                )
                context.coordinator.hasZoomedToRoute = true
            }
        } else {
            // Reset the flag when route is cleared
            context.coordinator.hasZoomedToRoute = false
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        let parent: MapViewWithRoute
        var userHasInteractedWithMap = false
        var hasZoomedToRoute = false
        
        init(_ parent: MapViewWithRoute) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let searchAnnotation = annotation as? SearchAnnotation else {
                return nil
            }
            
            let identifier = "SearchResult"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
                
                // Add info button to callout
                let infoButton = UIButton(type: .detailDisclosure)
                annotationView?.rightCalloutAccessoryView = infoButton
            } else {
                annotationView?.annotation = annotation
            }
            
            annotationView?.markerTintColor = searchAnnotation.isSelected ? .systemRed : .systemBlue
            
            return annotationView
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .systemBlue
                renderer.lineWidth = 5
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
            guard let annotation = view.annotation as? SearchAnnotation else { return }
            
            // Find the MKMapItem for this annotation
            if let item = parent.searchResults.first(where: {
                $0.placemark.location?.coordinate.latitude == annotation.coordinate.latitude &&
                $0.placemark.location?.coordinate.longitude == annotation.coordinate.longitude
            }) {
                parent.onSelectResult(item)
            }
        }
        
        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            // Mark that user has interacted if this is a manual gesture
            if !animated {
                // Use DispatchQueue to avoid publishing changes during view update
                DispatchQueue.main.async {
                    self.userHasInteractedWithMap = true
                }
            }
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // Use DispatchQueue to avoid publishing changes during view update
            DispatchQueue.main.async {
                self.parent.region = mapView.region
            }
        }
    }
    
    private func formatAddress(_ placemark: MKPlacemark) -> String? {
        var components: [String] = []
        
        if let street = placemark.thoroughfare {
            components.append(street)
        }
        if let city = placemark.locality {
            components.append(city)
        }
        
        return components.isEmpty ? nil : components.joined(separator: ", ")
    }
}


class SearchAnnotation: NSObject, MKAnnotation {
    let title: String?
    let subtitle: String?
    let coordinate: CLLocationCoordinate2D
    let isSelected: Bool
    
    init(title: String?, subtitle: String?, coordinate: CLLocationCoordinate2D, isSelected: Bool) {
        self.title = title
        self.subtitle = subtitle
        self.coordinate = coordinate
        self.isSelected = isSelected
    }
}
