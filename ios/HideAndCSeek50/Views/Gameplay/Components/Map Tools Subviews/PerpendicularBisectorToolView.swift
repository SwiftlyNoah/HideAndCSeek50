//
//  PerpendicularBisectorView.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 12/7/25.
//

import SwiftUI
import MapKit

struct PerpendicularBisectorToolView: View {
    @ObservedObject var viewModel: MapToolsViewModel
    @Binding var mapCenter: CLLocationCoordinate2D
    let contextItem: MKMapItem?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Point A")
                        .font(.caption)
                        .foregroundColor(.primary.opacity(0.7))
                    if let item = contextItem {
                        Text(item.name ?? "Selected Location")
                            .font(.caption2)
                            .foregroundColor(.primary)
                    } else {
                        Text(viewModel.bisectorTool.pointA.map { "Lat: \($0.latitude, specifier: "%.5f"), Lon: \($0.longitude, specifier: "%.5f")" } ?? "Not set")
                            .font(.caption2)
                            .foregroundColor(.primary)
                    }
                }
                Spacer()
                if contextItem == nil {
                    Button {
                        viewModel.setBisectorPointA(mapCenter)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "target")
                            Text("Set A from Crosshair")
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
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Point B")
                        .font(.caption)
                        .foregroundColor(.primary.opacity(0.7))
                    Text(viewModel.bisectorTool.pointB.map { "Lat: \($0.latitude, specifier: "%.5f"), Lon: \($0.longitude, specifier: "%.5f")" } ?? "Not set")
                        .font(.caption2)
                        .foregroundColor(.primary)
                }
                Spacer()
                Button {
                    viewModel.setBisectorPointB(mapCenter)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "target")
                        Text("Set B from Crosshair")
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.primary.opacity(0.12))
                    .foregroundColor(.primary)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Bisector Color:")
                    .font(.caption)
                    .foregroundColor(.primary.opacity(0.7))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(MapToolsViewModel.colorOptions.enumerated()), id: \.offset) { index, color in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.bisectorColorIndex = index
                                }
                            }) {
                                Circle()
                                    .fill(color)
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary, lineWidth: viewModel.bisectorColorIndex == index ? 3 : 0)
                                    )
                                    .scaleEffect(viewModel.bisectorColorIndex == index ? 1.1 : 1.0)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(4)
                    }
                }
            }
            
            Toggle(isOn: Binding(
                get: { viewModel.bisectorTool.fillPositiveSide },
                set: { viewModel.toggleBisectorSide($0) }
            )) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                        .foregroundColor(.primary.opacity(0.8))
                    Text("Side")
                        .foregroundColor(.primary)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: .blue))
            
            HStack(spacing: 12) {
                Button {
                    viewModel.addCurrentBisector()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Bisector")
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(MapToolsViewModel.colorOptions[viewModel.bisectorColorIndex].opacity(0.35))
                    .foregroundColor(.primary)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                // Optional: clear current overlays
                Button {
                    viewModel.clearBisector()
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
            
            Text("Choose A and B, then press Compute to draw the perpendicular bisector and shade a side.")
                .font(.caption)
                .foregroundColor(.primary.opacity(0.7))
            
            if !viewModel.bisectorItems.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Saved Bisectors")
                        .font(.caption)
                        .foregroundColor(.primary.opacity(0.7))
                    ForEach(viewModel.bisectorItems) { item in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(MapToolsViewModel.colorOptions[min(item.colorIndex, MapToolsViewModel.colorOptions.count - 1)])
                                .frame(width: 10, height: 10)
                            Text("A:(\(item.pointA.latitude, specifier: "%.3f")), B:(\(item.pointB.latitude, specifier: "%.3f"))")
                                .font(.caption2)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            Spacer()
                            Button(role: .destructive) {
                                viewModel.removeBisector(id: item.id)
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
    }
}
