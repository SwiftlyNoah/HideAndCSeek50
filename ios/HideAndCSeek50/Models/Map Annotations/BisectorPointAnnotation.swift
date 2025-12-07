//
//  BisectorPointAnnotation.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 12/7/25.
//

import MapKit

final class BisectorPointAnnotation: NSObject, MKAnnotation {
    enum Kind { case a, b }
    let kind: Kind
    dynamic var coordinate: CLLocationCoordinate2D
    var title: String? {
        switch kind {
        case .a: return "Point A"
        case .b: return "Point B"
        }
    }
    init(kind: Kind, coordinate: CLLocationCoordinate2D) {
        self.kind = kind
        self.coordinate = coordinate
        super.init()
    }
}
