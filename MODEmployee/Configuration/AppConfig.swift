//
//  AppConfig.swift
//  MODEmployee
//
//  Created by Rajpal singh on 12/10/26.
//

import Foundation
import CoreLocation

/// Application configuration with environment-specific settings
/// All sensitive values should be set via environment variables or build configurations
enum AppConfig {
    
    enum Environment {
        case development
        case production
    }
    
    static var currentEnvironment: Environment {
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }
    
    // MARK: - API Configuration
    
    static var apiBaseURL: String {
        switch currentEnvironment {
        case .development:
            return "https://dev-api.example.com"
        case .production:
            return "https://api.example.com"
        }
    }
    
    static var apiTimeout: TimeInterval {
        return 30.0
    }
    
    // MARK: - Feature Flags
    
    static var useMockServices: Bool {
        switch currentEnvironment {
        case .development:
            return true // Set to false when real API is available
        case .production:
            return false
        }
    }
    
    static var enableDebugLogging: Bool {
        return currentEnvironment == .development
    }
    
    // MARK: - Location Configuration
    
    static var locationAccuracyThreshold: Double {
        return 50.0 // meters
    }
    
    static var locationTimeout: TimeInterval {
        return 10.0 // seconds
    }
    
    // MARK: - Liveness SDK Configuration
    
    /// KBY-AI License Key
    /// NOTE: This should be stored securely (e.g., in a config file excluded from git)
    /// and loaded at runtime. For development, use the demo license from KBY-AI.
    static var kbyLicenseKey: String {
        // Demo license from KBY-AI documentation for development only
        // Replace with your production license before release
        return "glF/068/SCjGIKN/o1HwZKKEANRWrO0eCTY7VinO46mMiXWcccNfCGLzAe2aNU2JBbjcn+IY000Q" +
               "zwYQUjEqx8X4Dkx41KMcZhJQSSdPg9KBEpxbOaksjsPCktAy78wlUJ9L+zmX6oa0h/3H45gMCHka" +
               "qPjjEWqrtGotonspHOxo5Z8TqofHSWJ04ORGllILdB4UQELaeToomCJMSNMJRKt425sIEdidO/+2" +
               "cQTdw04ShTpyMRgFI4B/sY5XMlz8Jyh1L9X3Yf5vEzj/Dk6d/7mtp1r3vRzIaBiFvk8M0Y0CyIwK" +
               "pdXxtkmC/OAO7DqzT3XQL69oX51XBMIwQXFriA=="
    }
    
    static var livenessThreshold: Float {
        return 0.7 // KBY-AI recommended threshold
    }
    
    // MARK: - Security Configuration
    
    static var keychainServiceName: String {
        return "com.mod.pizza.MODEmployee"
    }
    
    static var keychainAccessTokenKey: String {
        return "access_token"
    }
    
    static var keychainRefreshTokenKey: String {
        return "refresh_token"
    }
    
    // MARK: - App Info
    
    static var appVersion: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    static var buildNumber: String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}
