//
//  RadiusView.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 12/7/25.
//

import SwiftUI
import MapKit

struct RadiusSectionView: View {
    @ObservedObject var viewModel: MapToolsViewModel
    @Binding var mapCenter: CLLocationCoordinate2D
    let contextItem: MKMapItem?
    @FocusState private var isCustomRadiusFocused: Bool
    
    private var firstRowIndices: [Int] {
        let count = viewModel.milesOptions.count
        return Array(0..<(count / 2))
    }
    private var secondRowIndices: [Int] {
        let count = viewModel.milesOptions.count
        return Array((count / 2)..<count)
    }
    
    var body: some View {
        DisclosureGroup(isExpanded: $viewModel.radiusExpanded) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Circle Color:")
                        .font(.caption)
                        .foregroundColor(.primary.opacity(0.7))
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Array(MapToolsViewModel.colorOptions.enumerated()), id: \.offset) { index, color in
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        viewModel.radiusColorIndex = index
                                    }
                                }) {
                                    Circle()
                                        .fill(color)
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.primary, lineWidth: viewModel.radiusColorIndex == index ? 3 : 0)
                                        )
                                        .scaleEffect(viewModel.radiusColorIndex == index ? 1.1 : 1.0)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(4)
                        }
                    }
                }
                Toggle(isOn: $viewModel.shadeOutsideCircle) {
                    HStack(spacing: 8) {
                        Image(systemName: "circle.dotted")
                            .foregroundColor(.primary.opacity(0.8))
                        Text("Shade outside the circle")
                            .foregroundColor(.primary)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                .padding(.top, 4)
                
                // Preset radius chips in two rows (replaces segmented Picker)
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Button {
                            viewModel.useCustomRadius = true
                        } label: {
                            Text("Custom")
                                .font(.caption)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 10)
                                .background(
                                    viewModel.useCustomRadius
                                    ? MapToolsViewModel.colorOptions[viewModel.radiusColorIndex].opacity(0.30)
                                    : Color.primary.opacity(0.12)
                                )
                                .foregroundColor(.primary)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().stroke(Color.primary.opacity(
                                        viewModel.useCustomRadius ? 0.8 : 0.2
                                    ), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        
                        ForEach(firstRowIndices, id: \.self) { idx in
                            Button {
                                viewModel.radiusMilesIndex = idx
                                viewModel.useCustomRadius = false
                            } label: {
                                Text("\(viewModel.milesOptions[idx], specifier: "%.1f") mi")
                                    .font(.caption)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 10)
                                    .background(
                                        (viewModel.radiusMilesIndex == idx && !viewModel.useCustomRadius)
                                        ? MapToolsViewModel.colorOptions[viewModel.radiusColorIndex].opacity(0.30)
                                        : Color.primary.opacity(0.12)
                                    )
                                    .foregroundColor(.primary)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule().stroke(Color.primary.opacity(
                                            (viewModel.radiusMilesIndex == idx && !viewModel.useCustomRadius) ? 0.8 : 0.2
                                        ), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    HStack(spacing: 8) {
                        ForEach(secondRowIndices, id: \.self) { idx in
                            Button {
                                viewModel.radiusMilesIndex = idx
                                viewModel.useCustomRadius = false
                            } label: {
                                Text("\(viewModel.milesOptions[idx], specifier: "%.1f") mi")
                                    .font(.caption)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 10)
                                    .background(
                                        (viewModel.radiusMilesIndex == idx && !viewModel.useCustomRadius)
                                        ? MapToolsViewModel.colorOptions[viewModel.radiusColorIndex].opacity(0.30)
                                        : Color.primary.opacity(0.12)
                                    )
                                    .foregroundColor(.primary)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule().stroke(Color.primary.opacity(
                                            (viewModel.radiusMilesIndex == idx && !viewModel.useCustomRadius) ? 0.8 : 0.2
                                        ), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Removed the entire Toggle for "Use custom radius" and its surrounding HStack
                
                // Custom radius input shown only if useCustomRadius is true
                if viewModel.useCustomRadius {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Custom Radius (mi)")
                                .font(.caption)
                                .foregroundColor(.primary.opacity(0.7))
                            TextField("e.g. 0.75", value: $viewModel.customRadiusMiles, format: .number)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 120)
                                .focused($isCustomRadiusFocused)
                                .onChange(of: viewModel.customRadiusMiles) { _, newVal in
                                    if newVal < 0 { viewModel.customRadiusMiles = 0 }
                                }
                        }
                        Spacer()
                    }
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Center:")
                            .font(.caption)
                            .foregroundColor(.primary.opacity(0.7))
                        if let item = contextItem {
                            Text(item.name ?? "Selected Location")
                                .font(.caption2)
                                .foregroundColor(.primary)
                        } else {
                            Text("Lat: \(mapCenter.latitude, specifier: "%.5f")")
                                .font(.caption2)
                                .foregroundColor(.primary)
                            Text("Lon: \(mapCenter.longitude, specifier: "%.5f")")
                                .font(.caption2)
                                .foregroundColor(.primary)
                        }
                    }
                    Spacer()
                    Button(action: {
                        let center = contextItem?.location.coordinate ?? mapCenter
                        viewModel.addCircle(at: center)
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Circle")
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .background(MapToolsViewModel.colorOptions[viewModel.radiusColorIndex].opacity(0.4))
                        .foregroundColor(.primary)
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
                                    .foregroundColor(.primary)
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
            .background(Color.primary.opacity(0.1))
            .cornerRadius(12)
            
            // Dismiss keyboard when tapping outside the TextField
            .onTapGesture {
                if isCustomRadiusFocused {
                    isCustomRadiusFocused = false
                }
            }
            // Add a keyboard toolbar Done button
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isCustomRadiusFocused = false
                    }
                }
            }
        } label: {
            HStack {
                Image(systemName: "circle.fill")
                    .foregroundColor(.primary.opacity(0.8))
                Text("Radius Tools")
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.vertical, 4)
        }
        .accentColor(.clear)
    }
}
