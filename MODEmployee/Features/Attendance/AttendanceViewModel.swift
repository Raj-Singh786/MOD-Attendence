//
//  AttendanceViewModel.swift
//  MODEmployee
//
//  Created by Rajpal singh on 12/10/26.
//

import Foundation

@MainActor
class AttendanceViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var state: AttendanceState = .unauthenticated
    @Published var locationStatus: String = ""
    @Published var employeeName: String = ""
    @Published var employeeId: String = ""
    @Published var siteName: String = ""
    
    // MARK: - Dependencies
    
    private let attendanceService = AttendanceService.shared
    private let authService = AuthenticationService.shared
    private let locationService = LocationService.shared
    
    // MARK: - Computed Properties
    
    var canSubmitAttendance: Bool {
        return state.canSubmitAttendance
    }
    
    var isLoading: Bool {
        return state.isLoading
    }
    
    var errorMessage: String? {
        return state.errorMessage
    }
    
    var canRetry: Bool {
        return state.canRetry
    }
    
    var isAttendanceSuccess: Bool {
        if case .attendanceSuccess = state {
            return true
        }
        return false
    }
    
    // MARK: - Initialization
    
    init() {
        setupBindings()
        loadEmployeeInfo()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        attendanceService.$state
            .assign(to: &$state)
        
        attendanceService.$locationStatus
            .assign(to: &$locationStatus)
    }
    
    private func loadEmployeeInfo() {
        guard let employee = authService.currentEmployee else {
            return
        }
        
        employeeName = employee.name
        employeeId = employee.employeeIdentifier
        siteName = employee.site.name
    }
    
    // MARK: - Attendance Flow
    
    func startAttendanceFlow() async {
        // Check authentication
        guard authService.isAuthenticated else {
            state = .unauthenticated
            return
        }
        
        // Request location permission if needed
        if !locationService.isLocationAvailable() {
            locationService.requestAuthorization()
            // Give user time to grant permission
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
        
        await attendanceService.startAttendanceFlow()
    }
    
    func submitAttendance() async {
        // Configure liveness provider
        let livenessProvider = KBYLivenessAdapter()
        attendanceService.setLivenessProvider(livenessProvider)
        
        await attendanceService.submitAttendance()
    }
    
    func retry() async {
        await attendanceService.retry()
    }
    
    func reset() {
        attendanceService.reset()
    }
    
    func logout() {
        authService.logout()
        attendanceService.reset()
        state = .unauthenticated
    }
}
