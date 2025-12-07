//
//  MeasureToolView.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 12/7/25.
//

import SwiftUI
import MapKit

// MARK: - Measure Tool
struct MeasureToolView: View {
    @ObservedObject var viewModel: MapToolsViewModel
    @Binding var mapCenter: CLLocationCoordinate2D
    let contextItem: MKMapItem?
    
    private func formatDistance(_ meters: CLLocationDistance) -> String {
        let miles = meters / 1609.34
        if miles < 0.1 {
            let feet = meters * 3.28084
            return String(format: "%.0f ft", feet)
        } else {
            return String(format: "%.2f mi", miles)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Live distance display above the buttons
            VStack(alignment: .leading, spacing: 4) {
                Text("Live Distance")
                    .font(.caption)
                    .foregroundColor(.primary.opacity(0.7))
                if let d = viewModel.measureTool.distanceMeters, viewModel.measureTool.pointA != nil {
                    Text("\(formatDistance(d))")
                        .font(.headline)
                        .foregroundColor(.primary)
                } else {
                    Text("Set Point A to start")
                        .font(.caption2)
                        .foregroundColor(.primary.opacity(0.7))
                }
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Measure Point")
                        .font(.caption)
                        .foregroundColor(.primary.opacity(0.7))
                    if let item = contextItem {
                        Text(item.name ?? "Selected Location")
                            .font(.caption2)
                            .foregroundColor(.primary)
                    } else {
                        Text(viewModel.measureTool.pointA.map { "Lat: \($0.latitude, specifier: "%.5f"), Lon: \($0.longitude, specifier: "%.5f")" } ?? "Not set")
                            .font(.caption2)
                            .foregroundColor(.primary)
                    }
                }
                Spacer()
                if contextItem == nil {
                    Button {
                        viewModel.setMeasurePointA(mapCenter)
                        viewModel.updateMeasureLive(toCrosshair: mapCenter)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "mappin.circle")
                            Text("Set Measure Point")
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.primary.opacity(0.12))
                        .foregroundColor(.primary)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Keep color picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Line Color:")
                    .font(.caption)
                    .foregroundColor(.primary.opacity(0.7))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(MapToolsViewModel.colorOptions.enumerated()), id: \.offset) { index, color in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.measureColorIndex = index
                                }
                            }) {
                                Circle()
                                    .fill(color)
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary, lineWidth: viewModel.measureColorIndex == index ? 3 : 0)
                                    )
                                    .scaleEffect(viewModel.measureColorIndex == index ? 1.1 : 1.0)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(4)
                    }
                }
            }
            
            HStack(spacing: 12) {
                Button {
                    // Use current crosshair as Point B, then save
                    viewModel.measureTool.pointB = mapCenter
                    viewModel.addCurrentMeasurement()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Measurement")
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(MapToolsViewModel.colorOptions[viewModel.measureColorIndex].opacity(0.35))
                    .foregroundColor(.primary)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                Button(role: .destructive) {
                    viewModel.clearMeasure()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                        Text("Clear")
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.red.opacity(0.15))
                    .foregroundColor(.red)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            
            if !viewModel.measureItems.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Saved Measurements")
                        .font(.caption)
                        .foregroundColor(.primary.opacity(0.7))
                    ForEach(viewModel.measureItems) { item in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(MapToolsViewModel.colorOptions[min(item.colorIndex, MapToolsViewModel.colorOptions.count - 1)])
                                .frame(width: 10, height: 10)
                            Text("\(formatDistance(item.distanceMeters)) — A:(\(item.pointA.latitude, specifier: "%.3f")), B:(\(item.pointB.latitude, specifier: "%.3f"))")
                                .font(.caption2)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            Spacer()
                            Button(role: .destructive) {
                                viewModel.removeMeasurement(id: item.id)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.top, 8)
            }
        }
        // Live update when crosshair (mapCenter) moves; observe components to avoid Equatable constraint
        .onChange(of: mapCenter.latitude, initial: false) { oldLat, newLat in
            let newCenter = CLLocationCoordinate2D(latitude: newLat, longitude: mapCenter.longitude)
            viewModel.updateMeasureLive(toCrosshair: newCenter)
        }
        .onChange(of: mapCenter.longitude, initial: false) { oldLon, newLon in
            let newCenter = CLLocationCoordinate2D(latitude: mapCenter.latitude, longitude: newLon)
            viewModel.updateMeasureLive(toCrosshair: newCenter)
        }
    }
}
