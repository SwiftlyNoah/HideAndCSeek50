//
//  MapToolsViewModel.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 11/28/25.
//

import SwiftUI
import MapKit
import BottomSheet
internal import Combine

@MainActor
class MapToolsViewModel: ObservableObject {
    // Map tools state
    @Published var mapToolsBottomSheetPosition: BottomSheetPosition = .hidden
    @Published var showTrainLines: Bool = true
    
    // Region selection
    @Published var selectedRegions: Set<String> = []
    @Published var visibleRegions: Set<String> = [] // Track which regions are actually rendered
    @Published var regionColors: [String: Bool] = [:] // Track color per region (true = red, false = green)
    @Published var circleItems: [CircleOverlayItem] = []
    
    // UI State
    @Published var selectedColorIndex: Int = 2 // Default to yellow (index 2)
    @Published var selectedMilesIndex: Int = 2
    @Published var municipalitiesExpanded: Bool = false
    @Published var radiusExpanded: Bool = false
    
    // Color options - static so it can be shared between views
    static let colorOptions: [Color] = [.red, .orange, .yellow, .green, .teal, .blue, .purple]
    static let colorOptionsUIKit: [UIColor] = [
        .systemRed, .systemOrange, .systemYellow, .systemGreen, 
        .systemTeal, .systemBlue, .systemPurple
    ]
    
    let milesOptions: [Double] = [0.5, 1, 3, 5, 10]
    let allRegionNames = MassachusettsRegions.allRegionNames
    
    // Computed properties for green and red regions
    var greenRegions: Set<String> {
        Set(visibleRegions.filter { regionColors[$0] == false })
    }
    
    var redRegions: Set<String> {
        Set(visibleRegions.filter { regionColors[$0] == true })
    }
    
    // MARK: - Region Management Functions
    
    func toggleGreen(_ regionName: String) {
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
    
    func toggleRed(_ regionName: String) {
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
    
    func showAllGreen() {
        withAnimation(.easeInOut(duration: 0.2)) {
            visibleRegions = Set(allRegionNames)
            for region in allRegionNames {
                regionColors[region] = false // green
            }
        }
    }
    
    func showAllRed() {
        withAnimation(.easeInOut(duration: 0.2)) {
            visibleRegions = Set(allRegionNames)
            for region in allRegionNames {
                regionColors[region] = true // red
            }
        }
    }
    
    func hideAll() {
        withAnimation(.easeInOut(duration: 0.2)) {
            visibleRegions.removeAll()
            regionColors.removeAll()
        }
    }
    
    // MARK: - Circle Management Functions
    
    func addCircleAtCenter(_ mapCenter: CLLocationCoordinate2D) {
        let miles = milesOptions[selectedMilesIndex]
        let meters = miles * 1609.34
        let item = CircleOverlayItem(center: mapCenter, radiusMeters: meters, colorIndex: selectedColorIndex)
        withAnimation(.easeInOut(duration: 0.18)) {
            circleItems.append(item)
        }
    }
    
    func removeCircle(withId id: UUID) {
        withAnimation(.easeInOut(duration: 0.16)) {
            circleItems.removeAll(where: { $0.id == id })
        }
    }
    
    // MARK: - Color and Distance Accessors
    var selectedColor: Color {
        Self.colorOptions[selectedColorIndex]
    }
    
    var selectedMiles: Double {
        milesOptions[selectedMilesIndex]
    }
}
