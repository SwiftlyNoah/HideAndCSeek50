//
//  MeasurePointAnnotation.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 12/7/25.
//

import MapKit

final class MeasurePointAnnotation: NSObject, MKAnnotation {
    enum Kind { case a }
    let kind: Kind
    dynamic var coordinate: CLLocationCoordinate2D
    var title: String? { "Measure Point" }
    init(kind: Kind, coordinate: CLLocationCoordinate2D) {
        self.kind = kind
        self.coordinate = coordinate
        super.init()
    }
}
