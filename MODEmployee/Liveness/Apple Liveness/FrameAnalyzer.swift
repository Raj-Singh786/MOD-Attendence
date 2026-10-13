//
//  FrameAnalyzer.swift
//  MODEmployee
//
//  Created by Rajpal singh on 13/10/26.
//

import UIKit
import CoreImage
import Accelerate

/// Analyzes captured frames for video spoofing artifacts
class FrameAnalyzer {
    
    struct AnalysisResult {
        let isLikelyVideo: Bool
        let confidence: Float
        let reasons: [String]
    }
    
    /// Analyzes frames for video spoofing indicators
    static func analyzeFrames(_ frames: [Data]) -> AnalysisResult {
        guard frames.count >= 2 else {
            return AnalysisResult(isLikelyVideo: false, confidence: 0.0, reasons: ["Insufficient frames"])
        }
        
        var reasons: [String] = []
        var totalScore: Float = 0.0
        var maxScore: Float = 0.0
        
        // Check 1: Frame consistency (videos have repeating patterns) - Lowered threshold
        if let consistencyScore = checkFrameConsistency(frames) {
            maxScore += 1.0
            totalScore += consistencyScore
            if consistencyScore > 0.4 {
                reasons.append("High frame consistency (possible video)")
            }
        }
        
        // Check 2: Compression artifacts - Lowered threshold
        if let compressionScore = checkCompressionArtifacts(frames) {
            maxScore += 1.0
            totalScore += compressionScore
            if compressionScore > 0.4 {
                reasons.append("Compression artifacts detected")
            }
        }
        
        // Check 3: Screen reflection detection - Lowered threshold
        if let reflectionScore = checkScreenReflection(frames) {
            maxScore += 1.0
            totalScore += reflectionScore
            if reflectionScore > 0.4 {
                reasons.append("Screen reflection detected")
            }
        }
        
        // Check 4: Color uniformity (screens have even lighting) - Lowered threshold
        if let uniformityScore = checkColorUniformity(frames) {
            maxScore += 1.0
            totalScore += uniformityScore
            if uniformityScore > 0.4 {
                reasons.append("Unnatural color uniformity")
            }
        }
        
        let confidence = maxScore > 0 ? totalScore / maxScore : 0.0
        let isLikelyVideo = confidence > 0.4  // Lowered from 0.5 to 0.4
        
        return AnalysisResult(
            isLikelyVideo: isLikelyVideo,
            confidence: confidence,
            reasons: reasons
        )
    }
    
    // MARK: - Analysis Methods
    
    /// Checks if consecutive frames are too similar (indicates video loop)
    private static func checkFrameConsistency(_ frames: [Data]) -> Float? {
        guard frames.count >= 2 else { return nil }
        
        // Only check first and last frame for performance
        guard let img1 = UIImage(data: frames.first!),
              let img2 = UIImage(data: frames.last!),
              let cgImg1 = img1.cgImage,
              let cgImg2 = img2.cgImage else { return nil }
        
        let diff = calculateImageDifference(cgImg1, cgImg2)
        
        // If difference is very low, frames are too similar (possible video)
        // Real camera feed has natural variation
        let score = 1.0 - min(diff / 30.0, 1.0)  // Lowered threshold from 50 to 30
        return score
    }
    
    /// Detects compression artifacts typical of video encoding
    private static func checkCompressionArtifacts(_ frames: [Data]) -> Float? {
        guard let firstFrame = frames.first,
              let image = UIImage(data: firstFrame),
              let cgImage = image.cgImage else { return nil }
        
        let width = cgImage.width
        let height = cgImage.height
        
        guard width >= 8 && height >= 8 else { return nil }
        
        // Sample edge areas for compression blocks - Reduced sampling for performance
        let blockSize = 8
        var blockScores: [Float] = []
        
        // Check only center block for performance
        let centerX = width / 2 - blockSize / 2
        let centerY = height / 2 - blockSize / 2
        
        if let score = analyzeBlockForCompression(cgImage, x: centerX, y: centerY, size: blockSize) {
            blockScores.append(score)
        }
        
        guard !blockScores.isEmpty else { return nil }
        
        let avgScore = blockScores.reduce(0, +) / Float(blockScores.count)
        return avgScore
    }
    
