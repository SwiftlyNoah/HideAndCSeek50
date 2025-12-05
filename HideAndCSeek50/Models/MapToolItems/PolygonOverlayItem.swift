//
//  PolygonOverlayItem.swift
//  HideAndCSeek50
//
//  Created by Assistant on 12/2/25.
//

import Foundation
import MapKit

struct PolygonOverlayItem: Identifiable, Equatable, Codable {
    let id: UUID
    let vertices: [CLLocationCoordinate2D]
    let colorIndex: Int
    let shadeOutside: Bool
    let polygon: MKPolygon

    init(
        id: UUID = UUID(),
        vertices: [CLLocationCoordinate2D],
        colorIndex: Int,
        shadeOutside: Bool = false,
        polygon: MKPolygon
    ) {
        self.id = id
        self.vertices = vertices
        self.colorIndex = colorIndex
        self.shadeOutside = shadeOutside
        self.polygon = polygon
    }

    static func == (lhs: PolygonOverlayItem, rhs: PolygonOverlayItem) -> Bool {
        lhs.id == rhs.id
    }

    // Codable conformance
    enum CodingKeys: String, CodingKey {
        case id, vertices, colorIndex, shadeOutside
    }

    struct CodableCoordinate: Codable {
        let latitude: Double
        let longitude: Double
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        let codableVertices = try container.decode([CodableCoordinate].self, forKey: .vertices)
        vertices = codableVertices.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        colorIndex = try container.decode(Int.self, forKey: .colorIndex)
        shadeOutside = try container.decode(Bool.self, forKey: .shadeOutside)

        // Recreate polygon from vertices
        polygon = MKPolygon(coordinates: vertices, count: vertices.count)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        let codableVertices = vertices.map { CodableCoordinate(latitude: $0.latitude, longitude: $0.longitude) }
        try container.encode(codableVertices, forKey: .vertices)
        try container.encode(colorIndex, forKey: .colorIndex)
        try container.encode(shadeOutside, forKey: .shadeOutside)
    }
}
