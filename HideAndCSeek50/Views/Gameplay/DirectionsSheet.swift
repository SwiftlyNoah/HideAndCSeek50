//
//  DirectionsSheet.swift
//  HideAndCSeek50
//
//  Created by Ryan Eto on 11/25/25.
//

import SwiftUI
import MapKit

struct DirectionsSheetContent: View {
    let destination: MKMapItem
    let transportType: TransportType
    @ObservedObject var viewModel: MapSearchViewModel
    let onDismiss: () -> Void
    let onRecalculate: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    if let route = viewModel.route {
                        // Route Summary
                        HStack {
                            // Destination info
                            VStack(alignment: .leading, spacing: 4) {
                                Text(destination.name ?? "Unknown")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                
                                if let address = destination.address {
                                    Text(address)
                                        .font(.caption)
                                        .foregroundColor(.primary.opacity(0.7))
                                }
                                
                                HStack(spacing: 6) {
                                    Image(systemName: transportType.iconName)
                                        .foregroundColor(.blue)
                                    
                                    Image(systemName: "circle.fill")
                                        .font(.system(size: 4))
                                    
                                    Text(formatDuration(route.expectedTravelTime))
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    Image(systemName: "circle.fill")
                                        .font(.system(size: 4))

                                    Text(formatDistance(route.distance))
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.primary)
                                .padding(.top, 8)
                            }
                            
                            Spacer()
                            
                            Button(action: onDismiss) {
                                Image(systemName: "xmark")
                                    .tint(.primary)
                                    .opacity(0.7)
                                    .padding(8)
                                    .background(
                                        Color.primary.opacity(0.2)
                                    )
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Advisories
                        if !route.advisoryNotices.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Advisories")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                ForEach(route.advisoryNotices, id: \.self) { notice in
                                    HStack(alignment: .top, spacing: 8) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                        
                                        Text(notice)
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                            .multilineTextAlignment(.leading)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                        }
                        
                        // Turn-by-turn directions
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Directions")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            VStack(alignment: .leading, spacing: 0) {
                                let steps = route.steps.suffix(route.steps.count - 1)
                                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                                    VStack(spacing: 0) {
                                        HStack(alignment: .center, spacing: 12) {
                                            ZStack {
                                                Circle()
                                                    .fill(Color.blue)
                                                    .frame(width: 24, height: 24)
                                                
                                                Text("\(index + 1)")
                                                    .font(.caption2)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.primary)
                                            }
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(step.instructions)
                                                    .font(.subheadline)
                                                    .foregroundColor(.primary)
                                                    .multilineTextAlignment(.leading)
                                                
                                                HStack(spacing: 12) {
                                                    if step.distance > 0 {
                                                        Text(formatDistance(step.distance))
                                                            .font(.caption)
                                                            .foregroundColor(.primary.opacity(0.5))
                                                    }
                                                    
                                                    if step.transportType == .transit {
                                                        Text("Transit")
                                                            .font(.caption)
                                                            .padding(.horizontal, 6)
                                                            .padding(.vertical, 2)
                                                            .background(Color.blue.opacity(0.2))
                                                            .cornerRadius(4)
                                                            .foregroundColor(.blue)
                                                    }
                                                }
                                            }
                                            
                                            Spacer()
                                        }
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 8)
                                        
                                        if index < route.steps.count - 1 {
                                            Divider()
                                                .background(Color.primary.opacity(0.2))
                                                .padding(.horizontal, 20)
                                        }
                                    }
                                }
                            }
                            .background(Color.primary.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal, 20)
                        
                        // Recalculate button
                        Button(action: onRecalculate) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Change Mode of Transport")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.primary.opacity(0.1))
                            .foregroundColor(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal, 20)
                        
                    } else if viewModel.isCalculatingDirections {
                        // Loading state
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .primary))
                            
                            Text("Calculating directions...")
                                .foregroundColor(.primary)
                        }
                        .padding(.top, 40)
                        
                    } else if let error = viewModel.directionsError {
                        // Error state
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.largeTitle)
                                .foregroundColor(.orange)
                            
                            Text("Directions Unavailable")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text(error)
                                .font(.subheadline)
                                .foregroundColor(.primary.opacity(0.7))
                                .multilineTextAlignment(.center)
                            
                            Button("Try Again") {
                                onRecalculate()
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 24)
                            .background(Color.blue)
                            .foregroundColor(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 40)
                    }
                }
                .padding(.bottom, 30)
            }
        }
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

