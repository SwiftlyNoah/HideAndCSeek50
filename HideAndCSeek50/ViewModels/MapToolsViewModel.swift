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
    @Published var municipalitiesExpanded: Bool = false
    
    
    // Radius variables
    @Published var radiusColorIndex: Int = 2 // Default to yellow (index 2)
    @Published var radiusMilesIndex: Int = 2
    @Published var radiusExpanded: Bool = false
    @Published var shadeOutsideCircle: Bool = false
    @Published var circleItems: [CircleOverlayItem] = []
    
    // Bisector variables
    @Published var bisectorTool = BisectorToolItem()
    @Published var bisectorExpanded: Bool = false
    @Published var bisectorColorIndex: Int = 5
    
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
        let miles = milesOptions[radiusMilesIndex]
        let meters = miles * 1609.34
        let item = CircleOverlayItem(
            center: mapCenter,
            radiusMeters: meters,
            colorIndex: radiusColorIndex,
            shadeOutside: shadeOutsideCircle
        )
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
    var radiusSelectedColor: Color {
        Self.colorOptions[radiusColorIndex]
    }
    
    var radiusSelectedMiles: Double {
        milesOptions[radiusMilesIndex]
    }
    
    var bisectorSelectedColor: UIColor {
        Self.colorOptionsUIKit[min(max(bisectorColorIndex, 0), Self.colorOptionsUIKit.count - 1)]
    }
    
    // MARK: - Bisector Tool API
    
    func setBisectorPointA(_ coord: CLLocationCoordinate2D) {
        bisectorTool.pointA = coord
    }
    
    func setBisectorPointB(_ coord: CLLocationCoordinate2D) {
        bisectorTool.pointB = coord
    }
    
    func toggleBisectorSide(_ fillPositive: Bool) {
        bisectorTool.fillPositiveSide = fillPositive
    }
    
    func computeBisector() {
        recomputeBisector()
    }
    
    func clearBisector() {
        bisectorTool.pointA = nil
        bisectorTool.pointB = nil
        bisectorTool.halfPlanePolygon = nil
        bisectorTool.bisectorPolyline = nil
    }
    
    private func recomputeBisector() {
        guard let a = bisectorTool.pointA, let b = bisectorTool.pointB else {
            bisectorTool.halfPlanePolygon = nil
            bisectorTool.bisectorPolyline = nil
            return
        }
        
        // Compute perpendicular bisector in MapKit's Web Mercator plane using MKMapPoint
        let aP = MKMapPoint(a)
        let bP = MKMapPoint(b)
        let midP = MKMapPoint(x: (aP.x + bP.x) / 2.0, y: (aP.y + bP.y) / 2.0)

        // Vector along AB and its perpendicular (bisector direction)
        let vx = bP.x - aP.x
        let vy = bP.y - aP.y
        let vLen = max(1e-9, hypot(vx, vy))
        let vUnit = (x: vx / vLen, y: vy / vLen)
        let nx = -vy
        let ny = vx
        
        // Build a big Mercator rectangle centered at midP and split by bisector
        let delta: Double = 2_000_000.0
        let rectP: [MKMapPoint] = [
            MKMapPoint(x: midP.x - delta, y: midP.y - delta), // bottom-left
            MKMapPoint(x: midP.x - delta, y: midP.y + delta), // top-left
            MKMapPoint(x: midP.x + delta, y: midP.y + delta), // top-right
            MKMapPoint(x: midP.x + delta, y: midP.y - delta)  // bottom-right
        ]

        // Intersect infinite bisector with rectangle edges (parametric)
        func intersectEdge(pA: MKMapPoint, pB: MKMapPoint) -> MKMapPoint? {
            // Edge: E(s) = pA + s*(pB-pA), s in [0,1]
            let ex = pB.x - pA.x
            let ey = pB.y - pA.y
            // Bisector: L(t) = midP + t*nUnit
            // Solve pA + s*E = midP + t*N  => two equations
            // [ex, -nx] [s] = midP.x - pA.x
            // [ey, -ny] [t] = midP.y - pA.y
            // Solve for s via Cramer's rule
            let det = ex * (-ny) - ey * (-nx)
            if abs(det) < 1e-9 { return nil }
            let rhsx = midP.x - pA.x
            let rhsy = midP.y - pA.y
            let s = (rhsx * (-ny) - rhsy * (-nx)) / det
            if s < -1e-9 || s > 1.0 + 1e-9 { return nil }
            return MKMapPoint(x: pA.x + s * ex, y: pA.y + s * ey)
        }

        // Rectangle edges in order (close the loop)
        let edges: [(MKMapPoint, MKMapPoint)] = [
            (rectP[0], rectP[1]), // left edge
            (rectP[1], rectP[2]), // top edge
            (rectP[2], rectP[3]), // right edge
            (rectP[3], rectP[0])  // bottom edge
        ]

        var inters: [MKMapPoint] = []
        for (pa, pb) in edges {
            if let ip = intersectEdge(pA: pa, pB: pb) { inters.append(ip) }
        }
        guard inters.count >= 2 else {
            bisectorTool.halfPlanePolygon = nil
            return
        }
        // Take two distinct intersections
        let i1 = inters[0]
        let i2 = inters[1]

        // Split rectangle into two polygons along i1-i2. We'll construct both loops.
        // Polygon A: i1 -> traverse rect from vertex after the edge containing i1 to edge containing i2 -> i2
        // For simplicity, build two candidate polygons by walking around rectP and inserting intersections.
        func buildPolygons() -> ([[MKMapPoint]], [[MKMapPoint]]) {
            // Find which edges produced i1/i2 to get ordering; do a small tolerance match
            func onEdge(_ p: MKMapPoint, _ e: (MKMapPoint, MKMapPoint)) -> Bool {
                let ax = e.0.x, ay = e.0.y
                let bx = e.1.x, by = e.1.y
                let vx = bx - ax, vy = by - ay
                let wx = p.x - ax, wy = p.y - ay
                let cross = abs(vx * wy - vy * wx)
                let dot = wx * vx + wy * vy
                let len2 = vx * vx + vy * vy
                return cross < 1e-3 && dot >= -1e-6 && dot <= len2 + 1e-6
            }
            var iEdgeIdx: [Int] = []
            for (idx, e) in edges.enumerated() {
                if onEdge(i1, e) { iEdgeIdx.append(idx) }
                if onEdge(i2, e) { iEdgeIdx.append(idx) }
            }
            if iEdgeIdx.count < 2 { return ([], []) }
            let eA = iEdgeIdx[0]
            let eB = iEdgeIdx[1]

            // Walk A: from i1, go forward along edges until reaching eB, then add i2
            var polyA: [MKMapPoint] = [i1]
            var v = (eA + 1) & 3
            while v != ((eB + 1) & 3) {
                polyA.append(rectP[v])
                v = (v + 1) & 3
            }
            polyA.append(rectP[(eB + 1) & 3])
            polyA.append(i2)

            // Walk B: from i2, go forward until reaching eA, then add i1
            var polyB: [MKMapPoint] = [i2]
            v = (eB + 1) & 3
            while v != ((eA + 1) & 3) {
                polyB.append(rectP[v])
                v = (v + 1) & 3
            }
            polyB.append(rectP[(eA + 1) & 3])
            polyB.append(i1)
            return ([polyA], [polyB])
        }

        let (polysA, polysB) = buildPolygons()
        guard let polyA = polysA.first, let polyB = polysB.first else {
            bisectorTool.halfPlanePolygon = nil
            return
        }

        // Choose side: use centroid dot with vUnit in Mercator space
        func centroid(_ pts: [MKMapPoint]) -> MKMapPoint {
            let sx = pts.map { $0.x }.reduce(0, +)
            let sy = pts.map { $0.y }.reduce(0, +)
            let n = Double(pts.count)
            return MKMapPoint(x: sx / n, y: sy / n)
        }
        let cA = centroid(polyA)
        let cB = centroid(polyB)
        let dA = (cA.x - midP.x) * vUnit.x + (cA.y - midP.y) * vUnit.y
        let dB = (cB.x - midP.x) * vUnit.x + (cB.y - midP.y) * vUnit.y
        let keepPositive = bisectorTool.fillPositiveSide
        let chosenP: [MKMapPoint] = keepPositive ? (dA >= dB ? polyA : polyB) : (dA < dB ? polyA : polyB)

        // Convert to coordinates and create polygon
        let coords = chosenP.map { $0.coordinate }
        let polygon = coords.withUnsafeBufferPointer { MKPolygon(coordinates: $0.baseAddress!, count: coords.count) }
        polygon.title = "bisector_halfplane:\(keepPositive ? "pos" : "neg")"
        bisectorTool.halfPlanePolygon = polygon
    }
}

final class BisectorToolItem: ObservableObject {
    @Published var pointA: CLLocationCoordinate2D?
    @Published var pointB: CLLocationCoordinate2D?
    @Published var fillPositiveSide: Bool = true // "side" toggle
    
    // A large half-plane polygon and the bisector line polyline generated from A/B
    @Published var halfPlanePolygon: MKPolygon?
    @Published var bisectorPolyline: MKPolyline?
}
