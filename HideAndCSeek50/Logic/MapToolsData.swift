//
//  MapToolsData.swift
//  HideAndCSeek50
//
//  Created on 12/5/25.
//

import Foundation
import MapKit

/// Contains all map tools data that can be saved and shared with teammates
struct MapToolsData: Codable {
    // Metadata
    let savedBy: String // UID of the player who saved this
    let savedByName: String // Display name of the player who saved this
    let savedAt: Date
    
    // Map tools state
    var showTrainLines: Bool
    var selectedRegions: [String] // Using array instead of Set for Codable
    var regionColors: [String: Bool] // regionName -> isRed (true = red, false = green)
    
    // Radius circles
    var circles: [CircleOverlayItem]
    
    // Bisectors
    var bisectors: [BisectorOverlayItem]
    
    // Distance measurements
    var measurements: [DistanceOverlayItem]
    
    // Polygons
    var polygons: [PolygonOverlayItem]
    
    // Points
    var points: [PointOverlayItem]
    
    init(
        savedAt: Date = Date(),
        savedBy: String,
        savedByName: String,
        circles: [CircleOverlayItem] = [],
        bisectors: [BisectorOverlayItem] = [],
        measurements: [DistanceOverlayItem] = [],
        polygons: [PolygonOverlayItem] = [],
        points: [PointOverlayItem] = [],
        selectedRegions: [String] = [],
        regionColors: [String: Bool] = [:],
        showTrainLines: Bool = true
    ) {
        self.savedBy = savedBy
        self.savedByName = savedByName
        self.savedAt = savedAt
        self.showTrainLines = showTrainLines
        self.selectedRegions = selectedRegions
        self.regionColors = regionColors
        self.circles = circles
        self.bisectors = bisectors
        self.measurements = measurements
        self.polygons = polygons
        self.points = points
    }
    
    /// Create MapToolsData from a MapToolsViewModel
    static func fromViewModel(
        _ viewModel: MapToolsViewModel,
        savedBy: String,
        savedByName: String
    ) -> MapToolsData {
        return MapToolsData(
            savedAt: Date(),
            savedBy: savedBy,
            savedByName: savedByName,
            circles: viewModel.circleItems,
            bisectors: viewModel.bisectorItems,
            measurements: viewModel.measureItems,
            polygons: viewModel.polygonItems,
            points: viewModel.pointItems,
            selectedRegions: Array(viewModel.selectedRegions),
            regionColors: viewModel.regionColors,
            showTrainLines: viewModel.showTrainLines
        )
    }
    
    /// Apply this data to a MapToolsViewModel
    func applyToViewModel(_ viewModel: MapToolsViewModel) {
        viewModel.showTrainLines = showTrainLines
        viewModel.selectedRegions = Set(selectedRegions)
        viewModel.visibleRegions = Set(selectedRegions)
        viewModel.regionColors = regionColors
        viewModel.circleItems = circles
        viewModel.bisectorItems = bisectors
        viewModel.measureItems = measurements
        viewModel.polygonItems = polygons
        viewModel.pointItems = points
    }
    
    // Custom Codable implementation to handle Date encoding/decoding
    enum CodingKeys: String, CodingKey {
        case savedBy, savedByName, savedAt
        case showTrainLines, selectedRegions, regionColors
        case circles, bisectors, measurements, polygons, points
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        savedBy = try container.decode(String.self, forKey: .savedBy)
        savedByName = try container.decode(String.self, forKey: .savedByName)
        
        // Handle Date decoding - could be TimeInterval or Date
        if let timestamp = try? container.decode(TimeInterval.self, forKey: .savedAt) {
            savedAt = Date(timeIntervalSince1970: timestamp)
        } else {
            savedAt = try container.decode(Date.self, forKey: .savedAt)
        }
        
        // Decode with defaults for optional fields
        showTrainLines = try container.decodeIfPresent(Bool.self, forKey: .showTrainLines) ?? true
        selectedRegions = try container.decodeIfPresent([String].self, forKey: .selectedRegions) ?? []
        regionColors = try container.decodeIfPresent([String: Bool].self, forKey: .regionColors) ?? [:]
        
        // Decode arrays with empty defaults if missing
        circles = try container.decodeIfPresent([CircleOverlayItem].self, forKey: .circles) ?? []
        bisectors = try container.decodeIfPresent([BisectorOverlayItem].self, forKey: .bisectors) ?? []
        measurements = try container.decodeIfPresent([DistanceOverlayItem].self, forKey: .measurements) ?? []
        polygons = try container.decodeIfPresent([PolygonOverlayItem].self, forKey: .polygons) ?? []
        points = try container.decodeIfPresent([PointOverlayItem].self, forKey: .points) ?? []
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(savedBy, forKey: .savedBy)
        try container.encode(savedByName, forKey: .savedByName)
        try container.encode(savedAt.timeIntervalSince1970, forKey: .savedAt)
        try container.encode(showTrainLines, forKey: .showTrainLines)
        try container.encode(selectedRegions, forKey: .selectedRegions)
        try container.encode(regionColors, forKey: .regionColors)
        try container.encode(circles, forKey: .circles)
        try container.encode(bisectors, forKey: .bisectors)
        try container.encode(measurements, forKey: .measurements)
        try container.encode(polygons, forKey: .polygons)
        try container.encode(points, forKey: .points)
    }
}

/// Lightweight info about saved map tools (for displaying in a list)
struct SavedMapToolsInfo: Codable {
    let savedBy: String
    let savedByName: String
    let savedAt: Date
    
    init(savedBy: String, savedByName: String, savedAt: Date) {
        self.savedBy = savedBy
        self.savedByName = savedByName
        self.savedAt = savedAt
    }
    
    // Custom Codable implementation to handle Date encoding/decoding
    enum CodingKeys: String, CodingKey {
        case savedBy, savedByName, savedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        savedBy = try container.decode(String.self, forKey: .savedBy)
        savedByName = try container.decode(String.self, forKey: .savedByName)
        
        // Handle Date decoding - could be TimeInterval or Date
        if let timestamp = try? container.decode(TimeInterval.self, forKey: .savedAt) {
            savedAt = Date(timeIntervalSince1970: timestamp)
        } else {
            savedAt = try container.decode(Date.self, forKey: .savedAt)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(savedBy, forKey: .savedBy)
        try container.encode(savedByName, forKey: .savedByName)
        try container.encode(savedAt.timeIntervalSince1970, forKey: .savedAt)
    }
}
