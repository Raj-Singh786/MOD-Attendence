//
//  LivenessResult.swift
//  MODEmployee
//
//  Created by Rajpal singh on 12/10/26.
//

import Foundation
import UIKit

/// Application-owned liveness result model
/// Contains only the information required by the application
struct LivenessResult {
    let sessionID: String
    let isLive: Bool
    let livenessScore: Float
    let capturedImage: Data
    let timestamp: Date
    let diagnostics: [String: Any]
    
    init(sessionID: String, isLive: Bool, livenessScore: Float, capturedImage: Data, timestamp: Date = Date(), diagnostics: [String: Any] = [:]) {
        self.sessionID = sessionID
        self.isLive = isLive
        self.livenessScore = livenessScore
        self.capturedImage = capturedImage
        self.timestamp = timestamp
        self.diagnostics = diagnostics
    }
    
    /// Convert captured image data to UIImage
    var image: UIImage? {
        return UIImage(data: capturedImage)
    }
}

/// Error types for liveness detection
enum LivenessError: LocalizedError {
    case initializationFailed(String)
    case licenseInvalid
    case cameraPermissionDenied
    case cameraNotAvailable
    case detectionTimeout
    case userCancelled
    case detectionFailed(String)
    case sdkError(String)
    
    var errorDescription: String? {
        switch self {
        case .initializationFailed(let message):
            return "Liveness initialization failed: \(message)"
        case .licenseInvalid:
            return "Invalid liveness license"
        case .cameraPermissionDenied:
            return "Camera permission denied"
        case .cameraNotAvailable:
            return "Camera not available"
        case .detectionTimeout:
            return "Liveness detection timed out"
        case .userCancelled:
            return "User cancelled liveness detection"
        case .detectionFailed(let message):
            return "Liveness detection failed: \(message)"
        case .sdkError(let message):
            return "SDK error: \(message)"
        }
    }
}
