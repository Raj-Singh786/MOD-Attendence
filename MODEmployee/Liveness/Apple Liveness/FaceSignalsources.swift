//
//  FaceSignalsources.swift
//  MODEmployee
//
//  Created by Rajpal singh on 13/10/26.
//

import UIKit
import ARKit
import AVFoundation
import Vision
import CoreImage
import simd

// MARK: - Source protocol

protocol FaceSignalSource: AnyObject {
    var method: String { get }
    var supportedChallenges: Set<LivenessChallenge> { get }
    var providesDepth: Bool { get }
    var previewView: UIView { get }

    /// Called on the source's own serial queue.
    var onSignals: ((FaceSignals) -> Void)? { get set }
    var onFailure: ((String) -> Void)? { get set }

    func start()
    func stop()
    /// Upright, NON-mirrored JPEG of the latest camera frame (for the backend).
    func snapshotJPEG() -> Data?
}

private let sharedCIContext = CIContext()

private func jpegData(from pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) -> Data? {
    let image = CIImage(cvPixelBuffer: pixelBuffer).oriented(orientation)
    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
    let options: [CIImageRepresentationOption: Any] = [
        kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.85
    ]
    return sharedCIContext.jpegRepresentation(of: image, colorSpace: colorSpace, options: options)
}

// MARK: - ARKit source (Face ID iPhones: blendshapes + real depth)

final class ARKitFaceSource: NSObject, FaceSignalSource, ARSessionDelegate {

    static var isSupported: Bool { ARFaceTrackingConfiguration.isSupported }

    /// ARKit's face axes: if "turn left" feels reversed on a real device, flip this to -1.
    static let userLeftSign: Float = 1

    let method = "arkit+depth"
    let supportedChallenges = Set(LivenessChallenge.allCases)
    let providesDepth = true

    var onSignals: ((FaceSignals) -> Void)?
    var onFailure: ((String) -> Void)?

    private let sceneView = ARSCNView(frame: .zero)
    var previewView: UIView { sceneView }

    private let queue = DispatchQueue(label: "liveness.arkit")
    private let lock = NSLock()
    private var lastPixelBuffer: CVPixelBuffer?

    func start() {
        let config = ARFaceTrackingConfiguration()
        sceneView.automaticallyUpdatesLighting = false
        sceneView.session.delegate = self
        sceneView.session.delegateQueue = queue
        sceneView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
    }

    func stop() {
        sceneView.session.pause()
    }

    func snapshotJPEG() -> Data? {
        lock.lock(); let buffer = lastPixelBuffer; lock.unlock()
        guard let buffer else { return nil }
        // Portrait, un-mirrored. VERIFY by viewing a saved frame; if rotated, try .right.
        return jpegData(from: buffer, orientation: .left)
    }

    // MARK: ARSessionDelegate

    func session(_ session: ARSession, didFailWithError error: Error) {
        onFailure?("Camera/AR error: \(error.localizedDescription)")
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        lock.lock(); lastPixelBuffer = frame.capturedImage; lock.unlock()

        guard let face = frame.anchors.compactMap({ $0 as? ARFaceAnchor }).first, face.isTracked else {
            emitNoFace(frame.timestamp)
            return
        }

        let camera = frame.camera
        let rel = simd_mul(simd_inverse(camera.transform), face.transform)
        let positionInCamera = SIMD3<Float>(rel.columns.3.x, rel.columns.3.y, rel.columns.3.z)
        let distance = simd_length(positionInCamera)

        let facePosition = SIMD3<Float>(face.transform.columns.3.x,
                                        face.transform.columns.3.y,
                                        face.transform.columns.3.z)
        let imageSize = camera.imageResolution
        let imagePoint = camera.projectPoint(facePosition, orientation: .landscapeRight, viewportSize: imageSize)
        let nx = imagePoint.x / imageSize.width
        let ny = imagePoint.y / imageSize.height

        let framed = distance > 0.2 && distance < 0.7 && abs(nx - 0.5) < 0.25 && abs(ny - 0.5) < 0.25

        func shape(_ key: ARFaceAnchor.BlendShapeLocation) -> Float {
            face.blendShapes[key]?.floatValue ?? 0
        }

        let signals = FaceSignals(
            timestamp: frame.timestamp,
            faceInFrame: framed,
            eyesClosed: (shape(.eyeBlinkLeft) + shape(.eyeBlinkRight)) / 2,
            yawDegrees: userYawDegrees(rel: rel, position: positionInCamera),
            smile: (shape(.mouthSmileLeft) + shape(.mouthSmileRight)) / 2,
            mouthOpen: shape(.jawOpen),
            depthReliefMM: framed ? depthReliefMM(frame: frame, centerInImage: imagePoint, distance: distance) : nil
        )
        onSignals?(signals)
    }

