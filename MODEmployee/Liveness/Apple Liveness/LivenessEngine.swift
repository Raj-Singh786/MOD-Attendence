//
//  LivenessEngine.swift
//  MODEmployee
//
//  Created by Rajpal singh on 13/10/26.
//

import Foundation

// MARK: - Challenges

enum LivenessChallenge: CaseIterable, Hashable {
    case blink

    var prompt: String {
        switch self {
        case .blink:      return "Blink your eyes"
        }
    }

    var name: String { String(describing: self) }
}

// MARK: - Signals produced by a source (ARKit or Vision)

struct FaceSignals {
    var timestamp: TimeInterval
    var faceInFrame: Bool          // exactly one face, tracked, roughly centered, right distance
    var eyesClosed: Float          // 0 = open ... 1 = closed
    var yawDegrees: Float          // + = user's LEFT, - = user's RIGHT (sources normalize the sign)
    var smile: Float?              // 0...1, nil if the source cannot measure it
    var mouthOpen: Float?          // 0...1, nil if the source cannot measure it
    var depthReliefMM: Float?      // plane-fit residual of the face region, nil if no depth this frame
}

// MARK: - Policy (all thresholds in one place; CALIBRATE on real devices)

struct LivenessPolicy {
    var challengeCount = 1
    var challengeTimeout: TimeInterval = 10    // 10 seconds per challenge
    var overallTimeout: TimeInterval = 30       // 30 seconds total
    var neutralHold: TimeInterval = 0.8        // 0.8 seconds neutral hold
    var minReactionTime: TimeInterval = 0.5    // 0.5 seconds reaction time

    var blinkThreshold: Float = 0.6
    var neutralMaxYaw: Float = 8

    /// Minimum "3D-ness" of the face (mm of deviation from a flat plane).
    /// 5 is only a starting guess. Measure real faces vs. photos/screens and set it from data.
    var minDepthReliefMM: Float = 5
    var minDepthSamples = 5
    var requireDepthWhenAvailable = true
}

// MARK: - Engine

/// Runs a random sequence of challenges. Not thread-safe: call `process` from ONE queue.
final class LivenessEngine {

    enum Event {
        case message(String)
        case prompt(LivenessChallenge, index: Int, total: Int)
        case captureNeutralFrame
        case finished(passed: Bool, reason: String?)
    }

    var onEvent: ((Event) -> Void)?

    private enum Phase {
        case waitingNeutral(since: TimeInterval?)
        case challenge(start: TimeInterval)
    }

    private let policy: LivenessPolicy
    private let usesDepth: Bool
    private let challenges: [LivenessChallenge]

    private var index = 0
    private var phase: Phase = .waitingNeutral(since: nil)
    private var startTime: TimeInterval?
    private var depthSamples: [Float] = []
    private var capturedNeutral = false
    private var isDone = false

    private(set) var completedChallenges: [LivenessChallenge] = []
    private(set) var medianDepthReliefMM: Float?

    var plannedChallenges: [LivenessChallenge] { challenges }

    init(policy: LivenessPolicy, supported: Set<LivenessChallenge>, usesDepth: Bool) {
        self.policy = policy
        self.usesDepth = usesDepth
        // Random, non-repeating order: a pre-recorded video can't know it in advance.
        self.challenges = Array(supported.shuffled().prefix(policy.challengeCount))
    }

    func process(_ s: FaceSignals) {
        guard !isDone else { return }
        guard !challenges.isEmpty else { finish(false, "No challenges available"); return }

        let t = s.timestamp
        if startTime == nil { startTime = t }
        if t - (startTime ?? t) > policy.overallTimeout {
            finish(false, "Timed out. Please try again.")
            return
        }

        if s.faceInFrame, let relief = s.depthReliefMM {
            depthSamples.append(relief)
        }

        guard s.faceInFrame else {
            phase = .waitingNeutral(since: nil)
            onEvent?(.message("Center your face in the oval"))
            return
        }

        switch phase {
        case .waitingNeutral(let since):
            guard isNeutral(s) else {
                phase = .waitingNeutral(since: nil)
                onEvent?(.message("Look straight at the camera"))
                return
            }
            let begin = since ?? t
            if t - begin >= policy.neutralHold {
                if !capturedNeutral {
                    capturedNeutral = true
                    onEvent?(.captureNeutralFrame)   // best frame for face matching: frontal, eyes open
                }
                phase = .challenge(start: t)
                onEvent?(.prompt(challenges[index], index: index, total: challenges.count))
            } else {
                phase = .waitingNeutral(since: begin)
                onEvent?(.message("Look straight at the camera"))
            }

        case .challenge(let start):
            let elapsed = t - start
            if elapsed > policy.challengeTimeout {
                finish(false, "You didn't complete the action in time.")
                return
            }
            if elapsed >= policy.minReactionTime, isSatisfied(challenges[index], s) {
                completedChallenges.append(challenges[index])
                index += 1
                if index >= challenges.count {
                    evaluateFinal()
                } else {
                    phase = .waitingNeutral(since: nil)
                    onEvent?(.message("Good. Look straight again"))
                }
            }
        }
    }

    // MARK: - Private

    private func isNeutral(_ s: FaceSignals) -> Bool {
        s.eyesClosed < 0.3
            && abs(s.yawDegrees) < policy.neutralMaxYaw
    }

    private func isSatisfied(_ c: LivenessChallenge, _ s: FaceSignals) -> Bool {
        switch c {
        case .blink:      return s.eyesClosed >= policy.blinkThreshold
        }
    }

    private func evaluateFinal() {
        if usesDepth && policy.requireDepthWhenAvailable {
            guard depthSamples.count >= policy.minDepthSamples else {
                finish(false, "Depth data unavailable. Please try again.")
                return
            }
            let median = depthSamples.sorted()[depthSamples.count / 2]
            medianDepthReliefMM = median
            if median < policy.minDepthReliefMM {
                finish(false, "Face looks flat. Please use your live face.")
                return
            }
        }
        finish(true, nil)
    }

    private func finish(_ passed: Bool, _ reason: String?) {
        guard !isDone else { return }
        isDone = true
        onEvent?(.finished(passed: passed, reason: reason))
    }
}
