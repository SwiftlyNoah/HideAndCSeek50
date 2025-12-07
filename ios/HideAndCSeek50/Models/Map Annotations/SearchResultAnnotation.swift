//
//  SearchResultAnnotation.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 12/7/25.
//

import MapKit

class SearchResultAnnotation: NSObject, MKAnnotation {
    let name: String
    let coordinate: CLLocationCoordinate2D
    let isSelected: Bool
    
    var title: String? {
        return name
    }
    
    init(name: String, coordinate: CLLocationCoordinate2D, isSelected: Bool) {
        self.name = name
        self.coordinate = coordinate
        self.isSelected = isSelected
        super.init()
    }
}
