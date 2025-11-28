//
//  MapToolsBottomSheet.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 11/28/25.
//

import SwiftUI
import MapKit

struct MapToolsBottomSheetContent: View {
    @ObservedObject var viewModel: MapToolsViewModel
    @Binding var mapCenter: CLLocationCoordinate2D
    let onDismiss: () -> Void
        
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Map Tools")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(8)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            
            // Content
            ScrollView {
                VStack(spacing: 16) {
                    // Train Lines Toggle (no disclosure group)
                    HStack {
                        Image(systemName: "tram.fill")
                            .foregroundColor(.white.opacity(0.8))

                        Text("Train Lines")
                            .foregroundColor(.white)
                        Spacer()
                        
                        Toggle("", isOn: $viewModel.showTrainLines)
                            .toggleStyle(SwitchToggleStyle(tint: .green))
                    }
                
                    // Municipalities group
                    DisclosureGroup(isExpanded: $viewModel.municipalitiesExpanded) {
                        VStack(spacing: 16) {
                            HStack(spacing: 12) {
                                Button(action: viewModel.showAllGreen) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.caption)
                                        Text("All Green")
                                            .font(.caption)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Color.green.opacity(0.2))
                                    .foregroundColor(.green)
                                    .cornerRadius(8)
                                }
                                
                                Button(action: viewModel.hideAll) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "eye.slash.fill")
                                            .font(.caption)
                                        Text("Clear All")
                                            .font(.caption)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Color.gray.opacity(0.2))
                                    .foregroundColor(.gray)
                                    .cornerRadius(8)
                                }
                                
                                Button(action: viewModel.showAllRed) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.caption)
                                        Text("All Red")
                                            .font(.caption)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Color.red.opacity(0.2))
                                    .foregroundColor(.red)
                                    .cornerRadius(8)
                                }
                            }
                            
                            if viewModel.allRegionNames.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "map")
                                        .font(.title)
                                        .foregroundColor(.white.opacity(0.6))
                                    Text("No regions available")
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                            } else {
                                ScrollView {
                                    LazyVStack(spacing: 8) {
                                        ForEach(viewModel.allRegionNames, id: \.self) { regionName in
                                            regionToggleButton(regionName)
                                        }
                                    }
                                }
                                .frame(maxHeight: .infinity)
                            }
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        
                    } label: {
                        HStack {
                            Image(systemName: "building.2.fill")
                                .foregroundColor(.white.opacity(0.8))
                            Text("Municipalities")
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .accentColor(.clear)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.municipalitiesExpanded)
                    
                    // Radius group
                    DisclosureGroup(isExpanded: $viewModel.radiusExpanded) {
                        VStack(alignment: .leading, spacing: 16) {
                            // Color selection
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Circle Color:")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(Array(MapToolsViewModel.colorOptions.enumerated()), id: \.offset) { index, color in
                                            Button(action: { 
                                                withAnimation(.easeInOut(duration: 0.2)) { 
                                                    viewModel.selectedColorIndex = index 
                                                }
                                            }) {
                                                Circle()
                                                    .fill(color)
                                                    .frame(width: 32, height: 32)
                                                    .overlay(
                                                        Circle()
                                                            .stroke(Color.white, lineWidth: viewModel.selectedColorIndex == index ? 3 : 0)
                                                    )
                                                    .scaleEffect(viewModel.selectedColorIndex == index ? 1.1 : 1.0)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(4)
                                    }
                                }
                            }
                            
                            Picker("Radius (miles)", selection: $viewModel.selectedMilesIndex) {
                                ForEach(viewModel.milesOptions.indices, id: \.self) { idx in
                                    Text("\(viewModel.milesOptions[idx], specifier: "%.1f") mi").tag(idx)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .colorScheme(.dark)
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Center:")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                    Text("Lat: \(mapCenter.latitude, specifier: "%.5f")")
                                        .font(.caption2)
                                        .foregroundColor(.white)
                                    Text("Lon: \(mapCenter.longitude, specifier: "%.5f")")
                                        .font(.caption2)
                                        .foregroundColor(.white)
                                }
                                Spacer()
                                Button(action: { viewModel.addCircleAtCenter(mapCenter) }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "plus.circle.fill")
                                        Text("Add Circle")
                                    }
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 16)
                                    .background(MapToolsViewModel.colorOptions[viewModel.selectedColorIndex].opacity(0.4))
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            if !viewModel.circleItems.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(Array(viewModel.circleItems.enumerated()), id: \.element.id) { _, item in
                                        HStack {
                                            Circle()
                                                .fill(MapToolsViewModel.colorOptions[min(item.colorIndex, MapToolsViewModel.colorOptions.count - 1)])
                                                .frame(width: 12, height: 12)
                                            Text("\(item.radiusMeters / 1609.34, specifier: "%.1f") mi — Lat:\(item.center.latitude, specifier: "%.3f")")
                                                .font(.caption)
                                                .foregroundColor(.white)
                                            Spacer()
                                            Button(role: .destructive) {
                                                withAnimation(.easeInOut(duration: 0.16)) {
                                                    viewModel.removeCircle(withId: item.id)
                                                }
                                            } label: {
                                                Image(systemName: "trash")
                                                    .foregroundColor(.red)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(.vertical, 6)
                                    }
                                }
                                .padding(.top, 4)
                            }
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                    } label: {
                        HStack {
                            Image(systemName: "circle.fill")
                                .foregroundColor(.white.opacity(0.8))
                            Text("Radius Tools")
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .accentColor(.clear)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.radiusExpanded)
                    
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }
    
    private func regionToggleButton(_ regionName: String) -> some View {
        HStack(spacing: 12) {
            // Green checkbox on the left
            Button(action: { viewModel.toggleGreen(regionName) }) {
                Image(systemName: viewModel.greenRegions.contains(regionName) ? "checkmark.square.fill" : "square")
                    .font(.system(size: 18))
                    .foregroundColor(.green)
            }
            .buttonStyle(.plain)
            
            Text(regionName)
                .font(.body)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Red checkbox on the right
            Button(action: { viewModel.toggleRed(regionName) }) {
                Image(systemName: viewModel.redRegions.contains(regionName) ? "checkmark.square.fill" : "square")
                    .font(.system(size: 18))
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
}
