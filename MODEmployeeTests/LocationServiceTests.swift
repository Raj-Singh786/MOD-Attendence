//
//  LocationServiceTests.swift
//  MODEmployeeTests
//
//  Created by Rajpal singh on 12/10/26.
//

import XCTest
import CoreLocation
@testable import MODEmployee

final class LocationServiceTests: XCTestCase {
    
    var locationService: LocationService!
    
    override func setUp() {
        super.setUp()
        locationService = LocationService.shared
    }
    
    override func tearDown() {
        locationService = nil
        super.tearDown()
    }
    
    // MARK: - Geofence Tests
    
    func testIsWithinGeofence_InsideRadius() {
        let site = AttendanceSite(
            id: "site-001",
            name: "Main Office",
            latitude: 40.7128,
            longitude: -74.0060,
            allowedRadius: 100.0
        )
        
        let location = LocationData(
            latitude: 40.7128,
            longitude: -74.0060,
            horizontalAccuracy: 10.0
        )
        
        XCTAssertTrue(locationService.isWithinGeofence(location: location, site: site))
    }
    
    func testIsWithinGeofence_OutsideRadius() {
        let site = AttendanceSite(
            id: "site-001",
            name: "Main Office",
            latitude: 40.7128,
            longitude: -74.0060,
            allowedRadius: 100.0
        )
        
        // Location 200 meters away
        let location = LocationData(
            latitude: 40.7145,
            longitude: -74.0060,
            horizontalAccuracy: 10.0
        )
        
        XCTAssertFalse(locationService.isWithinGeofence(location: location, site: site))
    }
    
    func testDistanceToSite() {
        let site = AttendanceSite(
            id: "site-001",
            name: "Main Office",
            latitude: 40.7128,
            longitude: -74.0060,
            allowedRadius: 100.0
        )
        
        let location = LocationData(
            latitude: 40.7128,
            longitude: -74.0060,
            horizontalAccuracy: 10.0
        )
        
        let distance = locationService.distanceToSite(location: location, site: site)
        XCTAssertEqual(distance, 0.0, accuracy: 1.0)
    }
    
    // MARK: - Accuracy Tests
    
    func testValidateAccuracy_WithinThreshold() {
        let location = LocationData(
            latitude: 40.7128,
            longitude: -74.0060,
            horizontalAccuracy: 30.0
        )
        
        XCTAssertTrue(locationService.validateAccuracy(location, threshold: 50.0))
    }
    
    func testValidateAccuracy_ExceedsThreshold() {
        let location = LocationData(
            latitude: 40.7128,
            longitude: -74.0060,
            horizontalAccuracy: 100.0
        )
        
        XCTAssertFalse(locationService.validateAccuracy(location, threshold: 50.0))
    }
    
    func testLocationData_IsValid() {
        let validLocation = LocationData(
            latitude: 40.7128,
            longitude: -74.0060,
            horizontalAccuracy: 30.0
        )
        
        XCTAssertTrue(validLocation.isValid)
        
        let invalidLocation = LocationData(
            latitude: 40.7128,
            longitude: -74.0060,
            horizontalAccuracy: 100.0
        )
        
        XCTAssertFalse(invalidLocation.isValid)
    }
}
