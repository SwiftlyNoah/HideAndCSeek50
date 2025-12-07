import Foundation

struct MapToolsData: Codable {
    let savedAt: Date
    let savedBy: String
    let savedByName: String

    // Circle/Radius Tools
    let circles: [CircleOverlayItem]

    // Bisector Tools
    let bisectors: [BisectorOverlayItem]

    // Distance Measurements
    let measurements: [DistanceOverlayItem]

    // Polygons
    let polygons: [PolygonOverlayItem]

    // Regions/Municipalities
    let selectedRegions: [String]
    let regionColors: [String: Bool]

    // Train Lines
    let showTrainLines: Bool
}

struct SavedMapToolsInfo: Codable {
    let savedBy: String
    let savedByName: String
    let savedAt: Date
}
