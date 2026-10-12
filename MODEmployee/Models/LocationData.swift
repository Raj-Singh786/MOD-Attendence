//
//  LocationData.swift
//  MODEmployee
//
//  Created by Rajpal singh on 12/10/26.
//

import Foundation
import CoreLocation

struct LocationData: Equatable {
    let latitude: Double
    let longitude: Double
    let horizontalAccuracy: Double
    let timestamp: Date
    
    var isValid: Bool {
        return horizontalAccuracy >= 0 && horizontalAccuracy <= AppConfig.locationAccuracyThreshold
    }
    
    var clLocation: CLLocation {
        return CLLocation(latitude: latitude, longitude: longitude)
    }
    
    init(latitude: Double, longitude: Double, horizontalAccuracy: Double, timestamp: Date = Date()) {
        self.latitude = latitude
        self.longitude = longitude
        self.horizontalAccuracy = horizontalAccuracy
        self.timestamp = timestamp
    }
    
    init(from location: CLLocation) {
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.horizontalAccuracy = location.horizontalAccuracy
        self.timestamp = location.timestamp
    }
}