    private func emitNoFace(_ t: TimeInterval) {
        onSignals?(FaceSignals(timestamp: t, faceInFrame: false, eyesClosed: 0, yawDegrees: 0,
                               smile: 0, mouthOpen: 0, depthReliefMM: nil))
    }

    /// Angle of the face's forward direction relative to the line of sight,
    /// measured around the face's own vertical axis. Independent of device orientation.
    private func userYawDegrees(rel: simd_float4x4, position: SIMD3<Float>) -> Float {
        let forward = SIMD3<Float>(rel.columns.2.x, rel.columns.2.y, rel.columns.2.z)
        let up = simd_normalize(SIMD3<Float>(rel.columns.1.x, rel.columns.1.y, rel.columns.1.z))
        let toCamera = simd_normalize(-position)

        let f = forward - up * simd_dot(forward, up)
        let d = toCamera - up * simd_dot(toCamera, up)
        guard simd_length(f) > 1e-4, simd_length(d) > 1e-4 else { return 0 }

        let angle = atan2(simd_dot(simd_cross(d, f), up), simd_dot(d, f))
        return angle * 180 / .pi * Self.userLeftSign
    }

    // MARK: Depth: how far is the face from a flat plane?

    /// Fits a plane to the face region of the TrueDepth map and returns the RMS residual in mm.
    /// A flat photo or screen (even tilted) sits close to a plane; a real face does not.
    /// Returns nil when this frame has no depth or the region is unusable.
    private func depthReliefMM(frame: ARFrame, centerInImage: CGPoint, distance: Float) -> Float? {
        guard let depthData = frame.capturedDepthData else { return nil }

        let map = depthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32).depthDataMap
        CVPixelBufferLockBaseAddress(map, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(map, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(map) else { return nil }

        let w = CVPixelBufferGetWidth(map)
        let h = CVPixelBufferGetHeight(map)
        let rowFloats = CVPixelBufferGetBytesPerRow(map) / MemoryLayout<Float32>.size
        let depth = base.assumingMemoryBound(to: Float32.self)

        let image = frame.camera.imageResolution
        let scaleX = CGFloat(w) / image.width
        let scaleY = CGFloat(h) / image.height
        let fx = Double(frame.camera.intrinsics.columns.0.x) * Double(scaleX)
        let cx = Int(centerInImage.x * scaleX)
        let cy = Int(centerInImage.y * scaleY)
        guard cx >= 0, cy >= 0, cx < w, cy < h, fx > 0 else { return nil }

        // Reference depth: median of a 5x5 patch at the face centre.
        var reference: [Float] = []
        for dy in -2...2 {
            for dx in -2...2 {
                let x = cx + dx, y = cy + dy
                guard x >= 0, x < w, y >= 0, y < h else { continue }
                let z = depth[y * rowFloats + x]
                if z.isFinite, z > 0.1, z < 1.5 { reference.append(z) }
            }
        }
        guard reference.count >= 8 else { return nil }
        let refZ = reference.sorted()[reference.count / 2]

        // Sample a ~14 cm wide window, keep only points near the face surface (drops background).
        let half = max(10, Int(0.07 * fx / Double(refZ)))
        let step = max(1, half / 25)

        var xs: [Double] = [], ys: [Double] = [], zs: [Double] = []
        var y = max(0, cy - half)
        while y <= min(h - 1, cy + half) {
            var x = max(0, cx - half)
            while x <= min(w - 1, cx + half) {
                let z = depth[y * rowFloats + x]
                if z.isFinite, z > refZ - 0.05, z < refZ + 0.07 {
                    xs.append(Double(x - cx) * Double(z) / fx)
                    ys.append(Double(y - cy) * Double(z) / fx)
                    zs.append(Double(z))
                }
                x += step
            }
            y += step
        }
        guard xs.count >= 150 else { return nil }

        // Least-squares plane z = a*x + b*y + c on mean-centred data.
        let n = Double(xs.count)
        let mx = xs.reduce(0, +) / n, my = ys.reduce(0, +) / n, mz = zs.reduce(0, +) / n
        var sxx = 0.0, sxy = 0.0, syy = 0.0, sxz = 0.0, syz = 0.0, szz = 0.0
        for i in 0..<xs.count {
            let dx = xs[i] - mx, dy = ys[i] - my, dz = zs[i] - mz
            sxx += dx * dx; sxy += dx * dy; syy += dy * dy
            sxz += dx * dz; syz += dy * dz; szz += dz * dz
        }
        let det = sxx * syy - sxy * sxy
        guard abs(det) > 1e-12 else { return nil }
        let a = (sxz * syy - syz * sxy) / det
        let b = (syz * sxx - sxz * sxy) / det
        let sse = max(0, szz - a * sxz - b * syz)
        return Float((sse / n).squareRoot() * 1000)   // metres -> mm
    }
}

// MARK: - Vision source (any iPhone: no depth, weaker)

final class CameraPreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

final class VisionFaceSource: NSObject, FaceSignalSource, AVCaptureVideoDataOutputSampleBufferDelegate {

