//
//  AuthenticationService.swift
//  MODEmployee
//
//  Created by Rajpal singh on 12/10/26.
//

import Foundation
import UIKit

/// Service for authentication and session management
class AuthenticationService {
    
    static let shared = AuthenticationService()
    
    private let keychain = KeychainService.shared
    
    private init() {}
    
    // MARK: - Current Session
    
    @MainActor var isAuthenticated: Bool {
        return keychain.retrieveAccessToken() != nil
    }
    
    @MainActor var currentEmployee: Employee? {
        guard let data = UserDefaults.standard.data(forKey: "current_employee"),
              let employee = try? JSONDecoder().decode(Employee.self, from: data) else {
            return nil
        }
        return employee
    }
    
    // MARK: - Login
    
    func login(username: String, password: String) async throws -> Employee {
        let deviceId = UIDevice.current.identifierForVendor?.uuidString
        
        if AppConfig.useMockServices {
            let response = try await MockAPIService.shared.mockLogin(
                username: username,
                password: password
            )
            
            // Store tokens
            _ = keychain.storeAccessToken(response.accessToken)
            _ = keychain.storeRefreshToken(response.refreshToken)
            
            // Store employee
            storeEmployee(response.employee)
            
            return response.employee
        } else {
            let request = LoginRequest(username: username, password: password, deviceId: deviceId)
            let response = try await APIClient.shared.performRequest(
                endpoint: "/auth/login",
                method: .post,
                body: request,
                requiresAuth: false,
                responseType: LoginResponse.self
            )
            
            // Store tokens
            _ = keychain.storeAccessToken(response.accessToken)
            _ = keychain.storeRefreshToken(response.refreshToken)
            
            // Store employee
            storeEmployee(response.employee)
            
            return response.employee
        }
    }
    
    // MARK: - Logout
    
    func logout() {
        _ = keychain.deleteAccessToken()
        _ = keychain.deleteRefreshToken()
        clearEmployee()
    }
    
    // MARK: - Token Refresh
    
    func refreshToken() async throws -> Bool {
        guard let refreshToken = keychain.retrieveRefreshToken() else {
            return false
        }
        
        if AppConfig.useMockServices {
            let response = try await MockAPIService.shared.mockRefreshToken(refreshToken: refreshToken)
            keychain.storeAccessToken(response.accessToken)
            keychain.storeRefreshToken(response.refreshToken)
            return true
        } else {
            let request = RefreshTokenRequest(refreshToken: refreshToken)
            let response = try await APIClient.shared.performRequest(
                endpoint: "/auth/refresh",
                method: .post,
                body: request,
                requiresAuth: false,
                responseType: RefreshTokenResponse.self
            )
            keychain.storeAccessToken(response.accessToken)
            keychain.storeRefreshToken(response.refreshToken)
            return true
        }
    }
    
    // MARK: - Employee Profile
    
    func getEmployeeProfile() async throws -> Employee {
        if AppConfig.useMockServices {
            let response = try await MockAPIService.shared.mockGetEmployeeProfile()
            storeEmployee(response.employee)
            return response.employee
        } else {
            let response = try await APIClient.shared.performRequest(
                endpoint: "/employee/profile",
                method: .get,
                requiresAuth: true,
                responseType: EmployeeProfileResponse.self
            )
            storeEmployee(response.employee)
            return response.employee
        }
    }
    
    // MARK: - Private Methods
    
    private func storeEmployee(_ employee: Employee) {
        if let data = try? JSONEncoder().encode(employee) {
            UserDefaults.standard.set(data, forKey: "current_employee")
        }
    }
    
    private func clearEmployee() {
        UserDefaults.standard.removeObject(forKey: "current_employee")
    }
}
