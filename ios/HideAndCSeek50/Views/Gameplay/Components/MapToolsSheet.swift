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

    // Game context for export/sync
    let gameId: String?
    let playerTeam: Team?
    let playerUID: String?
    let playerName: String?

    init(viewModel: MapToolsViewModel,
         mapCenter: Binding<CLLocationCoordinate2D>,
         onDismiss: @escaping () -> Void,
         contextItem: MKMapItem? = nil,
         gameId: String? = nil,
         playerTeam: Team? = nil,
         playerUID: String? = nil,
         playerName: String? = nil) {
        self.viewModel = viewModel
        self._mapCenter = mapCenter
        self.onDismiss = onDismiss
        self.contextItem = contextItem
        self.gameId = gameId
        self.playerTeam = playerTeam
        self.playerUID = playerUID
        self.playerName = playerName
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
                    // Train Lines Toggle
                    if contextItem == nil {
                        TrainLinesToggleView(viewModel: viewModel)
                    }
                
                    // Municipalities group
                    if contextItem == nil {
                        MunicipalitiesSectionView(viewModel: viewModel)
                            .animation(.easeInOut(duration: 0.2), value: viewModel.municipalitiesExpanded)
                    }
                    
                    // Radius group
                    RadiusSectionView(viewModel: viewModel, mapCenter: $mapCenter, contextItem: contextItem)
                        .animation(.easeInOut(duration: 0.2), value: viewModel.radiusExpanded)
                    
                    // Measure Distance Tool
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
                    
                    // Perpendicular Bisector Tool
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
                    
                    // Custom Polygon Tool
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
                    
                    // Point Tool
                    DisclosureGroup(isExpanded: $viewModel.pointExpanded) {
                        PointToolView(
                            viewModel: viewModel,
                            mapCenter: $mapCenter,
                            contextItem: contextItem
                        )
                        .padding(16)
                        .background(Color.primary.opacity(0.1))
                        .cornerRadius(12)
                    } label: {
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.primary.opacity(0.8))
                            Text("Point Marker")
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .accentColor(.clear)

                    // Export/Sync Section (only show if no context item and game context is available)
                    if contextItem == nil, let gameId = gameId, let playerTeam = playerTeam,
                       let playerUID = playerUID {
                        ExportSyncSectionView(
                            viewModel: viewModel,
                            gameId: gameId,
                            playerTeam: playerTeam,
                            playerUID: playerUID,
                            playerName: playerName ?? "Guest"
                        )
                    }
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
