//
//  MapToolsView.swift
//  HideAndCSeek50
//
//  Created by Jack Ploof on 11/24/25.
//

import SwiftUI
import MapKit

struct MapToolsView: View {
    @Binding var selectedRegions: Set<String>
    @Binding var visibleRegions: Set<String> // Track visible overlays
    @Binding var regionColors: [String: Bool] // Track colors (true = red, false = green)
    @Binding var mapCenter: CLLocationCoordinate2D
    @Binding var circleItems: [CircleOverlayItem]

    private let allRegionNames = MassachusettsRegions.allRegionNames

    @State private var circleIsRed: Bool = true
    @State private var selectedMilesIndex: Int = 2
    @State private var municipalitiesExpanded: Bool = false
    @State private var radiusExpanded: Bool = false
    @State private var radiusCopyExpanded: Bool = false
    private let milesOptions: [Double] = [0.5, 1, 3, 5, 10]
    
    // Track green and red selections separately
    private var greenRegions: Set<String> {
        Set(visibleRegions.filter { regionColors[$0] == false })
    }
    
    private var redRegions: Set<String> {
        Set(visibleRegions.filter { regionColors[$0] == true })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Map Tools")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Tap to toggle overlays")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(16)
                    .border(Color(.systemGray5), width: 1)

                    // Municipalities group
                    DisclosureGroup(isExpanded: $municipalitiesExpanded) {
                        VStack(spacing: 14) {
                            HStack(spacing: 12) {
                                Button(action: showAllGreen) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.caption)
                                        Text("All Green")
                                            .font(.caption)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Color.green.opacity(0.1))
                                    .foregroundColor(.green)
                                    .cornerRadius(8)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.green.opacity(0.3), lineWidth: 1))
                                }

                                Button(action: hideAll) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "eye.slash.fill")
                                            .font(.caption)
                                        Text("Clear All")
                                            .font(.caption)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Color.gray.opacity(0.1))
                                    .foregroundColor(.gray)
                                    .cornerRadius(8)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                                }

                                Button(action: showAllRed) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.caption)
                                        Text("All Red")
                                            .font(.caption)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Color.red.opacity(0.1))
                                    .foregroundColor(.red)
                                    .cornerRadius(8)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red.opacity(0.3), lineWidth: 1))
                                }
                            }

                            if allRegionNames.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "map")
                                        .font(.title)
                                        .foregroundColor(.secondary)
                                    Text("No regions available")
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                            } else {
                                ScrollView(.vertical, showsIndicators: true) {
                                    VStack(spacing: 8) {
                                        ForEach(allRegionNames, id: \.self) { regionName in
                                            regionToggleButton(regionName)
                                                .transition(.opacity.combined(with: .move(edge: .top)))
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                                .frame(maxHeight: municipalitiesExpanded ? 600 : 300)
                            }
                        }
                        .padding(12)
                    } label: {
                        HStack {
                            Image(systemName: "building.2.fill")
                            Text("Municipalities")
                            Spacer()
                        }
                        .padding(12)
                    }
                    .animation(.easeInOut(duration: 0.22), value: municipalitiesExpanded)
                    .accentColor(.primary)
                    .padding(.horizontal, 12)

                    Divider()
                        .padding(.horizontal, 12)

                    // Radius group
                    DisclosureGroup(isExpanded: $radiusExpanded) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                Button(action: { withAnimation { circleIsRed = true } }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: circleIsRed ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(.red)
                                        Text("Red")
                                            .foregroundColor(.primary)
                                    }
                                }
                                Button(action: { withAnimation { circleIsRed = false } }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: !circleIsRed ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(.green)
                                        Text("Green")
                                            .foregroundColor(.primary)
                                    }
                                }
                                Spacer()
                            }

                            Picker("Radius (miles)", selection: $selectedMilesIndex) {
                                ForEach(milesOptions.indices, id: \.self) { idx in
                                    Text("\(milesOptions[idx], specifier: "%.1f") mi").tag(idx)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())

                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Center:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("Lat: \(mapCenter.latitude, specifier: "%.5f"), Lon: \(mapCenter.longitude, specifier: "%.5f")")
                                        .font(.caption2)
                                        .foregroundColor(.primary)
                                }
                                Spacer()
                                Button(action: addCircleAtCenter) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "plus.circle.fill")
                                        Text("Add Circle")
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(Color.blue.opacity(0.30))
                                    .cornerRadius(8)
                                }
                            }

                            if !circleItems.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(Array(circleItems.enumerated()), id: \.element.id) { _, item in
                                        HStack {
                                            Circle()
                                                .fill(item.isRed ? Color.red : Color.green)
                                                .frame(width: 12, height: 12)
                                            Text("\(item.radiusMeters / 1609.34, specifier: "%.1f") mi — Lat:\(item.center.latitude, specifier: "%.3f")")
                                                .font(.caption)
                                                .foregroundColor(.primary)
                                            Spacer()
                                            Button(role: .destructive) {
                                                withAnimation(.easeInOut(duration: 0.16)) {
                                                    circleItems.removeAll(where: { $0.id == item.id })
                                                }
                                            } label: {
                                                Image(systemName: "trash")
                                            }
                                        }
                                        .padding(.vertical, 6)
                                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                                    }
                                }
                                .padding(.top, 4)
                            }
                        }
                        .padding(12)
                    } label: {
                        HStack {
                            Image(systemName: "circle.fill")
                            Text("Radius")
                            Spacer()
                        }
                        .padding(12)
                    }
                    .animation(.easeInOut(duration: 0.22), value: radiusExpanded)
                    .accentColor(.primary)
                    .padding(.horizontal, 12)

                    Divider()
                        .padding(.horizontal, 12)

                    DisclosureGroup(isExpanded: $radiusCopyExpanded) {
                        EmptyView()
                    } label: {
                        HStack {
                            Image(systemName: "ruler.fill")
                            Text("Line Tool")
                            Spacer()
                        }
                        .padding(12)
                    }
                    .animation(.easeInOut(duration: 0.22), value: radiusCopyExpanded)
                    .accentColor(.primary)
                    .padding(.horizontal, 12)

                    Spacer(minLength: 16)
                }
                .padding(.vertical, 12)
            }
            .navigationBarHidden(true)
        }
    }

    private func regionToggleButton(_ regionName: String) -> some View {
        HStack(spacing: 12) {
            // Green checkbox on the left
            Button(action: { toggleGreen(regionName) }) {
                Image(systemName: greenRegions.contains(regionName) ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundColor(.green)
            }
            .buttonStyle(PlainButtonStyle())

            Text(regionName)
                .font(.body)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Red checkbox on the right
            Button(action: { toggleRed(regionName) }) {
                Image(systemName: redRegions.contains(regionName) ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundColor(.red)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.systemGray5), lineWidth: 1))
    }

    private func toggleGreen(_ regionName: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if greenRegions.contains(regionName) {
                // Remove green
                visibleRegions.remove(regionName)
                regionColors.removeValue(forKey: regionName)
            } else {
                // Add green (remove red if it exists)
                visibleRegions.insert(regionName)
                regionColors[regionName] = false
            }
        }
    }
    
    private func toggleRed(_ regionName: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if redRegions.contains(regionName) {
                // Remove red
                visibleRegions.remove(regionName)
                regionColors.removeValue(forKey: regionName)
            } else {
                // Add red (remove green if it exists)
                visibleRegions.insert(regionName)
                regionColors[regionName] = true
            }
        }
    }

    private func showAllGreen() {
        withAnimation(.easeInOut(duration: 0.2)) {
            visibleRegions = Set(allRegionNames)
            for region in allRegionNames {
                regionColors[region] = false // green
            }
        }
    }

    private func showAllRed() {
        withAnimation(.easeInOut(duration: 0.2)) {
            visibleRegions = Set(allRegionNames)
            for region in allRegionNames {
                regionColors[region] = true // red
            }
        }
    }

    private func hideAll() {
        withAnimation(.easeInOut(duration: 0.2)) {
            visibleRegions.removeAll()
            regionColors.removeAll()
        }
    }

    private func addCircleAtCenter() {
        let miles = milesOptions[selectedMilesIndex]
        let meters = miles * 1609.34
        let item = CircleOverlayItem(center: mapCenter, radiusMeters: meters, isRed: circleIsRed)
        withAnimation(.easeInOut(duration: 0.18)) {
            circleItems.append(item)
            radiusExpanded = true
        }
    }
}

#Preview {
    @Previewable @State var selected = Set<String>()
    @Previewable @State var visible = Set<String>()
    @Previewable @State var colors: [String: Bool] = [:]
    @Previewable @State var center = CLLocationCoordinate2D(latitude: 42.3601, longitude: -71.0589)
    @Previewable @State var circles: [CircleOverlayItem] = []

    return MapToolsView(selectedRegions: $selected, visibleRegions: $visible, regionColors: $colors, mapCenter: $center, circleItems: $circles)
}

