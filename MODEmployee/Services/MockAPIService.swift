//
//  MockAPIService.swift
//  MODEmployee
//
//  Created by Rajpal singh on 12/10/26.
//

import Foundation

/// Mock API service for development and testing
/// This simulates backend responses when the real API is not available
class MockAPIService {
    
    static let shared = MockAPIService()
    
    private init() {}
    
    // MARK: - Mock Data
    
    private let mockEmployee = Employee(
        id: "emp-001",
        name: "John Doe",
        employeeIdentifier: "EMP001",
        email: "john.doe@example.com",
        site: AttendanceSite(
            id: "site-001",
            name: "Main Office",
            latitude: 28.674563232638263,
            longitude: 77.15138479517233,
            allowedRadius: 100.0
        )
    )
    
    // MARK: - Authentication
    
    func mockLogin(username: String, password: String) async throws -> LoginResponse {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Simple mock validation
        guard !username.isEmpty, !password.isEmpty else {
            throw APIError(code: "INVALID_CREDENTIALS", message: "Invalid username or password", details: nil)
        }
        
        return LoginResponse(
            accessToken: "mock_access_token_\(UUID().uuidString)",
            refreshToken: "mock_refresh_token_\(UUID().uuidString)",
            expiresIn: 3600,
            employee: mockEmployee
        )
    }
    
    func mockRefreshToken(refreshToken: String) async throws -> RefreshTokenResponse {
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        return RefreshTokenResponse(
            accessToken: "mock_access_token_\(UUID().uuidString)",
            refreshToken: "mock_refresh_token_\(UUID().uuidString)",
            expiresIn: 3600
        )
    }
    
    func mockGetEmployeeProfile() async throws -> EmployeeProfileResponse {
        try await Task.sleep(nanoseconds: 500_000_000)
        
        return EmployeeProfileResponse(employee: mockEmployee)
    }
    
    // MARK: - Verification Session
    
    func mockCreateVerificationSession() async throws -> VerificationSessionResponse {
        try await Task.sleep(nanoseconds: 500_000_000)
        
        return VerificationSessionResponse(
            sessionId: "session_\(UUID().uuidString)",
            expiresAt: Date().addingTimeInterval(300), // 5 minutes
            nonce: UUID().uuidString
        )
    }
    
    // MARK: - Attendance Verification
    
    func mockSubmitAttendance(request: AttendanceVerificationRequest) async throws -> AttendanceVerificationResponse {
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Simulate basic validation
        guard request.livenessScore >= AppConfig.livenessThreshold else {
            throw APIError(code: "LIVENESS_FAILED", message: "Liveness verification failed", details: nil)
        }
        
        return AttendanceVerificationResponse(
            success: true,
            attendanceId: "att_\(UUID().uuidString)",
            timestamp: Date(),
            message: "Attendance recorded successfully",
            errorCode: nil
        )
    }
    
    // MARK: - Attendance Status
    
    func mockGetAttendanceStatus() async throws -> AttendanceStatusResponse {
        try await Task.sleep(nanoseconds: 500_000_000)
        
        return AttendanceStatusResponse(
            isCheckedIn: false,
            lastCheckInTime: nil,
            lastCheckOutTime: nil
        )
    }
}
