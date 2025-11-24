import Foundation
import MapKit
import CoreLocation

struct MassachusettsRegions {
    static let hidableAreas: [MKPolygon] = loadPolygonsFromGeoJSON(named: "ma")
    
    static let exampleCircleOverlay: MKCircle = {
        let center = CLLocationCoordinate2D(latitude: 42.361366, longitude: -71.062035)
        let radiusInMeters: CLLocationDistance = 1000 // 1 km
        return MKCircle(center: center, radius: radiusInMeters)
    }()
    
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
                guard let properties = feature["properties"] as? [String: Any],
                      let river = properties["RIVER"] as? String,
                      river == "S" else { continue }
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
}


