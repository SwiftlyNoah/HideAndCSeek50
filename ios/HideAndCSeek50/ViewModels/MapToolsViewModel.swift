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
    @Published var useCustomRadius: Bool = false
    @Published var customRadiusMiles: Double = 1.0
    
    // Bisector variables
    @Published var bisectorTool = BisectorToolItem()
    @Published var bisectorExpanded: Bool = false
    @Published var bisectorColorIndex: Int = 5
    @Published var bisectorItems: [BisectorOverlayItem] = []
    @Published var refreshToken: Bool = false
    
    // Distance Measuring variables
    @Published var measureTool = MeasureToolItem()
    @Published var measureExpanded: Bool = false
    @Published var measureColorIndex: Int = 5
    @Published var measureItems: [DistanceOverlayItem] = []
    
    // Polygon variables
    @Published var polygonTool = PolygonToolItem()
    @Published var polygonExpanded: Bool = false
    @Published var polygonColorIndex: Int = 3 // Default to green
    @Published var shadeOutsidePolygon: Bool = false
    @Published var polygonItems: [PolygonOverlayItem] = []
    
    // Point variables
    @Published var pointExpanded: Bool = false
    @Published var pointColorIndex: Int = 0 // Default to red
    @Published var pointSymbolIndex: Int = 0 // Default to first symbol
    @Published var pointItems: [PointOverlayItem] = []
    
    // Pending location from chat
    @Published var pendingChatLocation: PendingChatLocation? = nil

    // Color options - static so it can be shared between views
    static let colorOptions: [Color] = [.red, .orange, .yellow, .green, .teal, .blue, .purple]
    static let colorOptionsUIKit: [UIColor] = [
        .systemRed, .systemOrange, .systemYellow, .systemGreen,
            .systemTeal, .systemBlue, .systemPurple
    ]
    
    // Symbol options for points
    static let symbolOptions: [String] = [
        "mappin.circle.fill",
        "star.fill",
        "flag.fill",
        "exclamationmark.triangle.fill",
        "checkmark.circle.fill",
        "xmark.circle.fill",
        "questionmark.circle.fill",
        "heart.fill"
    ]
    
    let milesOptions: [Double] = [0.25, 0.5, 1, 3, 5, 10, 25, 50, 100]
    let allRegionNames: [String]
    let regionsByName: [String: MKPolygon]
    let hidableRegions: [MKPolygon]
    let cityTrainLines: [MKPolyline]
    
    // MARK: - Initialization
    
    init(city: GameCity) {
        self.allRegionNames = city.allRegionNames
        self.regionsByName = city.regionsByName
        self.hidableRegions = city.hidableAreas
        self.cityTrainLines = city.trainLines
    }
    
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
    
    func addCircle(
            at center: CLLocationCoordinate2D,
            radiusMeters: CLLocationDistance? = nil,
            colorIndex: Int? = nil,
            shadeOutside: Bool? = nil
        ) {
        let meters = radiusMeters ?? (radiusSelectedMiles * 1609.34)
        let color = colorIndex ?? radiusColorIndex
        let shade = shadeOutside ?? shadeOutsideCircle
        let item = CircleOverlayItem(
            center: center,
            radiusMeters: meters,
            colorIndex: color,
            shadeOutside: shade
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
        useCustomRadius ? max(customRadiusMiles, 0) : milesOptions[radiusMilesIndex]
    }
    
    var bisectorSelectedColor: UIColor {
        Self.colorOptionsUIKit[min(max(bisectorColorIndex, 0), Self.colorOptionsUIKit.count - 1)]
    }
    
    // MARK: - Bisector Tool Functions
    
    func setBisectorPointA(_ coord: CLLocationCoordinate2D) {
        bisectorTool.pointA = coord
        refreshToken.toggle()
    }
    
    func setBisectorPointB(_ coord: CLLocationCoordinate2D) {
        bisectorTool.pointB = coord
        refreshToken.toggle()
    }
    
    func toggleBisectorSide(_ fillPositive: Bool) {
        bisectorTool.fillPositiveSide = fillPositive
    }
    
    func computeBisector() {
        recomputeBisectorLive()
        refreshToken.toggle()
    }
    
    func clearBisector() {
        bisectorTool.pointA = nil
        bisectorTool.pointB = nil
        bisectorTool.halfPlanePolygon = nil
        bisectorTool.bisectorPolyline = nil
        refreshToken.toggle()
    }
    
    private func recomputeBisectorLive() {
        guard let a = bisectorTool.pointA, let b = bisectorTool.pointB else {
            bisectorTool.halfPlanePolygon = nil
            bisectorTool.bisectorPolyline = nil
            refreshToken.toggle()
            return
        }
        let (poly) = generateBisectorGeometry(pointA: a, pointB: b, fillPositive: bisectorTool.fillPositiveSide)
        bisectorTool.halfPlanePolygon = poly
        bisectorTool.bisectorPolyline = nil // do not draw a line
        refreshToken.toggle()
    }
    
    func addCurrentBisector() {
        guard let a = bisectorTool.pointA, let b = bisectorTool.pointB else { return }
        if bisectorTool.halfPlanePolygon == nil || bisectorTool.bisectorPolyline == nil {
            recomputeBisectorLive()
        }
        guard let poly = bisectorTool.halfPlanePolygon else { return }

        let id = UUID()
        poly.title = "bisector_halfplane:\(id.uuidString):\(bisectorColorIndex):\(bisectorTool.fillPositiveSide ? "pos" : "neg")"

        let item = BisectorOverlayItem(
            id: id,
            pointA: a,
            pointB: b,
            fillPositiveSide: bisectorTool.fillPositiveSide,
            colorIndex: bisectorColorIndex,
            halfPlanePolygon: poly,
            bisectorPolyline: MKPolyline()
        )
        withAnimation(.easeInOut(duration: 0.18)) {
            bisectorItems.append(item)
        }
        refreshToken.toggle()
    }

    func removeBisector(id: UUID) {
        withAnimation(.easeInOut(duration: 0.16)) {
            bisectorItems.removeAll { $0.id == id }
        }
        refreshToken.toggle()
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
    
    private func generateBisectorGeometry(pointA: CLLocationCoordinate2D,
                                          pointB: CLLocationCoordinate2D,
                                          fillPositive: Bool) -> (MKPolygon) {
        let aP = MKMapPoint(pointA)
        let bP = MKMapPoint(pointB)
        let midP = MKMapPoint(x: (aP.x + bP.x) * 0.5, y: (aP.y + bP.y) * 0.5)
        let vx = bP.x - aP.x
        let vy = bP.y - aP.y
        let len = sqrt(vx * vx + vy * vy)
        guard len > 0 else {
            let emptyPoly = MKPolygon()
            emptyPoly.title = "bisector_halfplane_live"
            return (emptyPoly)
        }
        let ux = vx / len
        let uy = vy / len
        let nx = -uy
        let ny = ux

        // Large rectangle bounds
        let extent: Double = 2_500_000
        let rectP: [MKMapPoint] = [
            MKMapPoint(x: midP.x - extent, y: midP.y - extent),
            MKMapPoint(x: midP.x + extent, y: midP.y - extent),
            MKMapPoint(x: midP.x + extent, y: midP.y + extent),
            MKMapPoint(x: midP.x - extent, y: midP.y + extent)
        ]

        // Line (midP + t*nx, midP + t*(-ny)) intersect edges
        func intersectEdge(p1: MKMapPoint, p2: MKMapPoint) -> MKMapPoint? {
            // Edge param form
            let ex = p2.x - p1.x
            let ey = p2.y - p1.y
            // Use line in param: L(t) = mid + t*(nx, ny)
            // Solve with segment p1 + s*(ex, ey)
            let denom = ex * ny - ey * nx
            if abs(denom) < 1e-9 { return nil }
            let s = ((midP.x - p1.x) * ny - (midP.y - p1.y) * nx) / denom
            if s < 0 || s > 1 { return nil }
            // t from x
            // Not strictly needed; compute intersection point
            let ix = p1.x + ex * s
            let iy = p1.y + ey * s
            return MKMapPoint(x: ix, y: iy)
        }

        var intersections: [MKMapPoint] = []
        var idxMap: [Int] = []
        for i in 0..<4 {
            if let ip = intersectEdge(p1: rectP[i], p2: rectP[(i + 1) & 3]) {
                intersections.append(ip)
                idxMap.append(i)
            }
        }
        if intersections.count < 2 {
            let emptyPoly = MKPolygon()
            let emptyLine = MKPolyline()
            emptyPoly.title = "bisector_halfplane_live"
            emptyLine.title = "bisector_line_live"
            return (emptyPoly)
        }
        let i1 = intersections[0]
        let i2 = intersections[1]
        let eA = idxMap[0]
        let eB = idxMap[1]

        var polyA: [MKMapPoint] = [i1]
        var v = (eA + 1) & 3
        while v != ((eB + 1) & 3) {
            polyA.append(rectP[v])
            v = (v + 1) & 3
        }
        polyA.append(rectP[(eB + 1) & 3])
        polyA.append(i2)

        var polyB: [MKMapPoint] = [i2]
        v = (eB + 1) & 3
        while v != ((eA + 1) & 3) {
            polyB.append(rectP[v])
            v = (v + 1) & 3
        }
        polyB.append(rectP[(eA + 1) & 3])
        polyB.append(i1)

        let cA = aP
        let cB = bP
        let vUnit = MKMapPoint(x: ux, y: uy)
        let dA = (cA.x - midP.x) * vUnit.x + (cA.y - midP.y) * vUnit.y
        let dB = (cB.x - midP.x) * vUnit.x + (cB.y - midP.y) * vUnit.y
        let chosen = fillPositive ? (dA >= dB ? polyA : polyB) : (dA < dB ? polyA : polyB)

        let coords = chosen.map { $0.coordinate }
        let polygon = coords.withUnsafeBufferPointer {
            MKPolygon(coordinates: $0.baseAddress!, count: coords.count)
        }
        polygon.title = "bisector_halfplane_live"

        return (polygon)
    }
    
    // MARK: - Distance Measuring Tool
    
    
    func updateMeasureLive(toCrosshair crosshair: CLLocationCoordinate2D) {
        // Only compute if A is set
        guard let a = measureTool.pointA else {
            measureTool.polyline = nil
            measureTool.distanceMeters = nil
            return
        }
        let coords = [a, crosshair]
        let line = coords.withUnsafeBufferPointer {
            MKPolyline(coordinates: $0.baseAddress!, count: 2)
        }
        line.title = "measure_line_live"
        measureTool.polyline = line

        let d = CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: crosshair.latitude, longitude: crosshair.longitude))
        measureTool.distanceMeters = d
        refreshToken.toggle()
    }
    
    func setMeasurePointA(_ coord: CLLocationCoordinate2D) {
        measureTool.pointA = coord
        recomputeMeasureLive()
        refreshToken.toggle()
    }

    func clearMeasure() {
        measureTool.pointA = nil
        measureTool.pointB = nil
        measureTool.polyline = nil
        measureTool.distanceMeters = nil
        refreshToken.toggle()
    }

    func addCurrentMeasurement() {
        guard let a = measureTool.pointA, let b = measureTool.pointB else { return }
        let distance = CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))

        let id = UUID()
        let coords = [a, b]
        let line = coords.withUnsafeBufferPointer {
            MKPolyline(coordinates: $0.baseAddress!, count: 2)
        }
        line.title = "measure_line:\(id.uuidString):\(measureColorIndex)"

        let item = DistanceOverlayItem(
            id: id,
            pointA: a,
            pointB: b,
            colorIndex: measureColorIndex,
            distanceMeters: distance,
            polyline: line
        )
        withAnimation(.easeInOut(duration: 0.18)) {
            measureItems.append(item)
        }
        refreshToken.toggle()
    }

    func removeMeasurement(id: UUID) {
        withAnimation(.easeInOut(duration: 0.16)) {
            measureItems.removeAll { $0.id == id }
        }
        refreshToken.toggle()
    }

    private func recomputeMeasureLive() {
        guard let a = measureTool.pointA, let b = measureTool.pointB else {
            measureTool.polyline = nil
            measureTool.distanceMeters = nil
            return
        }
        let coords = [a, b]
        let line = coords.withUnsafeBufferPointer {
            MKPolyline(coordinates: $0.baseAddress!, count: 2)
        }
        line.title = "measure_line_live"
        measureTool.polyline = line

        let d = CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
        measureTool.distanceMeters = d
    }
    
    // MARK: - Polygon Tool
    
    func addPolygonVertex(_ coord: CLLocationCoordinate2D) {
        polygonTool.vertices.append(coord)
        refreshToken.toggle()
    }
    
    func removePolygonVertex(at index: Int) {
        guard index >= 0 && index < polygonTool.vertices.count else { return }
        polygonTool.vertices.remove(at: index)
        refreshToken.toggle()
    }
    
    func closeAndAddPolygon() {
        guard polygonTool.vertices.count >= 3 else { return }
        
        let id = UUID()
        let vertices = polygonTool.vertices
        let polygon = vertices.withUnsafeBufferPointer {
            MKPolygon(coordinates: $0.baseAddress!, count: vertices.count)
        }
        polygon.title = "polygon:\(id.uuidString):\(polygonColorIndex)"
        
        let item = PolygonOverlayItem(
            id: id,
            vertices: vertices,
            colorIndex: polygonColorIndex,
            shadeOutside: shadeOutsidePolygon,
            polygon: polygon
        )
        
        withAnimation(.easeInOut(duration: 0.18)) {
            polygonItems.append(item)
        }
        
        // Clear current vertices
        polygonTool.vertices.removeAll()
        refreshToken.toggle()
    }
    
    func removePolygon(id: UUID) {
        withAnimation(.easeInOut(duration: 0.16)) {
            polygonItems.removeAll { $0.id == id }
        }
        refreshToken.toggle()
    }
    
    func clearPolygonTool() {
        polygonTool.vertices.removeAll()
        refreshToken.toggle()
    }
    
    // MARK: - Point Tool
    
    func addPoint(
        at coordinate: CLLocationCoordinate2D,
        colorIndex: Int? = nil,
        symbolIndex: Int? = nil
    ) {
        let color = colorIndex ?? pointColorIndex
        let symbol = symbolIndex ?? pointSymbolIndex
        let item = PointOverlayItem(
            coordinate: coordinate,
            colorIndex: color,
            symbolIndex: symbol
        )
        withAnimation(.easeInOut(duration: 0.16)) {
            pointItems.append(item)
        }
        refreshToken.toggle()
    }
    
    func removePoint(id: UUID) {
        withAnimation(.easeInOut(duration: 0.16)) {
            pointItems.removeAll { $0.id == id }
        }
        refreshToken.toggle()
    }
    
    // MARK: - Pending Chat Location
    
    /// Sets a pending location from chat that can be added to the map
    func setPendingChatLocation(latitude: Double, longitude: Double, senderName: String, messageId: String) {
        pendingChatLocation = PendingChatLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            senderName: senderName,
            messageId: messageId
        )
        addPendingChatLocationAsPoint()
    }
    
    /// Adds the pending chat location as a point to the map
    func addPendingChatLocationAsPoint() {
        guard let pending = pendingChatLocation else { return }
        
        // Add the point with default red color and mappin symbol
        addPoint(
            at: pending.coordinate,
            colorIndex: 0, // Red
            symbolIndex: 0  // mappin.circle.fill
        )
        
        // Clear the pending location
        pendingChatLocation = nil
    }
    
    /// Clears the pending chat location without adding it
    func clearPendingChatLocation() {
        pendingChatLocation = nil
    }

    // MARK: - Export/Sync Map Tools

    func exportMapTools(gameId: String, playerUID: String, playerName: String) async throws {
        let mapToolsData = MapToolsData(
            savedAt: Date(),
            savedBy: playerUID,
            savedByName: playerName,
            circles: circleItems,
            bisectors: bisectorItems,
            measurements: measureItems,
            polygons: polygonItems,
            points: pointItems,
            selectedRegions: Array(selectedRegions),
            regionColors: regionColors,
            showTrainLines: showTrainLines
        )

        try await GameManager.saveMapTools(
            gameId: gameId,
            playerUID: playerUID,
            mapToolsData: mapToolsData
        )
    }

    func importMapTools(from data: MapToolsData) {
        withAnimation(.easeInOut(duration: 0.2)) {
            // Clear existing data
            circleItems.removeAll()
            bisectorItems.removeAll()
            measureItems.removeAll()
            polygonItems.removeAll()
            pointItems.removeAll()
            visibleRegions.removeAll()
            regionColors.removeAll()

            // Import new data
            circleItems = data.circles
            bisectorItems = data.bisectors
            measureItems = data.measurements
            polygonItems = data.polygons
            pointItems = data.points
            selectedRegions = Set(data.selectedRegions)
            visibleRegions = Set(data.selectedRegions)
            regionColors = data.regionColors
            showTrainLines = data.showTrainLines

            refreshToken.toggle()
        }
    }

    func clearAllMapTools() {
        withAnimation(.easeInOut(duration: 0.2)) {
            circleItems.removeAll()
            bisectorItems.removeAll()
            measureItems.removeAll()
            polygonItems.removeAll()
            pointItems.removeAll()
            visibleRegions.removeAll()
            regionColors.removeAll()
            clearBisector()
            clearMeasure()
            clearPolygonTool()
            refreshToken.toggle()
        }
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

final class MeasureToolItem: ObservableObject {
    @Published var pointA: CLLocationCoordinate2D?
    @Published var pointB: CLLocationCoordinate2D?
    @Published var polyline: MKPolyline?
    @Published var distanceMeters: Double?
}

struct PendingChatLocation: Identifiable, Equatable {
    let id: String // Message ID
    let coordinate: CLLocationCoordinate2D
    let senderName: String
    let messageId: String
    
    init(coordinate: CLLocationCoordinate2D, senderName: String, messageId: String) {
        self.id = messageId
        self.coordinate = coordinate
        self.senderName = senderName
        self.messageId = messageId
    }
    
    static func == (lhs: PendingChatLocation, rhs: PendingChatLocation) -> Bool {
        return lhs.id == rhs.id
    }
}

final class PolygonToolItem: ObservableObject {
    @Published var vertices: [CLLocationCoordinate2D] = []
}
