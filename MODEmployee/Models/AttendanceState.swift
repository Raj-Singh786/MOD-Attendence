//
//  AttendanceState.swift
//  MODEmployee
//
//  Created by Rajpal singh on 12/10/26.
//

import Foundation

/// State machine for attendance verification flow
enum AttendanceState: Equatable {
    case unauthenticated
    case checkingLocation
    case outsideGeofence(reason: String)
    case readyForAttendance
    case creatingVerificationSession
    case startingLiveness
    case livenessInProgress
    case livenessFailed(reason: String)
    case submittingVerification
    case attendanceSuccess(timestamp: Date)
    case recoverableError(message: String)
    
    var canSubmitAttendance: Bool {
        switch self {
        case .readyForAttendance:
            return true
        default:
            return false
        }
    }
    
    var isLoading: Bool {
        switch self {
        case .checkingLocation, .creatingVerificationSession, .startingLiveness, .livenessInProgress, .submittingVerification:
            return true
        default:
            return false
        }
    }
    
    var errorMessage: String? {
        switch self {
        case .outsideGeofence(let reason):
            return reason
        case .livenessFailed(let reason):
            return reason
        case .recoverableError(let message):
            return message
        default:
            return nil
        }
    }
    
    var canRetry: Bool {
        switch self {
        case .outsideGeofence, .livenessFailed, .recoverableError:
            return true
        default:
            return false
        }
    }
}
