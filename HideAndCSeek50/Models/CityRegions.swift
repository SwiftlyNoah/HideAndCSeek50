import Foundation
import MapKit
import CoreLocation

struct RegionData {
    let name: String
    let polygon: MKPolygon
}

// NOTE: Subclassing MKPolygon can cause runtime issues with MapKit's internal
// implementations (class cluster / factory methods). Instead of subclassing,
// we attach region names to the polygon via the `title` property inherited
// from `MKShape`.

struct MassachusettsRegions {
    // Load named regions first (these are IdentifiablePolygon instances)
    static let regionsByName: [String: MKPolygon] = loadRegionsWithNames(named: "ma")

    // Use the named regions (IdentifiablePolygon) as the hidable areas so
    // each overlay carries its `regionName` for renderer-based styling.
    static let hidableAreas: [MKPolygon] = Array(regionsByName.values)

    static let allRegionNames: [String] = loadRegionNames(named: "ma")
    
    static let exampleCircleOverlay: MKCircle = {
        let center = CLLocationCoordinate2D(latitude: 42.361366, longitude: -71.062035)
        let radiusInMeters: CLLocationDistance = 1000 // 1 km
        return MKCircle(center: center, radius: radiusInMeters)
    }()

    // Always-on MBTA line overlays loaded from Rapid_Transit_Routes.geojson (WGS84 lon/lat)
    static let mbtaLineOverlays: [MKPolyline] = loadMBTALinesGeoJSON(named: "Rapid_Transit_Routes")
    
    static func loadPolygonsFromGeoJSON(named name: String) -> [MKPolygon] {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else { return [] }
        do {
            let data = try Data(contentsOf: url)
            #if DEBUG
            print("[CityRegions] Loaded \(data.count) bytes from \(url.lastPathComponent)")
            #endif
            let obj = try JSONSerialization.jsonObject(with: data, options: [])
              guard let dict = obj as? [String: Any],
                  let features = dict["features"] as? [[String: Any]] else { return [] }

            func asDouble(_ any: Any) -> Double? {
                if let d = any as? Double { return d }
                if let n = any as? NSNumber { return n.doubleValue }
                if let s = any as? String, let d = Double(s) { return d }
                return nil
            }

            var polygons: [MKPolygon] = []
            var parsedFeatureCount = 0
            for feature in features {
                parsedFeatureCount += 1
                guard let geometry = feature["geometry"] as? [String: Any],
                      let type = geometry["type"] as? String,
                      let coordsAny = geometry["coordinates"] as? [Any] else { continue }

                if type == "Polygon" {
                    // coordsAny is an array of rings: [ ring1, ring2, ... ]
                    for ringAny in coordsAny {
                        guard let ring = ringAny as? [Any] else { continue }
                        var ringCoords: [CLLocationCoordinate2D] = []
                        for coordAny in ring {
                            guard let pair = coordAny as? [Any], pair.count >= 2,
                                  let lon = asDouble(pair[0]), let lat = asDouble(pair[1]) else { continue }
                            ringCoords.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
                        }
                        if ringCoords.count > 0 {
                            let polygon = ringCoords.withUnsafeBufferPointer { ptr -> MKPolygon in
                                return MKPolygon(coordinates: ptr.baseAddress!, count: ringCoords.count)
                            }
                            polygons.append(polygon)
                        }
                    }
                } else if type == "MultiPolygon" {
                    // coordsAny is an array of polygons, each polygon is an array of rings
                    for polyAny in coordsAny {
                        guard let poly = polyAny as? [Any] else { continue }
                        for ringAny in poly {
                            guard let ring = ringAny as? [Any] else { continue }
                            var ringCoords: [CLLocationCoordinate2D] = []
                            for coordAny in ring {
                                guard let pair = coordAny as? [Any], pair.count >= 2,
                                      let lon = asDouble(pair[0]), let lat = asDouble(pair[1]) else { continue }
                                ringCoords.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
                            }
                            if ringCoords.count > 0 {
                                let polygon = ringCoords.withUnsafeBufferPointer { ptr -> MKPolygon in
                                    return MKPolygon(coordinates: ptr.baseAddress!, count: ringCoords.count)
                                }
                                polygons.append(polygon)
                            }
                        }
                    }
                }
            }

            #if DEBUG
            print("[CityRegions] Parsed \(parsedFeatureCount) features; created \(polygons.count) polygons from \(name).json")
            #endif
            return polygons
        } catch {
    #if DEBUG
            print("[CityRegions] Error loading/parsing GeoJSON (\(name)): \(error)")
    #endif
            return []
        }
    }
    
