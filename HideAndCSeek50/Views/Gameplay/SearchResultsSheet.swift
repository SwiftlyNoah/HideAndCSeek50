//
//  SearchResultsSheet.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 11/27/25.
//

import SwiftUI
import MapKit
import CoreLocation

struct SearchResultsSheetContent: View {
    @ObservedObject var viewModel: MapSearchViewModel
    let userLocation: CLLocation?
    let onItemSelected: (MKMapItem) -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(viewModel.query)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
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
            
            // Content
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.results, id: \.self) { item in
                        SearchResultRow(
                            item: item,
                            userLocation: userLocation,
                            isSelected: viewModel.selectedLandmark == item,
                            onTap: {
                                onItemSelected(item)
                            }
                        )
                        .padding(.horizontal, 20)
                        
                        if item != viewModel.results.last {
                            Divider()
                                .background(Color.white.opacity(0.2))
                                .padding(.horizontal, 20)
                        }
                    }
                }
                .padding(.bottom, 20)
            }
        }
    }
}

struct SearchResultRow: View {
    let item: MKMapItem
    let userLocation: CLLocation?
    let isSelected: Bool
    let onTap: () -> Void
    
    private var distance: String? {
        guard let userLocation = userLocation else {
            return nil
        }
        
        let itemLocation = item.location
        let distanceInMeters = userLocation.distance(from: itemLocation)
        let distanceInMiles = distanceInMeters / 1609.34
        
        if distanceInMiles < 0.1 {
            let distanceInFeet = distanceInMeters * 3.28084
            return String(format: "%.0f ft", distanceInFeet)
        } else {
            return String(format: "%.1f mi", distanceInMiles)
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name ?? "Unknown")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        if let address = item.address {
                            Text(address)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                                .lineLimit(1)
                        }
                        
                        if let distance = distance {
                            HStack(spacing: 3) {
                                Image(systemName: "location")
                                    .font(.caption2)
                                    .foregroundColor(.blue.opacity(0.8))
                                
                                Text(distance)
                                    .font(.caption)
                                    .foregroundColor(.blue.opacity(0.8))
                                    .fontWeight(.medium)
                            }
                        }
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.subheadline)
                }
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
