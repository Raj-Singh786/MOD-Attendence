//
//  AppleLiveNess.swift
//  MODEmployee
//
//  Created by Rajpal singh on 13/10/26.
//

import UIKit
import AVFoundation

// MARK: - Result

struct AppleLivenessResult {
    let passed: Bool
    let method: String             // "arkit+depth" or "vision"
    let challenges: [String]       // what was asked, in order
    let challengesPassed: Int
    let depthReliefMM: Float?      // median flatness measure (ARKit path only)
    let frames: [Data]             // upright JPEGs (only when passed): neutral frame + final frame
    let failureReason: String?
}

// MARK: - Provider (what the rest of the app calls)

@MainActor
final class AppleLivenessProvider {

    /// - Parameter allowVisionFallback: set false to REQUIRE a Face ID (TrueDepth) iPhone.
    func performLiveness(from presenter: UIViewController,
                         policy: LivenessPolicy = LivenessPolicy(),
                         allowVisionFallback: Bool = true) async -> AppleLivenessResult {

        let source: FaceSignalSource
        if ARKitFaceSource.isSupported {
            source = ARKitFaceSource()
        } else if allowVisionFallback {
            source = VisionFaceSource()
        } else {
            return AppleLivenessResult(passed: false, method: "none", challenges: [], challengesPassed: 0,
                                       depthReliefMM: nil, frames: [],
                                       failureReason: "This device is not supported for face check-in.")
        }

        return await withCheckedContinuation { continuation in
            let vc = AppleLivenessViewController(source: source, policy: policy)
            vc.modalPresentationStyle = .fullScreen
            vc.isModalInPresentation = true
            vc.onComplete = { result in
                vc.dismiss(animated: true) {
                    continuation.resume(returning: result)   // onComplete fires once (see `completed`)
                }
            }
            presenter.present(vc, animated: true)
        }
    }
}

// MARK: - Screen

final class AppleLivenessViewController: UIViewController {

    var onComplete: ((AppleLivenessResult) -> Void)?

    private let source: FaceSignalSource
    private let engine: LivenessEngine

    private let promptLabel = UILabel()
    private let stepLabel = UILabel()
    private let cancelButton = UIButton(type: .system)
    private let ovalLayer = CAShapeLayer()
    private let debugLabel = UILabel()

    private var neutralJPEG: Data?        // touched only on the source queue
    private var lastDebugUpdate: TimeInterval = 0
    private var completed = false         // touched only on the main thread

    init(source: FaceSignalSource, policy: LivenessPolicy) {
        self.source = source
        self.engine = LivenessEngine(policy: policy,
                                     supported: source.supportedChallenges,
                                     usesDepth: source.providesDepth)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupUI()
        wireUp()
        checkPermissionThenStart()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let width = view.bounds.width * 0.7
        let rect = CGRect(x: (view.bounds.width - width) / 2,
                          y: view.bounds.height * 0.22,
                          width: width, height: width * 1.3)
        ovalLayer.path = UIBezierPath(ovalIn: rect).cgPath
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        source.stop()
    }

    // MARK: UI

