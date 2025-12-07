//
//  PlayerAnnotation.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 12/7/25.
//

import MapKit

class PlayerAnnotation: NSObject, MKAnnotation {
    let displayName: String
    let coordinate: CLLocationCoordinate2D
    let team: Team
    
    var title: String? {
        return displayName
    }
    
    var subtitle: String? {
        return team.displayName
    }
    
    init(displayName: String, coordinate: CLLocationCoordinate2D, team: Team) {
        self.displayName = displayName
        self.coordinate = coordinate
        self.team = team
        super.init()
    }
}
