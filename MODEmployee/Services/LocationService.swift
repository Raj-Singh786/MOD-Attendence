//
//  LocationService.swift
//  MODEmployee
//
//  Created by Rajpal singh on 12/10/26.
//

//import Foundation
//import CoreLocation
//
///// Service for location acquisition and geofence validation
//class LocationService: NSObject {
//    
//    // MARK: - Types
//    
//    enum LocationError: LocalizedError {
//        case permissionDenied
//        case permissionRestricted
//        case locationDisabled
//        case timeout
//        case insufficientAccuracy(required: Double, actual: Double)
//        case unknown(String)
//        
//        var errorDescription: String? {
//            switch self {
//            case .permissionDenied:
//                return "Location permission denied"
//            case .permissionRestricted:
//                return "Location permission restricted"
//            case .locationDisabled:
//                return "Location services disabled"
//            case .timeout:
//                return "Location acquisition timed out"
//            case .insufficientAccuracy(let required, let actual):
//                return "Location accuracy insufficient. Required: \(required)m, Actual: \(actual)m"
//            case .unknown(let message):
//                return message
//            }
//        }
//    }
//    
//    // MARK: - Properties
//    
//    private let locationManager = CLLocationManager()
//    private var locationCompletion: ((Result<LocationData, LocationError>) -> Void)?
//    private var timeoutTimer: Timer?
//    
//    /// Pending location request stored when authorization is not yet determined.
//    /// Once authorization is granted, this request is processed.
//    private var pendingLocationRequest: (timeout: TimeInterval, completion: (Result<LocationData, LocationError>) -> Void)?
//    
//    var currentLocation: LocationData?
//    var authorizationStatus: CLAuthorizationStatus {
//        return locationManager.authorizationStatus
//    }
//    
//    // MARK: - Initialization
//    
//    static let shared = LocationService()
//    
//    private override init() {
//        super.init()
//        setupLocationManager()
//    }
//    
//    private func setupLocationManager() {
//        locationManager.delegate = self
//        print("LocationService: Location manager setup with delegate: \(locationManager.delegate != nil)")
//        locationManager.desiredAccuracy = kCLLocationAccuracyBest
//        locationManager.distanceFilter = 10.0 // meters
//    }
//    
//    // MARK: - Public Methods
//    
//    /// Request location authorization
//    func requestAuthorization() {
//        locationManager.requestWhenInUseAuthorization()
//    }
//    
//    /// Check if location services are enabled and authorized
//    func isLocationAvailable() -> Bool {
//        guard CLLocationManager.locationServicesEnabled() else {
//            return false
//        }
//        
//        let status = locationManager.authorizationStatus
//        return status == .authorizedWhenInUse || status == .authorizedAlways
//    }
//    
//    /// Get current location with timeout using async/await.
//    /// The continuation is always resumed to avoid deadlocks,
//    /// even if authorization is denied or disabled.
//    func getCurrentLocation(timeout: TimeInterval = AppConfig.locationTimeout) async throws -> LocationData {
//        return try await withCheckedThrowingContinuation { continuation in
//            getCurrentLocation(timeout: timeout) { result in
//                switch result {
//                case .success(let location):
//                    continuation.resume(returning: location)
//                case .failure(let error):
//                    continuation.resume(throwing: error)
//                }
//            }
//        }
//    }
//    
//    /// Get current location with completion handler.
//    ///
//    /// If authorization is not determined, requests authorization and stores the request.
//    /// Once authorization status changes, the stored request is processed.
//    ///
//    /// - Parameters:
//    ///   - timeout: Time interval to wait before timing out.
//    ///   - completion: Completion handler with Result containing location or error.
//    func getCurrentLocation(timeout: TimeInterval = AppConfig.locationTimeout, completion: @escaping (Result<LocationData, LocationError>) -> Void) {
//        print("LocationService: getCurrentLocation called. Services enabled: \(CLLocationManager.locationServicesEnabled()), status: \(locationManager.authorizationStatus.rawValue)")
//        
//        // Fail any existing locationCompletion to ensure only one request active
//        if let existingCompletion = locationCompletion {
//            existingCompletion(.failure(.unknown("Cancelled by new request")))
//            locationCompletion = nil
//            pendingLocationRequest = nil
//        }
//        
//        let status = locationManager.authorizationStatus
//        let isAvailable = (status == .authorizedWhenInUse || status == .authorizedAlways)
//        
//        if status == .notDetermined {
//            // Authorization not yet determined: request authorization and store the request
//            self.pendingLocationRequest = (timeout, completion)
//            locationManager.requestWhenInUseAuthorization()
//            return
//        }
//        
//        guard isAvailable else {
//            // Authorization denied or restricted or location disabled: immediately return failure
//            let error: LocationError
//            if status == .denied {
//                error = .permissionDenied
//            } else if status == .restricted {
//                error = .permissionRestricted
//            } else {
//                error = .locationDisabled
//            }
//            completion(.failure(error))
//            return
//        }
//        
//        // Authorized: proceed to request location updates
//        self.locationCompletion = completion
//        
//        locationManager.startUpdatingLocation()
//        
//        timeoutTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
//            self?.handleTimeout()
//        }
//    }
//    
//    /// Cancel current location request and clear any pending location requests.
//    func cancelCurrentRequest() {
//        locationManager.stopUpdatingLocation()
//        timeoutTimer?.invalidate()
//        timeoutTimer = nil
//        // If there's a pending completion, fail it so any async caller is resumed.
//        if let completion = locationCompletion {
//            completion(.failure(.timeout)) // Prevents continuation leaks
//        }
//        locationCompletion = nil
//        pendingLocationRequest = nil
//    }
//    
//    // MARK: - Geofence Validation
//    
//    /// Check if a location is within the allowed radius of a site
//    func isWithinGeofence(location: LocationData, site: AttendanceSite) -> Bool {
//        let siteLocation = CLLocation(latitude: site.latitude, longitude: site.longitude)
//        let userLocation = location.clLocation
//        
//        let distance = userLocation.distance(from: siteLocation)
//        return distance <= site.allowedRadius
//    }
//    
//    /// Calculate distance from a location to a site
//    func distanceToSite(location: LocationData, site: AttendanceSite) -> CLLocationDistance {
//        let siteLocation = CLLocation(latitude: site.latitude, longitude: site.longitude)
//        let userLocation = location.clLocation
//        return userLocation.distance(from: siteLocation)
//    }
//    
//    /// Validate location accuracy
//    func validateAccuracy(_ location: LocationData, threshold: Double = AppConfig.locationAccuracyThreshold) -> Bool {
//        return location.horizontalAccuracy <= threshold
//    }
//    
//    // MARK: - Private Methods
//    
//    private func handleTimeout() {
//        print("LocationService: Location acquisition timed out.")
//        cancelCurrentRequest()
//        locationCompletion?(.failure(.timeout))
//    }
//}
//
//// MARK: - CLLocationManagerDelegate
//
//extension LocationService: CLLocationManagerDelegate {
//    
//    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
//        print("LocationService: didUpdateLocations called with \(locations.count) locations.")
//        if let location = locations.last {
//            print("LocationService: Latest location: lat=\(location.coordinate.latitude), lon=\(location.coordinate.longitude), accuracy=\(location.horizontalAccuracy), timestamp=\(location.timestamp)")
//        }
//        
//        guard let location = locations.last else { return }
//        
//        // Check accuracy
//        if location.horizontalAccuracy > AppConfig.locationAccuracyThreshold {
//            // Keep trying for better accuracy
//            return
//        }
//        
//        // Convert to LocationData
//        let locationData = LocationData(from: location)
//        
//        // Update current location
//        self.currentLocation = locationData
//        
//        // Return result
//        locationCompletion?(.success(locationData))
//        
//        // Stop location updates and timers
//        cancelCurrentRequest()
//    }
//    
//    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
//        print("LocationService: didFailWithError called: \(error)")
//        cancelCurrentRequest()
//        
//        let locationError: LocationError
//        if let clError = error as? CLError {
//            switch clError.code {
//            case .denied:
//                locationError = .permissionDenied
//            case .locationUnknown:
//                locationError = .unknown("Location unknown")
//            default:
//                locationError = .unknown(clError.localizedDescription)
//            }
//        } else {
//            locationError = .unknown(error.localizedDescription)
//        }
//        
//        locationCompletion?(.failure(locationError))
//    }
//    
//    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
//        print("LocationService: Authorization changed to \(manager.authorizationStatus.rawValue); pending request: \(self.pendingLocationRequest != nil)")
//        
//        let status = manager.authorizationStatus
//        
//        // If authorization is granted and a pending location request exists, process it
//        if (status == .authorizedWhenInUse || status == .authorizedAlways), let pending = self.pendingLocationRequest {
//            self.pendingLocationRequest = nil
//            getCurrentLocation(timeout: pending.timeout, completion: pending.completion)
//        }
//        // If authorization is denied or restricted, fail the pending request immediately
//        else if status == .denied || status == .restricted {
//            if let pending = self.pendingLocationRequest {
//                self.pendingLocationRequest = nil
//                let error: LocationError = (status == .denied) ? .permissionDenied : .permissionRestricted
//                pending.completion(.failure(error))
//            }
//        }
//        // For other states, no action needed here
//    }
//}


