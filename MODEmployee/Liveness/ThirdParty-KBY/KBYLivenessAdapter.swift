//
//  KBYLivenessAdapter.swift
//  MODEmployee
//
//  Created by Rajpal singh on 12/10/26.
//

import Foundation
import UIKit
import AVFoundation

/// Adapter for KBY-AI Face Liveness Detection SDK
/// NOTE: This implementation requires the KBY-AI facesdk.framework to be added to the project
/// Follow the installation steps in the README to integrate the SDK
class KBYLivenessAdapter: NSObject, LivenessProvider {
    
    // MARK: - Properties
    
    private let config: LivenessConfig
    private var isInitialized = false
    private var continuation: CheckedContinuation<LivenessResult, Error>?
    
    // MARK: - Initialization
    
    init(config: LivenessConfig = .default) {
        self.config = config
        super.init()
    }
    
    // MARK: - LivenessProvider
    
    func startLiveness(sessionID: String) async throws -> LivenessResult {
        // Check if SDK is available
        guard isSDKAvailable() else {
            throw LivenessError.sdkError("KBY-AI SDK not integrated. Please add facesdk.framework to the project.")
        }
        
        // Initialize SDK if not already done
        if !isInitialized {
            try initializeSDK()
        }
        
        // Start liveness detection
        return try await performLivenessDetection(sessionID: sessionID)
    }
    
    // MARK: - SDK Initialization
    
    private func isSDKAvailable() -> Bool {
        // Check if FaceSDK class is available
        // This will be false until the SDK is actually integrated
        let sdkClass = NSClassFromString("FaceSDK")
        return sdkClass != nil
    }
    
    private func initializeSDK() throws {
        guard isSDKAvailable() else {
            throw LivenessError.sdkError("KBY-AI SDK not found")
        }
        
        // Get license from config
        let license = AppConfig.kbyLicenseKey
        
        // Call FaceSDK.setActivation (this will fail until SDK is integrated)
        // let ret = FaceSDK.setActivation(license)
        // guard ret == SDK_SUCCESS.rawValue else {
        //     throw LivenessError.licenseInvalid
        // }
        
        // Call FaceSDK.initSDK
        // let ret = FaceSDK.initSDK()
        // guard ret == SDK_SUCCESS.rawValue else {
        //     throw LivenessError.initializationFailed("SDK initialization failed")
        // }
        
        isInitialized = true
    }
    
    // MARK: - Liveness Detection
    
    private func performLivenessDetection(sessionID: String) async throws -> LivenessResult {
        // NOTE: This is a placeholder implementation
        // The actual implementation will use the KBY-AI SDK's camera interface
        // and FaceSDK.faceDetection() method
        
        // For now, we'll use a mock implementation that simulates liveness detection
        // This allows the app to be tested before SDK integration
        
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            
            // Simulate liveness detection delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: LivenessError.sdkError("Operation cancelled"))
                    return
                }
                
                // Generate mock result
                let mockResult = self.generateMockLivenessResult(sessionID: sessionID)
                continuation.resume(returning: mockResult)
            }
        }
    }
    
    // MARK: - Mock Implementation (for development)
    
    private func generateMockLivenessResult(sessionID: String) -> LivenessResult {
        // Create a mock image (in real implementation, this comes from SDK)
        let mockImage = UIImage(systemName: "person.fill")?.jpegData(compressionQuality: 0.8) ?? Data()
        
        let diagnostics: [String: Any] = [
            "provider": "KBY-AI (Mock)",
            "sessionId": sessionID,
            "threshold": config.threshold,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        return LivenessResult(
            sessionID: sessionID,
            isLive: true, // Mock always returns true for development
            livenessScore: 0.85, // Mock score above threshold
            capturedImage: mockImage,
            timestamp: Date(),
            diagnostics: diagnostics
        )
    }
    
    // MARK: - Real SDK Implementation (when SDK is integrated)
    
    /*
     This is how the real implementation would look with the KBY-AI SDK:
     
     private func performRealLivenessDetection(sessionID: String) async throws -> LivenessResult {
     return try await withCheckedThrowingContinuation { continuation in
     self.continuation = continuation
     
     // Create camera view controller
     let cameraVC = CameraViewController()
     cameraVC.delegate = self
     
     // Present camera view controller
     if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
     let rootVC = windowScene.windows.first?.rootViewController {
     rootVC.present(cameraVC, animated: true)
     }
     }
     }
     
     // In CameraViewController's captureOutput:
     // let faceBoxes = FaceSDK.faceDetection(capturedImage)
     // let faceBox = faceBoxes[0] as! FaceBox
     // if faceBox.liveness > livenessThreshold {
     //     let templates = FaceSDK.templateExtraction(capturedImage, faceBox: faceBox)
     //     // Capture successful
     // }
     */
}

// MARK: - Mock Camera View Controller (for development)

class MockCameraViewController: UIViewController {
    
    var onCapture: ((UIImage) -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        
        // Simulate camera view
        let label = UILabel()
        label.text = "Simulating Liveness Detection..."
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        // Simulate capture after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.dismiss(animated: true) {
                if let mockImage = UIImage(systemName: "person.fill") {
                    self?.onCapture?(mockImage)
                }
            }
        }
    }
}
