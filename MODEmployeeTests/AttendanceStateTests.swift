//
//  AttendanceStateTests.swift
//  MODEmployeeTests
//
//  Created by Rajpal singh on 12/10/26.
//

import XCTest
@testable import MODEmployee

final class AttendanceStateTests: XCTestCase {
    
    // MARK: - State Transitions
    
    func testCanSubmitAttendance_OnlyReadyState() {
        XCTAssertTrue(AttendanceState.readyForAttendance.canSubmitAttendance)
        XCTAssertFalse(AttendanceState.unauthenticated.canSubmitAttendance)
        XCTAssertFalse(AttendanceState.checkingLocation.canSubmitAttendance)
        XCTAssertFalse(AttendanceState.outsideGeofence(reason: "").canSubmitAttendance)
        XCTAssertFalse(AttendanceState.livenessInProgress.canSubmitAttendance)
    }
    
    func testIsLoading_StateValidation() {
        XCTAssertTrue(AttendanceState.checkingLocation.isLoading)
        XCTAssertTrue(AttendanceState.creatingVerificationSession.isLoading)
        XCTAssertTrue(AttendanceState.startingLiveness.isLoading)
        XCTAssertTrue(AttendanceState.livenessInProgress.isLoading)
        XCTAssertTrue(AttendanceState.submittingVerification.isLoading)
        
        XCTAssertFalse(AttendanceState.unauthenticated.isLoading)
        XCTAssertFalse(AttendanceState.readyForAttendance.isLoading)
        XCTAssertFalse(AttendanceState.attendanceSuccess(timestamp: Date()).isLoading)
    }
    
    func testErrorMessage_ErrorStates() {
        XCTAssertNotNil(AttendanceState.outsideGeofence(reason: "Test error").errorMessage)
        XCTAssertNotNil(AttendanceState.livenessFailed(reason: "Test error").errorMessage)
        XCTAssertNotNil(AttendanceState.recoverableError(message: "Test error").errorMessage)
        
        XCTAssertNil(AttendanceState.readyForAttendance.errorMessage)
        XCTAssertNil(AttendanceState.unauthenticated.errorMessage)
    }
    
    func testCanRetry_RecoverableStates() {
        XCTAssertTrue(AttendanceState.outsideGeofence(reason: "").canRetry)
        XCTAssertTrue(AttendanceState.livenessFailed(reason: "").canRetry)
        XCTAssertTrue(AttendanceState.recoverableError(message: "").canRetry)
        
        XCTAssertFalse(AttendanceState.readyForAttendance.canRetry)
        XCTAssertFalse(AttendanceState.attendanceSuccess(timestamp: Date()).canRetry)
    }
    
    // MARK: - Equality
    
    func testStateEquality() {
        let state1 = AttendanceState.readyForAttendance
        let state2 = AttendanceState.readyForAttendance
        XCTAssertEqual(state1, state2)
        
        let state3 = AttendanceState.outsideGeofence(reason: "Test")
        let state4 = AttendanceState.outsideGeofence(reason: "Test")
        XCTAssertEqual(state3, state4)
        
        XCTAssertNotEqual(state1, state3)
    }
}