    /// Detects screen glare/reflection patterns
    private static func checkScreenReflection(_ frames: [Data]) -> Float? {
        guard let firstFrame = frames.first,
              let image = UIImage(data: firstFrame),
              let cgImage = image.cgImage else { return nil }
        
        let width = cgImage.width
        let height = cgImage.height
        
        guard width >= 16 && height >= 16 else { return nil }
        
        // Check for high-intensity specular highlights (screen glare)
        var brightPixelCount = 0
        var totalPixels = 0
        
        let imageContext = CIImage(cgImage: cgImage)
        guard let pixelBuffer = imageContext.pixelBuffer(width: width, height: height) else { return nil }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        // Sample only center area for performance
        let startX = width / 3
        let endX = width * 2 / 3
        let startY = height / 3
        let endY = height * 2 / 3
        
        for y in startY..<endY {
            for x in startX..<endX {
                let pixelIndex = y * bytesPerRow + x * 4
                if pixelIndex + 3 < bytesPerRow * height {
                    let r = Float(buffer[pixelIndex])
                    let g = Float(buffer[pixelIndex + 1])
                    let b = Float(buffer[pixelIndex + 2])
                    
                    let brightness = (r + g + b) / 3.0
                    if brightness > 240 {
                        brightPixelCount += 1
                    }
                    totalPixels += 1
                }
            }
        }
        
        guard totalPixels > 0 else { return nil }
        
        let brightRatio = Float(brightPixelCount) / Float(totalPixels)
        
        // Screens often have specular highlights
        let score = min(brightRatio * 5.0, 1.0)
        return score
    }
    
    /// Checks for unnatural color uniformity (screens have even lighting)
    private static func checkColorUniformity(_ frames: [Data]) -> Float? {
        guard let firstFrame = frames.first,
              let image = UIImage(data: firstFrame),
              let cgImage = image.cgImage else { return nil }
        
        let width = cgImage.width
        let height = cgImage.height
        
        guard width >= 16 && height >= 16 else { return nil }
        
        let imageContext = CIImage(cgImage: cgImage)
        guard let pixelBuffer = imageContext.pixelBuffer(width: width, height: height) else { return nil }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        var redValues: [Float] = []
        var greenValues: [Float] = []
        var blueValues: [Float] = []
        
        // Sample only 25 pixels for performance (reduced from 100)
        let sampleCount = 25
        let stepX = width / 5
        let stepY = height / 5
        
        for i in 0..<sampleCount {
            let x = (i % 5) * stepX
            let y = (i / 5) * stepY
            
            let pixelIndex = y * bytesPerRow + x * 4
            if pixelIndex + 3 < bytesPerRow * height {
                redValues.append(Float(buffer[pixelIndex]))
                greenValues.append(Float(buffer[pixelIndex + 1]))
                blueValues.append(Float(buffer[pixelIndex + 2]))
            }
        }
        
        guard !redValues.isEmpty else { return nil }
        
        // Calculate standard deviation
        let redStd = calculateStandardDeviation(redValues)
        let greenStd = calculateStandardDeviation(greenValues)
        let blueStd = calculateStandardDeviation(blueValues)
        
        let avgStd = (redStd + greenStd + blueStd) / 3.0
        
        // Low standard deviation = high uniformity (possible screen)
        let score = 1.0 - min(avgStd / 40.0, 1.0)  // Lowered threshold from 50 to 40
        return score
    }
    
    // MARK: - Helper Methods
    
