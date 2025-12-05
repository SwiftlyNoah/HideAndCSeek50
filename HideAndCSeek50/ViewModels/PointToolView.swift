//
//  PointToolView.swift
//  HideAndCSeek50
//
//  Created on 12/5/25.
//

import SwiftUI
import MapKit

struct PointToolView: View {
    @ObservedObject var viewModel: MapToolsViewModel
    @Binding var mapCenter: CLLocationCoordinate2D
    let contextItem: MKMapItem?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Color Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Point Color:")
                    .font(.caption)
                    .foregroundColor(.primary.opacity(0.7))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(MapToolsViewModel.colorOptions.enumerated()), id: \.offset) { index, color in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.pointColorIndex = index
                                }
                            }) {
                                Circle()
                                    .fill(color)
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary, lineWidth: viewModel.pointColorIndex == index ? 3 : 0)
                                    )
                                    .scaleEffect(viewModel.pointColorIndex == index ? 1.1 : 1.0)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(4)
                    }
                }
            }
            
            // Symbol Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Point Symbol:")
                    .font(.caption)
                    .foregroundColor(.primary.opacity(0.7))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(MapToolsViewModel.symbolOptions.enumerated()), id: \.offset) { index, symbolName in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.pointSymbolIndex = index
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.primary.opacity(0.1))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: symbolName)
                                        .font(.system(size: 20))
                                        .foregroundColor(MapToolsViewModel.colorOptions[viewModel.pointColorIndex])
                                }
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: viewModel.pointSymbolIndex == index ? 3 : 0)
                                )
                                .scaleEffect(viewModel.pointSymbolIndex == index ? 1.1 : 1.0)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(4)
                    }
                }
            }
            
            // Add Point Button
            VStack(alignment: .leading, spacing: 12) {
                Text("Add a point:")
                    .font(.caption)
                    .foregroundColor(.primary.opacity(0.7))
                
                Button(action: {
                    let coord = contextItem?.location.coordinate ?? mapCenter
                    viewModel.addPoint(at: coord)
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(MapToolsViewModel.colorOptions[viewModel.pointColorIndex])
                        if let item = contextItem {
                            Text("Place point at \(item.name ?? "selected location")")
                                .foregroundColor(.primary)
                        } else {
                            Text("Place point")
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(Color.primary.opacity(0.1))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
            
            // Existing Points List
            if !viewModel.pointItems.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Existing Points:")
                        .font(.caption)
                        .foregroundColor(.primary.opacity(0.7))
                    
                    ForEach(viewModel.pointItems) { point in
                        HStack {
                            Image(systemName: MapToolsViewModel.symbolOptions[point.symbolIndex])
                                .foregroundColor(MapToolsViewModel.colorOptions[point.colorIndex])
                                .frame(width: 30)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Lat: \(point.coordinate.latitude, specifier: "%.5f")")
                                    .font(.caption2)
                                    .foregroundColor(.primary)
                                Text("Lon: \(point.coordinate.longitude, specifier: "%.5f")")
                                    .font(.caption2)
                                    .foregroundColor(.primary)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                viewModel.removePoint(id: point.id)
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                                    .padding(8)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(10)
                        .background(Color.primary.opacity(0.05))
                        .cornerRadius(8)
                    }
                }
            }
        }
    }
}
