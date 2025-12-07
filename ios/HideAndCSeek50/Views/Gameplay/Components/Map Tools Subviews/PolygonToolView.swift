//
//  PolygonToolView.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 12/7/25.
//

import SwiftUI
import MapKit

struct PolygonToolView: View {
    @ObservedObject var viewModel: MapToolsViewModel
    @Binding var mapCenter: CLLocationCoordinate2D
    let contextItem: MKMapItem?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Instruction text
            Text("Tap 'Add Vertex' to place points at the crosshair. Need at least 3 vertices to close.")
                .font(.caption)
                .foregroundColor(.primary.opacity(0.7))
            
            // Current vertices list
            if !viewModel.polygonTool.vertices.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Vertices (\(viewModel.polygonTool.vertices.count))")
                        .font(.caption)
                        .foregroundColor(.primary.opacity(0.7))
                    
                    ForEach(Array(viewModel.polygonTool.vertices.enumerated()), id: \.offset) { index, vertex in
                        HStack(spacing: 10) {
                            Text("\(index + 1).")
                                .font(.caption2)
                                .foregroundColor(.primary.opacity(0.6))
                                .frame(width: 20, alignment: .leading)
                            Text("Lat: \(vertex.latitude, specifier: "%.5f"), Lon: \(vertex.longitude, specifier: "%.5f")")
                                .font(.caption2)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            Spacer()
                            Button(role: .destructive) {
                                viewModel.removePolygonVertex(at: index)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.vertical, 8)
            }
            
            // Color picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Polygon Color:")
                    .font(.caption)
                    .foregroundColor(.primary.opacity(0.7))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(MapToolsViewModel.colorOptions.enumerated()), id: \.offset) { index, color in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.polygonColorIndex = index
                                }
                            }) {
                                Circle()
                                    .fill(color)
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.black, lineWidth: viewModel.polygonColorIndex == index ? 3 : 0)
                                    )
                                    .scaleEffect(viewModel.polygonColorIndex == index ? 1.1 : 1.0)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(4)
                    }
                }
            }
            
            // Shade outside toggle
            Toggle("Shade Outside Polygon", isOn: $viewModel.shadeOutsidePolygon)
                .font(.caption)
                .foregroundColor(.primary)
                .toggleStyle(.switch)
            
            // Action buttons
            HStack(spacing: 12) {
                Button {
                    let coord = contextItem?.location.coordinate ?? mapCenter
                    viewModel.addPolygonVertex(coord)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle")
                        Text("Add Vertex")
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.primary.opacity(0.12))
                    .foregroundColor(.primary)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                Button {
                    viewModel.closeAndAddPolygon()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Close Polygon")
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(MapToolsViewModel.colorOptions[viewModel.polygonColorIndex].opacity(0.35))
                    .foregroundColor(.primary)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.polygonTool.vertices.count < 3)
                .opacity(viewModel.polygonTool.vertices.count < 3 ? 0.5 : 1.0)
                
                Button(role: .destructive) {
                    viewModel.clearPolygonTool()
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
            
            // Saved polygons list
            if !viewModel.polygonItems.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Saved Polygons")
                        .font(.caption)
                        .foregroundColor(.primary.opacity(0.7))
                    ForEach(viewModel.polygonItems) { item in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(MapToolsViewModel.colorOptions[min(item.colorIndex, MapToolsViewModel.colorOptions.count - 1)])
                                .frame(width: 10, height: 10)
                            Text("\(item.vertices.count) vertices")
                                .font(.caption2)
                                .foregroundColor(.primary)
                            Spacer()
                            Button(role: .destructive) {
                                viewModel.removePolygon(id: item.id)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption)
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
    }
}


// MARK: - Export/Sync Section