    static func loadRegionsWithNames(named name: String) -> [String: MKPolygon] {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else { return [:] }
        do {
            let data = try Data(contentsOf: url)
            let obj = try JSONSerialization.jsonObject(with: data, options: [])
            guard let dict = obj as? [String: Any],
                  let features = dict["features"] as? [[String: Any]] else { return [:] }

            func asDouble(_ any: Any) -> Double? {
                if let d = any as? Double { return d }
                if let n = any as? NSNumber { return n.doubleValue }
                if let s = any as? String, let d = Double(s) { return d }
                return nil
            }

            var regionsByName: [String: MKPolygon] = [:]
            for feature in features {
                guard let properties = feature["properties"] as? [String: Any],
                      let regionName = properties["NAME"] as? String else { continue }
                guard let geometry = feature["geometry"] as? [String: Any],
                      let type = geometry["type"] as? String,
                      let coordsAny = geometry["coordinates"] as? [Any] else { continue }

                if type == "Polygon" {
                    // Get the first ring (exterior boundary)
                    if let firstRing = coordsAny.first as? [Any] {
                        var ringCoords: [CLLocationCoordinate2D] = []
                        for coordAny in firstRing {
                            guard let pair = coordAny as? [Any], pair.count >= 2,
                                  let lon = asDouble(pair[0]), let lat = asDouble(pair[1]) else { continue }
                            ringCoords.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
                        }
                        if ringCoords.count > 0 {
                            let polygon = ringCoords.withUnsafeBufferPointer { ptr -> MKPolygon in
                                let basePolygon = MKPolygon(coordinates: ptr.baseAddress!, count: ringCoords.count)
                                basePolygon.title = regionName
                                return basePolygon
                            }
                            regionsByName[regionName] = polygon
                        }
                    }
                } else if type == "MultiPolygon" {
                    // Get the first polygon's first ring
                    if let firstPoly = coordsAny.first as? [Any],
                       let firstRing = firstPoly.first as? [Any] {
                        var ringCoords: [CLLocationCoordinate2D] = []
                        for coordAny in firstRing {
                            guard let pair = coordAny as? [Any], pair.count >= 2,
                                  let lon = asDouble(pair[0]), let lat = asDouble(pair[1]) else { continue }
                            ringCoords.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
                        }
                        if ringCoords.count > 0 {
                            let polygon = ringCoords.withUnsafeBufferPointer { ptr -> MKPolygon in
                                let basePolygon = MKPolygon(coordinates: ptr.baseAddress!, count: ringCoords.count)
                                basePolygon.title = regionName
                                return basePolygon
                            }
                            regionsByName[regionName] = polygon
                        }
                    }
                }
            }

            #if DEBUG
            print("[CityRegions] Loaded \(regionsByName.count) named regions from \(name).json")
            #endif
            return regionsByName
        } catch {
    #if DEBUG
            print("[CityRegions] Error loading named regions from GeoJSON (\(name)): \(error)")
    #endif
            return [:]
        }
    }
    
    static func loadRegionNames(named name: String) -> [String] {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else { return [] }
        do {
            let data = try Data(contentsOf: url)
            let obj = try JSONSerialization.jsonObject(with: data, options: [])
            guard let dict = obj as? [String: Any],
                  let features = dict["features"] as? [[String: Any]] else { return [] }

            var names: [String] = []
            for feature in features {
                guard let properties = feature["properties"] as? [String: Any],
                      let regionName = properties["NAME"] as? String else { continue }
                names.append(regionName)
            }

            return names.sorted()
        } catch {
            return []
        }
    }