    private func setupUI() {
        let preview = source.previewView
        preview.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(preview)

        ovalLayer.fillColor = UIColor.clear.cgColor
        ovalLayer.strokeColor = UIColor.white.withAlphaComponent(0.85).cgColor
        ovalLayer.lineWidth = 3
        view.layer.addSublayer(ovalLayer)

        promptLabel.text = "Look straight at the camera"
        promptLabel.textColor = .white
        promptLabel.font = .systemFont(ofSize: 22, weight: .bold)
        promptLabel.textAlignment = .center
        promptLabel.numberOfLines = 0
        promptLabel.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        promptLabel.layer.cornerRadius = 12
        promptLabel.clipsToBounds = true
        promptLabel.translatesAutoresizingMaskIntoConstraints = false

        stepLabel.textColor = .white
        stepLabel.font = .systemFont(ofSize: 14, weight: .medium)
        stepLabel.textAlignment = .center
        stepLabel.translatesAutoresizingMaskIntoConstraints = false

        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

        view.addSubview(promptLabel)
        view.addSubview(stepLabel)
        view.addSubview(cancelButton)

        #if DEBUG
        debugLabel.textColor = .systemYellow
        debugLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        debugLabel.numberOfLines = 0
        debugLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(debugLabel)
        NSLayoutConstraint.activate([
            debugLabel.topAnchor.constraint(equalTo: cancelButton.bottomAnchor, constant: 4),
            debugLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            debugLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
        #endif

        NSLayoutConstraint.activate([
            preview.topAnchor.constraint(equalTo: view.topAnchor),
            preview.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            preview.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            preview.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            cancelButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            cancelButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),

            stepLabel.bottomAnchor.constraint(equalTo: promptLabel.topAnchor, constant: -8),
            stepLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            promptLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            promptLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            promptLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -48),
            promptLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 56)
        ])
    }

    private func setPrompt(_ text: String) {
        if promptLabel.text != text { promptLabel.text = text }
    }

    // MARK: Wiring (source queue -> engine -> UI on main)

    private func wireUp() {
        engine.onEvent = { [weak self] event in self?.handle(event) }   // runs on the source queue

        source.onSignals = { [weak self] signals in
            guard let self else { return }
            self.engine.process(signals)
            #if DEBUG
            self.updateDebug(signals)
            #endif
        }

        source.onFailure = { [weak self] message in
            DispatchQueue.main.async { self?.complete(self?.failureResult(message) ?? nil) }
        }
    }

    private func handle(_ event: LivenessEngine.Event) {
        switch event {
        case .message(let text):
            DispatchQueue.main.async { self.setPrompt(text) }

        case .prompt(let challenge, let index, let total):
            DispatchQueue.main.async {
                self.setPrompt(challenge.prompt)
                self.stepLabel.text = "Step \(index + 1) of \(total)"
            }

        case .captureNeutralFrame:
            neutralJPEG = source.snapshotJPEG()

        case .finished(let passed, let reason):
            let finalFrame = source.snapshotJPEG()
            let frames = passed ? [neutralJPEG, finalFrame].compactMap { $0 } : []
            let result = AppleLivenessResult(
                passed: passed,
                method: source.method,
                challenges: engine.plannedChallenges.map { $0.name },
                challengesPassed: engine.completedChallenges.count,
                depthReliefMM: engine.medianDepthReliefMM,
                frames: frames,
                failureReason: reason
            )
            DispatchQueue.main.async { self.complete(result) }
        }
    }

    private func failureResult(_ reason: String) -> AppleLivenessResult {
        AppleLivenessResult(passed: false, method: source.method, challenges: [], challengesPassed: 0,
                            depthReliefMM: nil, frames: [], failureReason: reason)
    }

    // MARK: Completion (fires exactly once, on main)

    private func complete(_ result: AppleLivenessResult?) {
        guard !completed, let result else { return }
        completed = true
        source.stop()
        onComplete?(result)
        onComplete = nil
    }

    @objc private func cancelTapped() {
        complete(failureResult("Cancelled"))
    }

    // MARK: Permission

    private func checkPermissionThenStart() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            source.start()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    granted ? self.source.start()
                            : self.complete(self.failureResult("Camera permission denied"))
                }
            }
        default:
            complete(failureResult("Camera permission denied. Enable it in Settings."))
        }
    }

    // MARK: Debug overlay (use it to calibrate thresholds on real devices)

    #if DEBUG
    private func updateDebug(_ s: FaceSignals) {
        guard s.timestamp - lastDebugUpdate > 0.2 else { return }
        lastDebugUpdate = s.timestamp
        let relief = s.depthReliefMM.map { String(format: "%.1f", $0) } ?? "-"
        let text = String(format: "inFrame:%@ eyes:%.2f yaw:%.0f smile:%.2f mouth:%.2f reliefMM:%@",
                          s.faceInFrame ? "Y" : "N", s.eyesClosed, s.yawDegrees,
                          s.smile ?? -1, s.mouthOpen ?? -1, relief)
        DispatchQueue.main.async { self.debugLabel.text = text }
    }
    #endif
}
