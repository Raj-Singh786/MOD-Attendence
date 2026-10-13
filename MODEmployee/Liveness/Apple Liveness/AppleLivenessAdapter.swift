//
//  AppleLivenessAdapter.swift
//  MODEmployee
//
//  Created by Rajpal singh on 13/10/26.
//

import Foundation
import UIKit

/// Adapter for Apple Liveness Detection
/// Uses native iOS frameworks (ARKit/Vision) for face liveness detection
class AppleLivenessAdapter: NSObject, LivenessProvider {
    
    // MARK: - Properties
    
    private let config: LivenessConfig
    private let policy: LivenessPolicy
    private var presenter: UIViewController?
    
    // MARK: - Initialization

    init(config: LivenessConfig = .default, policy: LivenessPolicy = LivenessPolicy()) {
        self.config = config
        // Customize policy for better user experience
        var customPolicy = policy
        customPolicy.challengeCount = 1  // Only 1 challenge (blink)
        customPolicy.challengeTimeout = 10  // 10 seconds per challenge
        customPolicy.overallTimeout = 30    // 30 seconds total (reduced since only 1 challenge)
        customPolicy.neutralHold = 0.8       // 0.8 seconds neutral hold
        customPolicy.minReactionTime = 0.5   // 0.5 seconds reaction time
        self.policy = customPolicy
        super.init()
    }
    
    // MARK: - LivenessProvider
    
    @MainActor
    func startLiveness(sessionID: String) async throws -> LivenessResult {
        guard let presenter = presenter else {
            throw LivenessError.sdkError("Presenter not set. Call setPresenter() before starting liveness.")
        }
        
        let provider = AppleLivenessProvider()
        let result = await provider.performLiveness(
            from: presenter,
            policy: policy,
            allowVisionFallback: true
        )
        
        return try convertToLivenessResult(appleResult: result, sessionID: sessionID)
    }
    
    // MARK: - Public Methods
    
    /// Set the view controller that will present the liveness detection screen
    func setPresenter(_ presenter: UIViewController) {
        self.presenter = presenter
    }
    
    // MARK: - Private Methods
    
    private func convertToLivenessResult(appleResult: AppleLivenessResult, sessionID: String) throws -> LivenessResult {
        // Use the best available frame (neutral frame is preferred)
        let capturedImage: Data
        if appleResult.frames.count >= 1 {
            capturedImage = appleResult.frames[0]
        } else {
            // Create a placeholder image if no frames were captured
            let placeholderImage = UIImage(systemName: "person.fill")?.jpegData(compressionQuality: 0.8) ?? Data()
            capturedImage = placeholderImage
        }
        
        // Analyze frames for video spoofing
        let videoAnalysis = FrameAnalyzer.analyzeFrames(appleResult.frames)
        
        // Calculate liveness score based on challenges passed and video analysis
        let totalChallenges = appleResult.challenges.count
        let challengesPassed = appleResult.challengesPassed
        var livenessScore: Float
        
        if totalChallenges > 0 {
            livenessScore = Float(challengesPassed) / Float(totalChallenges)
        } else {
            livenessScore = appleResult.passed ? 1.0 : 0.0
        }
        
        // Reduce score if video is detected
        if videoAnalysis.isLikelyVideo {
            livenessScore = livenessScore * (1.0 - videoAnalysis.confidence)
        }
        
        let diagnostics: [String: Any] = [
            "provider": "Apple (ARKit/Vision)",
            "method": appleResult.method,
            "sessionId": sessionID,
            "challenges": appleResult.challenges,
            "challengesPassed": challengesPassed,
            "threshold": config.threshold,
            "timestamp": Date().timeIntervalSince1970,
            "videoDetection": [
                "isLikelyVideo": videoAnalysis.isLikelyVideo,
                "confidence": videoAnalysis.confidence,
                "reasons": videoAnalysis.reasons
            ]
        ]
        
        // Add depth relief if available
        if let depthRelief = appleResult.depthReliefMM {
            var mutableDiagnostics = diagnostics
            mutableDiagnostics["depthReliefMM"] = depthRelief
        }
        
        // Check if result passed
        guard appleResult.passed else {
            let failureReason = appleResult.failureReason ?? "Liveness verification failed"
            throw LivenessError.detectionFailed(failureReason)
        }
        
        // Reject if video is detected with high confidence
        if videoAnalysis.isLikelyVideo && videoAnalysis.confidence > 0.4 {
            let reasons = videoAnalysis.reasons.joined(separator: ", ")
            throw LivenessError.detectionFailed("Possible video spoofing detected: \(reasons)")
        }
        
        return LivenessResult(
            sessionID: sessionID,
            isLive: appleResult.passed && !videoAnalysis.isLikelyVideo,
            livenessScore: livenessScore,
            capturedImage: capturedImage,
            timestamp: Date(),
            diagnostics: diagnostics
        )
    }
}
