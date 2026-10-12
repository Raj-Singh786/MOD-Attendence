//
//  LoginViewModel.swift
//  MODEmployee
//
//  Created by Rajpal singh on 12/10/26.
//

import Foundation

@MainActor
class LoginViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var username: String = ""
    @Published var password: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isLoggedIn: Bool = false
    
    // MARK: - Dependencies
    
    private let authService = AuthenticationService.shared
    
    // MARK: - Validation
    
    var isValid: Bool {
        return !username.isEmpty && !password.isEmpty
    }
    
    // MARK: - Login
    
    func login() async {
        guard isValid else {
            errorMessage = "Please enter username and password"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let employee = try await authService.login(username: username, password: password)
            isLoggedIn = true
            print("Login successful for employee: \(employee.name)")
        } catch {
            errorMessage = error.localizedDescription
            if AppConfig.enableDebugLogging {
                print("Login error: \(error)")
            }
        }
        
        isLoading = false
    }
    
    // MARK: - Clear Error
    
    func clearError() {
        errorMessage = nil
    }
}