import Foundation
import CoreLocation

/// Service for location acquisition and geofence validation
final class LocationService: NSObject {

    // MARK: - Types

    enum LocationError: LocalizedError {
        case permissionDenied
        case permissionRestricted
        case locationDisabled
        case timeout
        case cancelled
        case mockLocationDetected
        case insufficientAccuracy(required: Double, actual: Double)
        case unknown(String)

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "Location permission denied"
            case .permissionRestricted:
                return "Location permission restricted"
            case .locationDisabled:
                return "Location services disabled"
            case .timeout:
                return "Location acquisition timed out"
            case .cancelled:
                return "Location request was cancelled"
            case .mockLocationDetected:
                return "Mock location detected. Please disable fake GPS apps."
            case .insufficientAccuracy(let required, let actual):
                return "Location accuracy insufficient. Required: \(required)m, Actual: \(actual)m"
            case .unknown(let message):
                return message
            }
        }
    }

    private typealias Completion = (Result<LocationData, LocationError>) -> Void

    // MARK: - Properties

    private let locationManager: CLLocationManager
    private var timeoutTimer: Timer?

    /// The active request. It is ONLY ever invoked through `finish(_:)`,
    /// which clears it before calling, so it can never fire twice.
    private var locationCompletion: Completion?

    /// Request stored while authorization is still `.notDetermined`.
    /// Processed once the user answers the permission prompt.
    private var pendingLocationRequest: (timeout: TimeInterval, completion: Completion)?

    var currentLocation: LocationData?

    var authorizationStatus: CLAuthorizationStatus {
        return locationManager.authorizationStatus
    }

    // MARK: - Initialization

    static let shared = LocationService()

    private override init() {
        // CLLocationManager delivers delegate callbacks on the thread it was
        // created on, so make sure it is created on the main thread.
        if Thread.isMainThread {
            locationManager = CLLocationManager()
        } else {
            locationManager = DispatchQueue.main.sync { CLLocationManager() }
        }
        super.init()
        setupLocationManager()
    }

    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10.0 // meters
        log("Location manager setup with delegate: \(locationManager.delegate != nil)")
    }

    // MARK: - Public Methods

    /// Request location authorization
    func requestAuthorization() {
        runOnMain { [weak self] in
            self?.locationManager.requestWhenInUseAuthorization()
        }
    }

    /// Check if location services are enabled and authorized
    func isLocationAvailable() -> Bool {
        guard CLLocationManager.locationServicesEnabled() else {
            return false
        }
        let status = locationManager.authorizationStatus
        return status == .authorizedWhenInUse || status == .authorizedAlways
    }

    /// Get current location with timeout using async/await.
    /// The underlying completion is guaranteed to fire exactly once,
    /// so the continuation is resumed exactly once.
    func getCurrentLocation(timeout: TimeInterval = AppConfig.locationTimeout) async throws -> LocationData {
        return try await withCheckedThrowingContinuation { continuation in
            getCurrentLocation(timeout: timeout) { result in
                switch result {
                case .success(let location):
                    continuation.resume(returning: location)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Get current location with completion handler.
    ///
    /// If authorization is not determined, requests authorization and stores the request.
    /// Once authorization status changes, the stored request is processed.
    ///
    /// - Parameters:
    ///   - timeout: Time interval to wait before timing out.
    ///   - completion: Completion handler with Result containing location or error.
    func getCurrentLocation(timeout: TimeInterval = AppConfig.locationTimeout,
                            completion: @escaping (Result<LocationData, LocationError>) -> Void) {
        // Timer and CLLocationManager must be used from the main thread.
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.getCurrentLocation(timeout: timeout, completion: completion)
            }
            return
        }

        log("getCurrentLocation called. Services enabled: \(CLLocationManager.locationServicesEnabled()), status: \(locationManager.authorizationStatus.rawValue)")

        // Fail any existing request exactly once, so only one request is ever active.
        failExistingRequests(with: .cancelled)

        let status = locationManager.authorizationStatus

        switch status {
        case .notDetermined:
            // Store the request and ask for permission; resumed in locationManagerDidChangeAuthorization.
            pendingLocationRequest = (timeout, completion)
            locationManager.requestWhenInUseAuthorization()

        case .authorizedWhenInUse, .authorizedAlways:
            startLocationRequest(timeout: timeout, completion: completion)

        case .denied:
            completion(.failure(.permissionDenied))

        case .restricted:
            completion(.failure(.permissionRestricted))

        @unknown default:
            completion(.failure(.locationDisabled))
        }
    }

    /// Cancel current location request and clear any pending location requests.
    /// Any waiting caller (including async/await callers) is resumed exactly once.
    func cancelCurrentRequest() {
        runOnMain { [weak self] in
            self?.failExistingRequests(with: .cancelled)
        }
    }

    // MARK: - Geofence Validation

    /// Check if a location is within the allowed radius of a site
    func isWithinGeofence(location: LocationData, site: AttendanceSite) -> Bool {
        let siteLocation = CLLocation(latitude: site.latitude, longitude: site.longitude)
        let userLocation = location.clLocation

        let distance = userLocation.distance(from: siteLocation)
        return distance <= site.allowedRadius
    }

    /// Calculate distance from a location to a site
    func distanceToSite(location: LocationData, site: AttendanceSite) -> CLLocationDistance {
        let siteLocation = CLLocation(latitude: site.latitude, longitude: site.longitude)
        let userLocation = location.clLocation
        return userLocation.distance(from: siteLocation)
    }

    /// Validate location accuracy
    func validateAccuracy(_ location: LocationData,
                          threshold: Double = AppConfig.locationAccuracyThreshold) -> Bool {
        return location.horizontalAccuracy <= threshold
    }

    // MARK: - Private Methods

    /// Begin an authorized location request.
    private func startLocationRequest(timeout: TimeInterval, completion: @escaping Completion) {
        locationCompletion = completion

        locationManager.startUpdatingLocation()

        timeoutTimer?.invalidate()
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            self?.handleTimeout()
        }
    }

    /// Stops location updates and the timeout timer. Does NOT call any completion.
    private func stopUpdates() {
        locationManager.stopUpdatingLocation()
        timeoutTimer?.invalidate()
        timeoutTimer = nil
    }

    /// The ONLY place where `locationCompletion` is invoked.
    /// It is cleared BEFORE being called, so a second call is a harmless no-op.
    private func finish(_ result: Result<LocationData, LocationError>) {
        stopUpdates()
        guard let completion = locationCompletion else { return } // already finished
        locationCompletion = nil
        completion(result)
    }

    /// Fails both the active request and any request waiting for authorization.
    private func failExistingRequests(with error: LocationError) {
        if let pending = pendingLocationRequest {
            pendingLocationRequest = nil
            pending.completion(.failure(error))
        }
        finish(.failure(error))
    }

    private func handleTimeout() {
        log("Location acquisition timed out.")
        finish(.failure(.timeout))
    }

    private func runOnMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }

    private func log(_ message: String) {
        #if DEBUG
        print("LocationService: \(message)")
        #endif
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        log("didUpdateLocations: accuracy=\(location.horizontalAccuracy), timestamp=\(location.timestamp)")

        // Anti-spoofing: reject software-simulated locations (iOS 15+)
        if #available(iOS 15.0, *) {
            if location.sourceInformation?.isSimulatedBySoftware == true {
                finish(.failure(.mockLocationDetected))
                return
            }
        }

        // Ignore invalid, poor-accuracy, or stale (cached) fixes and keep waiting.
        guard location.horizontalAccuracy >= 0,
              location.horizontalAccuracy <= AppConfig.locationAccuracyThreshold,
              abs(location.timestamp.timeIntervalSinceNow) < 15 else {
            return
        }

        let locationData = LocationData(from: location)
        currentLocation = locationData

        // Stops updates/timer, clears the completion, then calls it once.
        finish(.success(locationData))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        log("didFailWithError: \(error)")

        let locationError: LocationError
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                locationError = .permissionDenied
            case .locationUnknown:
                // Transient: CoreLocation keeps trying; the timeout handles the worst case.
                return
            default:
                locationError = .unknown(clError.localizedDescription)
            }
        } else {
            locationError = .unknown(error.localizedDescription)
        }

        finish(.failure(locationError))
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        log("Authorization changed to \(status.rawValue); pending request: \(pendingLocationRequest != nil)")

        guard let pending = pendingLocationRequest else { return }

        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            pendingLocationRequest = nil
            startLocationRequest(timeout: pending.timeout, completion: pending.completion)

        case .denied:
            pendingLocationRequest = nil
            pending.completion(.failure(.permissionDenied))

        case .restricted:
            pendingLocationRequest = nil
            pending.completion(.failure(.permissionRestricted))

        default:
            break // .notDetermined: still waiting for the user
        }
    }
}

