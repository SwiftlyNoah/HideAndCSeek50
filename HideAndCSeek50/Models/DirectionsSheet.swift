//
//  Directions.swift
//  HideAndCSeek50
//
//  Created by Ryan Eto on 11/25/25.
//


import SwiftUI
import MapKit

struct DirectionsSheet: View {
    let destination: MKMapItem
    @ObservedObject var viewModel: ResearchMapSearchViewModel
    let onRouteCalculated: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTransportType: TransportType = .automobile
    @State private var selectedDepartureType: Int = 0
    @State private var customDate = Date()
    @State private var hasCalculatedRoute = false
    
    // Initialize with existing route if available
    init(destination: MKMapItem, viewModel: ResearchMapSearchViewModel, onRouteCalculated: @escaping () -> Void) {
        self.destination = destination
        self.viewModel = viewModel
        self.onRouteCalculated = onRouteCalculated
        
        // If route already exists, mark as calculated
        _hasCalculatedRoute = State(initialValue: viewModel.route != nil)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Destination Info
                Section("Destination") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(destination.name ?? "Unknown")
                            .font(.headline)
                        
                        if let address = formatAddress(destination.placemark) {
                            Text(address)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Only show transport and schedule options if route hasn't been calculated
                if !hasCalculatedRoute {
                    // Transport Type
                    Section("Transportation") {
                        Picker("Mode of Transport", selection: $selectedTransportType) {
                            ForEach(TransportType.allCases) { type in
                                Label(type.displayName, systemImage: type.iconName)
                                    .tag(type)
                            }
                        }
                        .pickerStyle(.inline)
                    }
                    
                    // Departure Time
                    Section("Schedule") {
                        Picker("When", selection: $selectedDepartureType) {
                            Text("Leave Now").tag(0)
                            Text("Leave At").tag(1)
                            Text("Arrive By").tag(2)
                        }
                        .pickerStyle(.segmented)
                        
                        if selectedDepartureType != 0 {
                            DatePicker(
                                selectedDepartureType == 1 ? "Departure Time" : "Arrival Time",
                                selection: $customDate,
                                in: Date()...,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                        }
                    }
                }
                
                // Route Information (if available)
                if let route = viewModel.route, hasCalculatedRoute {
                    Section("Route Summary") {
                        // Transport Mode
                        HStack {
                            Image(systemName: selectedTransportType.iconName)
                            Text("Transport")
                            Spacer()
                            Text(selectedTransportType.displayName)
                                .foregroundColor(.secondary)
                        }
                        
                        // Travel Time
                        HStack {
                            Image(systemName: "clock")
                            Text("Travel Time")
                            Spacer()
                            Text(formatDuration(route.expectedTravelTime))
                                .foregroundColor(.secondary)
                        }
                        
                        // Distance
                        HStack {
                            Image(systemName: "arrow.left.and.right")
                            Text("Distance")
                            Spacer()
                            Text(formatDistance(route.distance))
                                .foregroundColor(.secondary)
                        }
                        
                        // Departure and arrival times
                        let departureTime = calculateDepartureTime(route: route)
                        let arrivalTime = calculateArrivalTime(from: departureTime, travelTime: route.expectedTravelTime)
                        
                        HStack {
                            Image(systemName: "arrow.up.circle")
                            Text(selectedDepartureType == 2 ? "Must Leave By" : "Depart")
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(departureTime, style: .time)
                                    .foregroundColor(.secondary)
                                if selectedDepartureType == 2 {
                                    Text("(\(formatTimeUntil(departureTime)))")
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                        
                        HStack {
                            Image(systemName: "arrow.down.circle")
                            Text("Arrive")
                            Spacer()
                            Text(arrivalTime, style: .time)
                                .foregroundColor(.secondary)
                        }
                        
                        // Advisories
                        if !route.advisoryNotices.isEmpty {
                            DisclosureGroup("Advisories") {
                                ForEach(route.advisoryNotices, id: \.self) { notice in
                                    Text(notice)
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                    }
                    
                    // Turn-by-turn directions
                    Section("Directions") {
                        ForEach(Array(route.steps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.blue)
                                        .frame(width: 24, height: 24)
                                    
                                    Text("\(index + 1)")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(step.instructions)
                                        .font(.subheadline)
                                    
                                    HStack(spacing: 12) {
                                        if step.distance > 0 {
                                            Text(formatDistance(step.distance))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        if step.transportType == .transit {
                                            Text("Transit")
                                                .font(.caption)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.blue.opacity(0.2))
                                                .cornerRadius(4)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    // Recalculate Button
                    Section {
                        Button(action: {
                            hasCalculatedRoute = false
                            viewModel.route = nil
                        }) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Change Route Options")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    // Get Directions Button (only show if route hasn't been calculated)
                    Section {
                        Button(action: getDirections) {
                            HStack {
                                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                                Text("Get Directions")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                
                // Show error if directions failed
                if let error = viewModel.directionsError {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.title2)
                                    .foregroundColor(.orange)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Directions Unavailable")
                                        .font(.headline)
                                        .foregroundColor(.orange)
                                    
                                    Text(error)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(.vertical, 4)
                            
                            if selectedTransportType == .transit {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Troubleshooting Tips:")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("• Transit data may not be available in all areas")
                                        Text("• Try selecting a major transit station")
                                        Text("• Check if transit operates at the selected time")
                                        Text("• Try driving or walking directions instead")
                                    }
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                }
                                .padding(.top, 4)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                if viewModel.directionsError != nil && !hasCalculatedRoute {
                    Section {
                        Button(action: {
                            // Test with a known location - Boston Common
                            let testLocation = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: 42.3601, longitude: -71.0589)))
                            testLocation.name = "Boston Common"
                            
                            viewModel.getDirections(
                                to: testLocation,
                                transportType: .walking,
                                departureType: .leaveNow
                            )
                        }) {
                            HStack {
                                Image(systemName: "hammer.fill")
                                Text("Test with Boston Common (Walking)")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    } header: {
                        Text("Debug")
                    }
                }
            }
            .navigationTitle(hasCalculatedRoute ? "Route Details" : "Directions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                if hasCalculatedRoute {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("View on Map") {
                            dismiss()
                        }
                    }
                }
            }
        }
    }
    
    private func getDirections() {
        let departureType: ResearchMapSearchViewModel.DepartureType
        switch selectedDepartureType {
        case 1:
            departureType = .leaveAt(customDate)
        case 2:
            departureType = .arriveBy(customDate)
        default:
            departureType = .leaveNow
        }
        
        viewModel.getDirections(
            to: destination,
            transportType: selectedTransportType.mkDirectionsType,
            departureType: departureType
        )
        
        // Mark route as calculated
        hasCalculatedRoute = true
        
        // Notify parent that route was calculated
        onRouteCalculated()
        
        // Dismiss sheet to show route on map
        dismiss()
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
    
    private func formatTimeUntil(_ date: Date) -> String {
        let interval = date.timeIntervalSinceNow
        
        if interval < 0 {
            return "now"
        }
        
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        
        if hours > 0 {
            return "in \(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "in \(minutes)m"
        } else {
            return "now"
        }
    }
    
    private func calculateDepartureTime(route: MKRoute) -> Date {
        // Calculate based on user selection
        switch selectedDepartureType {
        case 1: // Leave At
            return customDate
        case 2: // Arrive By
            return customDate.addingTimeInterval(-route.expectedTravelTime)
        default: // Leave Now
            return Date()
        }
    }
    
    private func calculateArrivalTime(from departureTime: Date, travelTime: TimeInterval) -> Date {
        return departureTime.addingTimeInterval(travelTime)
    }
}

// Transport Type Enum
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
    
    var mkDirectionsType: MKDirectionsTransportType {
        switch self {
        case .automobile: return .automobile
        case .walking: return .walking
        case .transit: return .transit
        }
    }
}

