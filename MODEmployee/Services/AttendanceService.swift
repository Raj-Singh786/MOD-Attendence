//
//  AttendanceService.swift
//  MODEmployee
//
//  Created by Rajpal singh on 12/10/26.
//

import Foundation
import CoreLocation

/// Service for attendance verification workflow with state machine
@MainActor
class AttendanceService: ObservableObject {
    
    static let shared = AttendanceService()
    
    // MARK: - Published State
    
    @Published var state: AttendanceState = .unauthenticated
    @Published var currentLocation: LocationData?
    @Published var locationStatus: String = ""
    
    // MARK: - Dependencies
    
    private let locationService = LocationService.shared
    private let authService = AuthenticationService.shared
    private var livenessProvider: LivenessProvider?
    
    private var currentSessionId: String?
    private var currentLivenessResult: LivenessResult?
    
    private init() {}
    
    // MARK: - Setup
    
    func setLivenessProvider(_ provider: LivenessProvider) {
        self.livenessProvider = provider
    }
    
    // MARK: - Attendance Flow
    
    /// Start the attendance verification flow
    func startAttendanceFlow() async {
        guard authService.isAuthenticated else {
            state = .unauthenticated
            return
        }
        
        state = .checkingLocation
        locationStatus = "Acquiring location..."
        
        do {
            // Get current location
            let location = try await locationService.getCurrentLocation()
            currentLocation = location
            
            // Validate accuracy
            guard locationService.validateAccuracy(location) else {
                state = .outsideGeofence(reason: "Location accuracy insufficient")
                locationStatus = "Location accuracy: \(Int(location.horizontalAccuracy))m (required: \(Int(AppConfig.locationAccuracyThreshold))m)"
                return
            }
            
            // Check geofence
            guard let employee = authService.currentEmployee else {
                state = .recoverableError(message: "Employee profile not found")
                return
            }
            
            if locationService.isWithinGeofence(location: location, site: employee.site) {
                let distance = locationService.distanceToSite(location: location, site: employee.site)
                locationStatus = "Within \(Int(employee.site.allowedRadius))m of \(employee.site.name) (current: \(Int(distance))m)"
                state = .readyForAttendance
            } else {
                let distance = locationService.distanceToSite(location: location, site: employee.site)
                state = .outsideGeofence(reason: "You are \(Int(distance))m from \(employee.site.name)")
                locationStatus = "Outside authorized area"
            }
        } catch {
            if let locationError = error as? LocationService.LocationError {
                state = .outsideGeofence(reason: locationError.localizedDescription)
                locationStatus = locationError.localizedDescription
            } else {
                state = .recoverableError(message: error.localizedDescription)
                locationStatus = "Location error"
            }
        }
    }
    
    /// Submit attendance verification
    func submitAttendance() async {
        guard state == .readyForAttendance else {
            return
        }
        
        guard let livenessProvider = livenessProvider else {
            state = .recoverableError(message: "Liveness provider not configured")
            return
        }
        
        state = .creatingVerificationSession
        
        do {
            // Create verification session
            let sessionId = try await createVerificationSession()
            currentSessionId = sessionId
            
            state = .startingLiveness
            
            // Perform liveness detection
            let livenessResult = try await livenessProvider.startLiveness(sessionID: sessionId)
            currentLivenessResult = livenessResult
            
            guard livenessResult.isLive else {
                state = .livenessFailed(reason: "Liveness verification failed")
                return
            }
            
            state = .submittingVerification
            
            // Submit to backend
            try await submitToBackend(livenessResult: livenessResult)
            
            state = .attendanceSuccess(timestamp: Date())
            
        } catch {
            if let livenessError = error as? LivenessError {
                state = .livenessFailed(reason: livenessError.localizedDescription)
            } else {
                state = .recoverableError(message: error.localizedDescription)
            }
        }
    }
    
    /// Retry attendance flow
    func retry() async {
        currentSessionId = nil
        currentLivenessResult = nil
        await startAttendanceFlow()
    }
    
    /// Reset to initial state
    func reset() {
        state = .unauthenticated
        currentLocation = nil
        locationStatus = ""
        currentSessionId = nil
        currentLivenessResult = nil
    }
    
    // MARK: - Private Methods
    
    private func createVerificationSession() async throws -> String {
        if AppConfig.useMockServices {
            let response = try await MockAPIService.shared.mockCreateVerificationSession()
            return response.sessionId
        } else {
            let response = try await APIClient.shared.performRequest(
                endpoint: "/attendance/verification-session",
                method: .post,
                body: VerificationSessionRequest(),
                requiresAuth: true,
                responseType: VerificationSessionResponse.self
            )
            return response.sessionId
        }
    }
    
    private func submitToBackend(livenessResult: LivenessResult) async throws {
        guard let location = currentLocation else {
            throw AttendanceError.locationNotAvailable
        }
        
        guard let employee = authService.currentEmployee else {
            throw AttendanceError.employeeNotAvailable
        }
        
        let request = AttendanceVerificationRequest(
            sessionId: livenessResult.sessionID,
            image: livenessResult.capturedImage,
            latitude: location.latitude,
            longitude: location.longitude,
            accuracy: location.horizontalAccuracy,
            timestamp: livenessResult.timestamp,
            livenessScore: livenessResult.livenessScore,
            deviceIntegrity: nil // TODO: Add App Attest when available
        )
        
        if AppConfig.useMockServices {
            let response = try await MockAPIService.shared.mockSubmitAttendance(request: request)
            guard response.success else {
                throw AttendanceError.verificationFailed(response.message)
            }
        } else {
            let response = try await APIClient.shared.performMultipartRequest(
                endpoint: "/attendance/verify",
                method: .post,
                fields: [
                    "sessionId": request.sessionId,
                    "latitude": "\(request.latitude)",
                    "longitude": "\(request.longitude)",
                    "accuracy": "\(request.accuracy)",
                    "timestamp": ISO8601DateFormatter().string(from: request.timestamp),
                    "livenessScore": "\(request.livenessScore)"
                ],
                imageData: request.image,
                imageFieldName: "image",
                requiresAuth: true,
                responseType: AttendanceVerificationResponse.self
            )
            guard response.success else {
                throw AttendanceError.verificationFailed(response.message)
            }
        }
    }
}

// MARK: - Attendance Errors

enum AttendanceError: LocalizedError {
    case locationNotAvailable
    case employeeNotAvailable
    case verificationFailed(String)
    case livenessNotConfigured
    
    var errorDescription: String? {
        switch self {
        case .locationNotAvailable:
            return "Location not available"
        case .employeeNotAvailable:
            return "Employee profile not available"
        case .verificationFailed(let message):
            return "Verification failed: \(message)"
        case .livenessNotConfigured:
            return "Liveness provider not configured"
        }
    }
}
