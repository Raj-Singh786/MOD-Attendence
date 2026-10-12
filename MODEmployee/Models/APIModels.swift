//
//  APIModels.swift
//  MODEmployee
//
//  Created by Rajpal singh on 12/10/26.
//

import Foundation

// MARK: - Authentication

struct LoginRequest: Codable {
    let username: String
    let password: String
    let deviceId: String?
}

struct LoginResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let employee: Employee
}

struct RefreshTokenRequest: Codable {
    let refreshToken: String
}

struct RefreshTokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
}

// MARK: - Employee

struct EmployeeProfileResponse: Codable {
    let employee: Employee
}

// MARK: - Attendance Verification

struct VerificationSessionRequest: Codable {
    // Additional parameters as needed by backend
}

struct VerificationSessionResponse: Codable {
    let sessionId: String
    let expiresAt: Date
    let nonce: String?
}

struct AttendanceVerificationRequest: Codable {
    let sessionId: String
    let image: Data
    let latitude: Double
    let longitude: Double
    let accuracy: Double
    let timestamp: Date
    let livenessScore: Float
    let deviceIntegrity: String?
}

struct AttendanceVerificationResponse: Codable {
    let success: Bool
    let attendanceId: String?
    let timestamp: Date
    let message: String
    let errorCode: String?
}

// MARK: - Attendance Status

struct AttendanceStatusResponse: Codable {
    let isCheckedIn: Bool
    let lastCheckInTime: Date?
    let lastCheckOutTime: Date?
}

// MARK: - API Error

struct APIError: LocalizedError, Codable {
    let code: String
    let message: String
    let details: [String: String]?
    
    var errorDescription: String? {
        return message
    }
    
    static func unauthorized() -> APIError {
        return APIError(code: "UNAUTHORIZED", message: "Authentication required", details: nil)
    }
    
    static func networkError() -> APIError {
        return APIError(code: "NETWORK_ERROR", message: "Network connection failed", details: nil)
    }
    
    static func serverError() -> APIError {
        return APIError(code: "SERVER_ERROR", message: "Server error occurred", details: nil)
    }
    
    static func timeout() -> APIError {
        return APIError(code: "TIMEOUT", message: "Request timed out", details: nil)
    }
}

// MARK: - HTTP Status

enum HTTPStatusCode: Int {
    case success = 200
    case created = 201
    case badRequest = 400
    case unauthorized = 401
    case forbidden = 403
    case notFound = 404
    case conflict = 409
    case unprocessableEntity = 422
    case tooManyRequests = 429
    case internalServerError = 500
    case serviceUnavailable = 503
}
