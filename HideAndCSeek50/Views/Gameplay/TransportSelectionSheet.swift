//
//  TransportSelectionSheet.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 11/27/25.
//

import SwiftUI
import MapKit
import CoreLocation

struct TransportSelectionSheetContent: View {
    let destination: MKMapItem
    let userLocation: CLLocation?
    let onTransportSelected: (TransportType) -> Void
    let onDismiss: () -> Void
    
    let onUseAsCircleCenter: (_ radiusMeters: Double, _ colorIndex: Int, _ shadeOutside: Bool) -> Void
    @ObservedObject var mapToolsViewModel: MapToolsViewModel

    
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
            
            // Radius/Color section ported from MapTools
            DisclosureGroup(isExpanded: $mapToolsViewModel.radiusExpanded) {
                VStack(alignment: .leading, spacing: 16) {
                    // Circle Color
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Circle Color:")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(Array(MapToolsViewModel.colorOptions.enumerated()), id: \.offset) { index, color in
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            mapToolsViewModel.radiusColorIndex = index
                                        }
                                    }) {
                                        Circle()
                                            .fill(color)
                                            .frame(width: 28, height: 28)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.white, lineWidth: mapToolsViewModel.radiusColorIndex == index ? 3 : 0)
                                            )
                                            .scaleEffect(mapToolsViewModel.radiusColorIndex == index ? 1.1 : 1.0)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(4)
                            }
                        }
                    }
                    
                    // Shade outside toggle
                    Toggle(isOn: $mapToolsViewModel.shadeOutsideCircle) {
                        HStack(spacing: 8) {
                            Image(systemName: "circle.dotted")
                                .foregroundColor(.white.opacity(0.8))
                            Text("Shade outside the circle")
                                .foregroundColor(.white)
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .padding(.top, 4)
                    
                    // Preset radius chips
                    VStack(spacing: 8) {
                        let options = mapToolsViewModel.milesOptions
                        let splitIndex = options.count / 2 + options.count % 2
                        HStack(spacing: 8) {
                            ForEach(0..<splitIndex, id: \.self) { idx in
                                Button {
                                    mapToolsViewModel.radiusMilesIndex = idx
                                    mapToolsViewModel.useCustomRadius = false
                                } label: {
                                    Text("\(options[idx], specifier: "%.1f") mi")
                                        .font(.caption)
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 10)
                                        .background(
                                            (mapToolsViewModel.radiusMilesIndex == idx && !mapToolsViewModel.useCustomRadius)
                                            ? MapToolsViewModel.colorOptions[mapToolsViewModel.radiusColorIndex].opacity(0.30)
                                            : Color.white.opacity(0.12)
                                        )
                                        .foregroundColor(.white)
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule().stroke(Color.white.opacity(
                                                (mapToolsViewModel.radiusMilesIndex == idx && !mapToolsViewModel.useCustomRadius) ? 0.8 : 0.2
                                            ), lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        HStack(spacing: 8) {
                            ForEach(splitIndex..<options.count, id: \.self) { idx in
                                Button {
                                    mapToolsViewModel.radiusMilesIndex = idx
                                    mapToolsViewModel.useCustomRadius = false
                                } label: {
                                    Text("\(options[idx], specifier: "%.1f") mi")
                                        .font(.caption)
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 10)
                                        .background(
                                            (mapToolsViewModel.radiusMilesIndex == idx && !mapToolsViewModel.useCustomRadius)
                                            ? MapToolsViewModel.colorOptions[mapToolsViewModel.radiusColorIndex].opacity(0.30)
                                            : Color.white.opacity(0.12)
                                        )
                                        .foregroundColor(.white)
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule().stroke(Color.white.opacity(
                                                (mapToolsViewModel.radiusMilesIndex == idx && !mapToolsViewModel.useCustomRadius) ? 0.8 : 0.2
                                            ), lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    // Custom radius
                    Toggle(isOn: $mapToolsViewModel.useCustomRadius) {
                        Text("Use custom radius")
                            .foregroundColor(.white)
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Custom Radius (mi)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            TextField("e.g. 0.75", value: $mapToolsViewModel.customRadiusMiles, format: .number)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 120)
                                .onChange(of: mapToolsViewModel.customRadiusMiles) { _, newVal in
                                    if newVal < 0 { mapToolsViewModel.customRadiusMiles = 0 }
                                }
                        }
                        Spacer()
                    }
                    
                    // Add circle using destination as center
                    Button {
                        let radiusMeters = mapToolsViewModel.radiusSelectedMiles * 1609.34
                        let colorIndex = mapToolsViewModel.radiusColorIndex
                        let shadeOutside = mapToolsViewModel.shadeOutsideCircle
                        onUseAsCircleCenter(radiusMeters, colorIndex, shadeOutside)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Circle at Destination")
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .background(MapToolsViewModel.colorOptions[mapToolsViewModel.radiusColorIndex].opacity(0.4))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "circle.fill")
                        .foregroundColor(.white.opacity(0.95))
                    Text("Center Radius")
                        .foregroundColor(.white)
                        .font(.title3.weight(.semibold))
                    Spacer().frame(width: 4)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                .background(Color.white.opacity(0.06))
                .cornerRadius(10)
            }
            .accentColor(.white)
        }
        
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
