//
//  Employee.swift
//  MODEmployee
//
//  Created by Rajpal singh on 12/10/26.
//

import Foundation

struct Employee: Codable, Equatable {
    let id: String
    let name: String
    let employeeIdentifier: String
    let email: String?
    let site: AttendanceSite
    
    init(id: String, name: String, employeeIdentifier: String, email: String? = nil, site: AttendanceSite) {
        self.id = id
        self.name = name
        self.employeeIdentifier = employeeIdentifier
        self.email = email
        self.site = site
    }
}

struct AttendanceSite: Codable, Equatable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    let allowedRadius: Double // in meters
    
    init(id: String, name: String, latitude: Double, longitude: Double, allowedRadius: Double) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.allowedRadius = allowedRadius
    }
}
