//
//  MapToolsSheet.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 11/28/25.
//

import SwiftUI
import MapKit

struct MapToolsSheetContent: View {
    @ObservedObject var viewModel: MapToolsViewModel
    @Binding var mapCenter: CLLocationCoordinate2D
    let onDismiss: () -> Void
    
    // Optional: if provided, this is a location-specific context
    let contextItem: MKMapItem?
    
    init(viewModel: MapToolsViewModel, 
         mapCenter: Binding<CLLocationCoordinate2D>, 
         onDismiss: @escaping () -> Void,
         contextItem: MKMapItem? = nil) {
        self.viewModel = viewModel
        self._mapCenter = mapCenter
        self.onDismiss = onDismiss
        self.contextItem = contextItem
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                if let item = contextItem {
                    Text("Map Tools: \(item.name ?? "Location")")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                } else {
                    Text("Map Tools")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Button(action: {
                    // Clear transient overlays when closing the sheet
                    viewModel.clearMeasure()
                    viewModel.clearBisector()
                    onDismiss()
                }) {
                    Image(systemName: "xmark")
                        .tint(.primary)
                        .opacity(0.7)
                        .padding(8)
                        .background(Color.primary.opacity(0.2))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            
            // Content
            ScrollView {
                VStack(spacing: 16) {
                    // Train Lines Toggle (only show if no context item)
                    if contextItem == nil {
                        TrainLinesToggleView(viewModel: viewModel)
                    }
                
                    // Municipalities group (only show if no context item)
                    if contextItem == nil {
                        MunicipalitiesSectionView(viewModel: viewModel)
                            .animation(.easeInOut(duration: 0.2), value: viewModel.municipalitiesExpanded)
                    }
                    
                    // Radius group (extracted subview)
                    RadiusSectionView(viewModel: viewModel, mapCenter: $mapCenter, contextItem: contextItem)
                        .animation(.easeInOut(duration: 0.2), value: viewModel.radiusExpanded)
                    
                    // Measure Distance Tool (NEW)
                    DisclosureGroup(isExpanded: $viewModel.measureExpanded) {
                        MeasureToolView(
                            viewModel: viewModel,
                            mapCenter: $mapCenter,
                            contextItem: contextItem
                        )
                        .padding(16)
                        .background(Color.primary.opacity(0.1))
                        .cornerRadius(12)
                    } label: {
                        HStack {
                            Image(systemName: "ruler")
                                .foregroundColor(.primary.opacity(0.8))
                            Text("Measure Distance")
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .accentColor(.clear)
                    
                    // Perpendicular Bisector Tool (extracted subview)
                    DisclosureGroup(isExpanded: $viewModel.bisectorExpanded) {
                        PerpendicularBisectorToolView(
                            viewModel: viewModel,
                            mapCenter: $mapCenter,
                            contextItem: contextItem
                        )
                        .padding(16)
                        .background(Color.primary.opacity(0.1))
                        .cornerRadius(12)
                    } label: {
                        HStack {
                            Image(systemName: "line.diagonal")
                                .foregroundColor(.primary.opacity(0.8))
                            Text("Perpendicular Bisector")
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .accentColor(.clear)
                    
                    // Custom Polygon Tool (NEW)
                    DisclosureGroup(isExpanded: $viewModel.polygonExpanded) {
                        PolygonToolView(
                            viewModel: viewModel,
                            mapCenter: $mapCenter,
                            contextItem: contextItem
                        )
                        .padding(16)
                        .background(Color.primary.opacity(0.1))
                        .cornerRadius(12)
                    } label: {
                        HStack {
                            Image(systemName: "pentagon.fill")
                                .foregroundColor(.primary.opacity(0.8))
                            Text("Custom Polygon")
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .accentColor(.clear)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .onChange(of: viewModel.radiusExpanded) { oldValue, newValue in
            // Ensure only one disclosure group is open at a time
            if newValue == true {
                viewModel.measureExpanded = false
                viewModel.bisectorExpanded = false
                viewModel.polygonExpanded = false
            }
        }
        .onChange(of: viewModel.measureExpanded) { oldValue, newValue in
            if newValue == true {
                // Ensure only one disclosure group is open at a time
                viewModel.bisectorExpanded = false
                viewModel.polygonExpanded = false
                
                // Set default point when opening if context item exists
                if let item = contextItem, viewModel.measureTool.pointA == nil {
                    let coord = item.location.coordinate
                    viewModel.setMeasurePointA(coord)
                    viewModel.updateMeasureLive(toCrosshair: mapCenter)
                }
            } else {
                // When the measure tool is collapsed, clear transient overlays
                viewModel.clearMeasure()
            }
        }
        .onChange(of: viewModel.bisectorExpanded) { oldValue, newValue in
            if newValue == true {
                viewModel.measureExpanded = false
                viewModel.polygonExpanded = false
                
                // Set default point when opening if context item exists
                if let item = contextItem, viewModel.bisectorTool.pointA == nil {
                    let coord = item.location.coordinate
                    viewModel.setBisectorPointA(coord)
                }
            } else {
                // When the bisector tool is collapsed, clear its transient points/overlays
                viewModel.clearBisector()
            }
        }
        .onChange(of: viewModel.polygonExpanded) { oldValue, newValue in
            if newValue == true {
                viewModel.measureExpanded = false
                viewModel.bisectorExpanded = false
                viewModel.municipalitiesExpanded = false
            } else {
                // Clear vertices when collapsed
                viewModel.clearPolygonTool()
            }
        }
        .onChange(of: viewModel.municipalitiesExpanded) { oldValue, newValue in
            if newValue == true {
                viewModel.measureExpanded = false
                viewModel.bisectorExpanded = false
                viewModel.polygonExpanded = false
            }
        }
    }
}

// MARK: - Perpendicular Bisector Tool
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

// MARK: - Train Lines Toggle
struct TrainLinesToggleView: View {
    @ObservedObject var viewModel: MapToolsViewModel
    var body: some View {
        HStack {
            Image(systemName: "tram.fill")
                .foregroundColor(.primary.opacity(0.8))
            Text("Train Lines")
                .foregroundColor(.primary)
            Spacer()
            Toggle("", isOn: $viewModel.showTrainLines)
                .toggleStyle(SwitchToggleStyle(tint: .green))
        }
    }
}

// MARK: - Municipalities Section
struct MunicipalitiesSectionView: View {
    @ObservedObject var viewModel: MapToolsViewModel
    var body: some View {
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
                            .foregroundColor(.primary.opacity(0.6))
                        Text("No regions available")
                            .foregroundColor(.primary.opacity(0.6))
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
            .background(Color.primary.opacity(0.1))
            .cornerRadius(12)
        } label: {
            HStack {
                Image(systemName: "building.2.fill")
                    .foregroundColor(.primary.opacity(0.8))
                Text("Municipalities")
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.vertical, 4)
        }
        .accentColor(.clear)
    }
    private func regionToggleButton(_ regionName: String) -> some View {
        HStack(spacing: 12) {
            Button(action: { viewModel.toggleGreen(regionName) }) {
                Image(systemName: viewModel.greenRegions.contains(regionName) ? "checkmark.square.fill" : "square")
                    .font(.system(size: 18))
                    .foregroundColor(.green)
            }
            .buttonStyle(.plain)
            Text(regionName)
                .font(.body)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: { viewModel.toggleRed(regionName) }) {
                Image(systemName: viewModel.redRegions.contains(regionName) ? "checkmark.square.fill" : "square")
                    .font(.system(size: 18))
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.primary.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - Radius Section
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

// MARK: - Polygon Tool
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

