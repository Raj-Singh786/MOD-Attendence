//
//  LivenessProvider.swift
//  MODEmployee
//
//  Created by Rajpal singh on 12/10/26.
//

import Foundation

/// Protocol for liveness detection providers
/// This abstraction allows different SDK implementations to be swapped
protocol LivenessProvider {
    func startLiveness(sessionID: String) async throws -> LivenessResult
}

/// Configuration for liveness detection
struct LivenessConfig {
    let threshold: Float
    let timeout: TimeInterval
    
    static let `default` = LivenessConfig(threshold: AppConfig.livenessThreshold, timeout: 30.0)
}