    // Load MBTA linework (LineString / MultiLineString) as MKPolyline overlays
    static func loadMBTALines(named name: String) -> [MKPolyline] {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else { return [] }
        do {
            let data = try Data(contentsOf: url)
            let obj = try JSONSerialization.jsonObject(with: data, options: [])
            guard let dict = obj as? [String: Any],
                  let features = dict["features"] as? [[String: Any]] else { return [] }

            func asDouble(_ any: Any) -> Double? {
                if let d = any as? Double { return d }
                if let n = any as? NSNumber { return n.doubleValue }
                if let s = any as? String, let d = Double(s) { return d }
                return nil
            }

            var polylines: [MKPolyline] = []
            for feature in features {
                guard let geometry = feature["geometry"] as? [String: Any],
                      let type = geometry["type"] as? String,
                      let coordsAny = geometry["coordinates"] as? [Any] else { continue }

                if type == "LineString" {
                    var coords: [CLLocationCoordinate2D] = []
                    for coordAny in coordsAny {
                        guard let pair = coordAny as? [Any], pair.count >= 2,
                              let lon = asDouble(pair[0]), let lat = asDouble(pair[1]) else { continue }
                        coords.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
                    }
                    if !coords.isEmpty {
                        let polyline = coords.withUnsafeBufferPointer { ptr -> MKPolyline in
                            MKPolyline(coordinates: ptr.baseAddress!, count: coords.count)
                        }
                        polylines.append(polyline)
                    }
                } else if type == "MultiLineString" {
                    for lineAny in coordsAny {
                        guard let line = lineAny as? [Any] else { continue }
                        var coords: [CLLocationCoordinate2D] = []
                        for coordAny in line {
                            guard let pair = coordAny as? [Any], pair.count >= 2,
                                  let lon = asDouble(pair[0]), let lat = asDouble(pair[1]) else { continue }
                            coords.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
                        }
                        if !coords.isEmpty {
                            let polyline = coords.withUnsafeBufferPointer { ptr -> MKPolyline in
                                MKPolyline(coordinates: ptr.baseAddress!, count: coords.count)
                            }
                            polylines.append(polyline)
                        }
                    }
                }
            }

            #if DEBUG
            print("[CityRegions] Loaded MBTA lines: \(polylines.count) polylines from \(name).json")
            #endif
            return polylines
        } catch {
            #if DEBUG
            print("[CityRegions] Error loading MBTA lines (\(name)): \(error)")
            #endif
            return []
        }
    }

    // Variant for files with .geojson extension
    static func loadMBTALinesGeoJSON(named name: String) -> [MKPolyline] {
        guard let url = Bundle.main.url(forResource: name, withExtension: "geojson") else { return [] }
        do {
            let data = try Data(contentsOf: url)
            let obj = try JSONSerialization.jsonObject(with: data, options: [])
            guard let dict = obj as? [String: Any],
                  let features = dict["features"] as? [[String: Any]] else { return [] }

            func asDouble(_ any: Any) -> Double? {
                if let d = any as? Double { return d }
                if let n = any as? NSNumber { return n.doubleValue }
                if let s = any as? String, let d = Double(s) { return d }
                return nil
            }

            var polylines: [MKPolyline] = []
            for feature in features {
                let properties = feature["properties"] as? [String: Any]
                let routeID = (properties?["route_id"] as? String) ?? (properties?["route"] as? String)
                guard let geometry = feature["geometry"] as? [String: Any],
                      let type = geometry["type"] as? String,
                      let coordsAny = geometry["coordinates"] as? [Any] else { continue }

                if type == "LineString" {
                    var coords: [CLLocationCoordinate2D] = []
                    for coordAny in coordsAny {
                        guard let pair = coordAny as? [Any], pair.count >= 2,
                              let lon = asDouble(pair[0]), let lat = asDouble(pair[1]) else { continue }
                        coords.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
                    }
                    if !coords.isEmpty {
                        let polyline = coords.withUnsafeBufferPointer { ptr -> MKPolyline in
                            let line = MKPolyline(coordinates: ptr.baseAddress!, count: coords.count)
                            line.title = routeID
                            return line
                        }
                        polylines.append(polyline)
                    }
                } else if type == "MultiLineString" {
                    for lineAny in coordsAny {
                        guard let line = lineAny as? [Any] else { continue }
                        var coords: [CLLocationCoordinate2D] = []
                        for coordAny in line {
                            guard let pair = coordAny as? [Any], pair.count >= 2,
                                  let lon = asDouble(pair[0]), let lat = asDouble(pair[1]) else { continue }
                            coords.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
                        }
                        if !coords.isEmpty {
                            let polyline = coords.withUnsafeBufferPointer { ptr -> MKPolyline in
                                let line = MKPolyline(coordinates: ptr.baseAddress!, count: coords.count)
                                line.title = routeID
                                return line
                            }
                            polylines.append(polyline)
                        }
                    }
                }
            }

            #if DEBUG
            print("[CityRegions] Loaded MBTA lines: \(polylines.count) polylines from \(name).geojson")
            #endif
            return polylines
        } catch {
            #if DEBUG
            print("[CityRegions] Error loading MBTA lines (\(name).geojson): \(error)")
            #endif
            return []
        }
    }
}