    /// Vision's yaw sign: if "turn left" feels reversed on a real device, flip this to -1.
    static let userLeftSign: Float = 1

    let method = "vision"
    let supportedChallenges: Set<LivenessChallenge> = [.blink]
    let providesDepth = false

    var onSignals: ((FaceSignals) -> Void)?
    var onFailure: ((String) -> Void)?

    private let preview = CameraPreviewView()
    var previewView: UIView { preview }

    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "liveness.vision")
    private let lock = NSLock()
    private var lastPixelBuffer: CVPixelBuffer?
    private var lastProcessed: TimeInterval = 0
    private var baselineOpenness: Float = 0

    func start() {
        queue.async { [weak self] in self?.configureAndRun() }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func snapshotJPEG() -> Data? {
        lock.lock(); let buffer = lastPixelBuffer; lock.unlock()
        guard let buffer else { return nil }
        return jpegData(from: buffer, orientation: .up)   // frames are already upright and not mirrored
    }

    private func configureAndRun() {
        session.beginConfiguration()
        session.sessionPreset = .hd1280x720

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            onFailure?("Front camera unavailable")
            return
        }
        session.addInput(input)

        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            onFailure?("Camera output unavailable")
            return
        }
        session.addOutput(output)

        if let connection = output.connection(with: .video) {
            if #available(iOS 17.0, *) {
                connection.videoRotationAngle = 90
            } else {
                connection.videoOrientation = .portrait
            }
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = false
            }
        }
        session.commitConfiguration()

        DispatchQueue.main.async {
            self.preview.previewLayer.session = self.session
            self.preview.previewLayer.videoGravity = .resizeAspectFill
        }
        session.startRunning()
    }

    // MARK: Frames

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        let now = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        guard now - lastProcessed >= 0.066 else { return }   // ~15 fps
        lastProcessed = now
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        lock.lock(); lastPixelBuffer = pixelBuffer; lock.unlock()

        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do { try handler.perform([request]) } catch { return }

        let faces = request.results ?? []
        guard faces.count == 1, let face = faces.first else {
            onSignals?(FaceSignals(timestamp: now, faceInFrame: false, eyesClosed: 0, yawDegrees: 0,
                                   smile: nil, mouthOpen: nil, depthReliefMM: nil))
            return
        }

        let box = face.boundingBox
        let framed = abs(box.midX - 0.5) < 0.25 && abs(box.midY - 0.5) < 0.25 && box.width > 0.25

        // Eye openness = height/width of the eye outline, compared with the person's own open-eye baseline.
        let left = openness(face.landmarks?.leftEye)
        let right = openness(face.landmarks?.rightEye)
        var eyesClosed: Float = 0
        if let left, let right {
            let open = (left + right) / 2
            baselineOpenness = max(open, baselineOpenness * 0.998)
            let ratio = baselineOpenness > 0 ? open / baselineOpenness : 1
            eyesClosed = min(max((0.75 - ratio) / 0.45, 0), 1)
        }

        let yawRadians = face.yaw?.floatValue ?? 0
        let yawDegrees = yawRadians * 180 / .pi * Self.userLeftSign

        onSignals?(FaceSignals(timestamp: now, faceInFrame: framed, eyesClosed: eyesClosed,
                               yawDegrees: yawDegrees, smile: nil, mouthOpen: nil, depthReliefMM: nil))
    }

    private func openness(_ region: VNFaceLandmarkRegion2D?) -> Float? {
        guard let points = region?.normalizedPoints, points.count > 4 else { return nil }
        let xs = points.map { $0.x }, ys = points.map { $0.y }
        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max(),
              maxX - minX > 0 else { return nil }
        return Float((maxY - minY) / (maxX - minX))
    }
}
