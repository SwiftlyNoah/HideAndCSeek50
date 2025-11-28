//
//  TransportSelectionSheet.swift
//  HideAndCSeek50
//
//  Created by Assistant on 11/27/25.
//

import SwiftUI
import MapKit
import CoreLocation

struct TransportSelectionSheetContent: View {
    let destination: MKMapItem
    let userLocation: CLLocation?
    let onTransportSelected: (TransportType) -> Void
    let onDismiss: () -> Void
    
    private var distance: String? {
        guard let userLocation = userLocation else {
            return nil
        }
        
        let destinationLocation = destination.location
        let distanceInMeters = userLocation.distance(from: destinationLocation)
        let distanceInMiles = distanceInMeters / 1609.34
        
        if distanceInMiles < 0.1 {
            let distanceInFeet = distanceInMeters * 3.28084
            return String(format: "%.0f ft", distanceInFeet)
        } else {
            return String(format: "%.1f mi", distanceInMiles)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .top) {
                // Destination info
                VStack(alignment: .leading, spacing: 8) {
                    Text(destination.name ?? "Unknown Location")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    if let address = destination.address {
                        HStack(spacing: 6) {
                            Image(systemName: "location")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            Text(address)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    
                    if let distance = distance {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.left.and.right")
                                .font(.caption)
                                .foregroundColor(.blue.opacity(0.8))
                            Text("\(distance) away")
                                .font(.caption)
                                .foregroundColor(.blue.opacity(0.8))
                                .fontWeight(.medium)
                        }
                    }
                }
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(8)
                        .background(
                            Color.white.opacity(0.2)
                        )
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            
            // Transport options
            VStack(spacing: 12) {
                ForEach(TransportType.allCases) { transportType in
                    TransportOptionRow(
                        transportType: transportType,
                        onTap: {
                            onTransportSelected(transportType)
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
}

struct TransportOptionRow: View {
    let transportType: TransportType
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: transportType.iconName)
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                
                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(transportType.displayName)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(transportType.description)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                // Arrow
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 16)
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}