    private static func calculateImageDifference(_ img1: CGImage, _ img2: CGImage) -> Float {
        let width = min(img1.width, img2.width)
        let height = min(img1.height, img2.height)
        
        guard width > 0 && height > 0 else { return 0 }
        
        let ctx1 = CIImage(cgImage: img1)
        let ctx2 = CIImage(cgImage: img2)
        
        guard let buf1 = ctx1.pixelBuffer(width: width, height: height),
              let buf2 = ctx2.pixelBuffer(width: width, height: height) else { return 0 }
        
        CVPixelBufferLockBaseAddress(buf1, .readOnly)
        CVPixelBufferLockBaseAddress(buf2, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(buf1, .readOnly)
            CVPixelBufferUnlockBaseAddress(buf2, .readOnly)
        }
        
        guard let base1 = CVPixelBufferGetBaseAddress(buf1),
              let base2 = CVPixelBufferGetBaseAddress(buf2) else { return 0 }
        
        let bytes1 = base1.assumingMemoryBound(to: UInt8.self)
        let bytes2 = base2.assumingMemoryBound(to: UInt8.self)
        
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buf1)
        var totalDiff: Float = 0
        var pixelCount = 0
        
        // Sample only center 50% of image for performance
        let startX = width / 4
        let endX = width * 3 / 4
        let startY = height / 4
        let endY = height * 3 / 4
        
        for y in startY..<endY {
            for x in startX..<endX {
                let idx = y * bytesPerRow + x * 4
                if idx + 3 < bytesPerRow * height {
                    let diff1 = abs(Float(bytes1[idx]) - Float(bytes2[idx]))
                    let diff2 = abs(Float(bytes1[idx+1]) - Float(bytes2[idx+1]))
                    let diff3 = abs(Float(bytes1[idx+2]) - Float(bytes2[idx+2]))
                    totalDiff += diff1 + diff2 + diff3
                    pixelCount += 1
                }
            }
        }
        
        return pixelCount > 0 ? totalDiff / Float(pixelCount) : 0
    }
    
    private static func analyzeBlockForCompression(_ image: CGImage, x: Int, y: Int, size: Int) -> Float? {
        let ctx = CIImage(cgImage: image)
        guard let pixelBuffer = ctx.pixelBuffer(width: image.width, height: image.height) else { return nil }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        var edgeCount = 0
        var totalPixels = 0
        
        // Check for sharp edges within block (compression creates artificial edges)
        for dy in 0..<size {
            for dx in 0..<size {
                let px = x + dx
                let py = y + dy
                
                if px < image.width - 1 && py < image.height - 1 {
                    let idx = py * bytesPerRow + px * 4
                    let nextIdx = py * bytesPerRow + (px + 1) * 4
                    
                    if idx + 3 < bytesPerRow * image.height && nextIdx + 3 < bytesPerRow * image.height {
                        let diff = abs(Float(buffer[idx]) - Float(buffer[nextIdx]))
                        if diff > 30 {
                            edgeCount += 1
                        }
                        totalPixels += 1
                    }
                }
            }
        }
        
        guard totalPixels > 0 else { return nil }
        
        let edgeRatio = Float(edgeCount) / Float(totalPixels)
        
        // High edge ratio suggests compression artifacts
        return min(edgeRatio * 3.0, 1.0)
    }
    
    private static func calculateStandardDeviation(_ values: [Float]) -> Float {
        guard !values.isEmpty else { return 0 }
        
        let mean = values.reduce(0, +) / Float(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Float(values.count)
        return sqrt(variance)
    }
}

// MARK: - CIImage Extension

extension CIImage {
    func pixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
        ] as CFDictionary
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32ARGB,
            attrs,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else { return nil }
        
        // Convert CIImage to CGImage first
        let ciContext = CIContext()
        guard let cgImage = ciContext.createCGImage(self, from: CGRect(x: 0, y: 0, width: extent.width, height: extent.height)) else { return nil }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        return buffer
    }
}
